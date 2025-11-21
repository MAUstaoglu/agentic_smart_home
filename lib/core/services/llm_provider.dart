import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_ui_agent/flutter_ui_agent.dart';

class GemmaLlmProvider implements LlmProvider {
  bool _isInitialized = false;
  ModelFileType _modelFileType = ModelFileType.binary;

  @override
  Future<void> configure({required String apiKey, String? modelName}) async {
    try {
      final path = modelName ?? 'assets/models/gemma-2b-it-gpu-int4.bin';
      final extension = path.split('.').last.toLowerCase();

      if (extension == 'task' || extension == 'litertlm') {
        _modelFileType = ModelFileType.task;
      } else {
        _modelFileType = ModelFileType.binary;
      }

      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: _modelFileType,
      ).fromAsset(path).install();
      _isInitialized = true;
    } catch (e) {
      throw Exception(
        'Failed to initialize Gemma model: $e\n\n'
        'Make sure you have:\n'
        '1. Called FlutterGemma.initialize() in main()\n'
        '2. Installed a model using FlutterGemma.installModel()\n'
        '3. The model is compatible with your platform',
      );
    }
  }

  @override
  Future<LlmResponse> send({
    required String systemPrompt,
    required String userMessage,
    required List<Map<String, dynamic>> tools,
    required List<ConversationMessage> history,
  }) async {
    if (!_isInitialized) {
      throw Exception(
        'Gemma provider not initialized. Call configure() first.',
      );
    }

    String finalUserMessage = userMessage;
    final userRequestMatch = RegExp(
      r'User request: "([^"]+)"',
    ).firstMatch(userMessage);
    if (userRequestMatch != null) {
      finalUserMessage = userRequestMatch.group(1)!;
    }

    final toolsList = tools.map((tool) => tool['function']).toList();
    String currentPage = 'unknown';
    final pageMatch = RegExp(
      r'Current Page:\s*([a-zA-Z0-9_ ]+)',
      caseSensitive: false,
    ).firstMatch(systemPrompt);

    if (pageMatch != null) {
      currentPage = pageMatch
          .group(1)!
          .trim()
          .toLowerCase()
          .replaceAll('_', ' ');
    }

    final normalizedPage = currentPage.replaceAll('_', ' ');

    final redundantNavPattern = RegExp(
      r'(?:go|navigate)\s+to\s+(?:the\s+)?' + RegExp.escape(normalizedPage),
      caseSensitive: false,
    );

    if (redundantNavPattern.hasMatch(finalUserMessage)) {
      debugPrint(
        'Found redundant navigation to $normalizedPage. Removing from message.',
      );
      finalUserMessage = finalUserMessage.replaceAll(redundantNavPattern, '');

      finalUserMessage = finalUserMessage
          .replaceAll(RegExp(r'^\s*(?:and|,)\s*', caseSensitive: false), '')
          .trim();

      debugPrint('Processed User Message: "$finalUserMessage"');
    }

    if (finalUserMessage.isEmpty) {
      return LlmResponse(text: 'Arrived in $currentPage');
    }

    final switchRoomFunc = toolsList.firstWhere(
      (t) => t['name'] == 'switch_room_page',
      orElse: () => {},
    );

    final roomEnum =
        switchRoomFunc['parameters']?['properties']?['room_name']?['enum']
            as List<dynamic>?;

    final filteredRooms = roomEnum
        ?.where((r) => r.toString().toLowerCase() != currentPage)
        .toList();

    final validRooms =
        filteredRooms?.map((e) => '"$e"').join(', ') ??
        '"Living Room", "Bedroom", "Garage"';

    final simplifiedTools = toolsList
        .map((tool) {
          final name = tool['name'];
          final desc = tool['description'];

          final params =
              tool['parameters']?['properties'] as Map<String, dynamic>? ?? {};
          final paramList = params.entries
              .map((e) {
                if (e.key == 'room_name' && name == 'switch_room_page') {
                  return '${e.key}: "One of [$validRooms]"';
                }
                return '${e.key}: ${e.value['type']}';
              })
              .join(', ');

          return '- $name($paramList): $desc';
        })
        .join('\n');

    final navInfo = _getNavigationInfo(finalUserMessage, currentPage, roomEnum);

    String? fewShotExample;
    if (navInfo.shouldSwitch && navInfo.targetRoom != null) {
      fewShotExample =
          '''
EXAMPLE:
User: "Turn on the ${navInfo.targetRoom} light"
CONTEXT: Current Page: "$currentPage"
CORRECT RESPONSE:
{
  "function_name": "switch_room_page",
  "arguments": {
    "room_name": "${navInfo.targetRoom}"
  }
}
''';
    }

    final promptContent =
        '''
${navInfo.hint}

You are an AI Assistant.

CONTEXT:
- Current Room: "$currentPage"
- Other Rooms: $validRooms

TOOLS:
$simplifiedTools

INSTRUCTIONS:
- Select the best tool(s) for the user's request.
- Use the EXACT function name from the TOOLS list.
- If the device is in another room, you MUST use `switch_room_page` to go there first.
- Return ONLY a valid JSON object.
- For a single action: {"function_name": "...", "arguments": {...}}
- For MULTIPLE actions: {"function_calls": [{"function_name": "...", "arguments": {...}}, ...]}
- Do NOT include any other text or markdown formatting.

${fewShotExample ?? ''}

EXAMPLE (Multi-step):
User: "Set color to red and turn on the light"
CORRECT RESPONSE:
{
  "function_calls": [
    {"function_name": "set_color_red_living_room", "arguments": {}},
    {"function_name": "toggle_light_living_room", "arguments": {"on": true}}
  ]
}

USER REQUEST: "$finalUserMessage"
''';

    String finalPrompt;
    if (_modelFileType == ModelFileType.binary) {
      finalPrompt =
          '<start_of_turn>user\n$promptContent<end_of_turn>\n<start_of_turn>model\n';
    } else {
      finalPrompt = promptContent;
    }
    debugPrint('--- Sending to Native ---');
    debugPrint('Current Message:');
    debugPrint(finalPrompt);
    debugPrint('-------------------------');

    final model = await FlutterGemma.getActiveModel(
      preferredBackend: PreferredBackend.gpu,
    );
    try {
      final chat = await model.createChat(
        supportImage: false,
        isThinking: false,
        modelType: ModelType.gemmaIt,
        temperature: 0.0,
        tools: _buildToolsDescription(tools),
      );

      await chat.addQueryChunk(Message.text(text: finalPrompt, isUser: true));

      final response = await chat.generateChatResponse();

      debugPrint('--- Response from Native ---');
      debugPrint('Response: $response');
      debugPrint('-----------------------------');

      if (navInfo.shouldSwitch && navInfo.targetRoom != null) {
        bool modelSwitched = false;
        final responseStr = response.toString();

        if (responseStr.contains('switch_room_page') &&
            responseStr.contains(navInfo.targetRoom!)) {
          modelSwitched = true;
        }

        if (!modelSwitched) {
          debugPrint(
            '⚠️ Auto-correcting navigation: Forcing switch to ${navInfo.targetRoom}',
          );
          return LlmResponse(
            functionCalls: [
              LlmFunctionCall('switch_room_page', {
                'room_name': navInfo.targetRoom,
              }, continueAfterNavigation: true),
            ],
          );
        }
      }

      if (response is TextResponse) {
        final responseText = response.token.trim();

        debugPrint('Response text: $responseText');

        String fixedText = responseText;

        final codeBlockMatch = RegExp(
          r'```(?:json)?\s*([\s\S]*?)\s*```',
        ).firstMatch(responseText);
        if (codeBlockMatch != null) {
          fixedText = codeBlockMatch.group(1)!.trim();
        } else {
          final start = fixedText.indexOf('{');
          final end = fixedText.lastIndexOf('}');
          if (start != -1 && end != -1 && end > start) {
            fixedText = fixedText.substring(start, end + 1);
          }
        }

        try {
          final jsonResponse = jsonDecode(fixedText);

          LlmFunctionCall? processCall(Map<String, dynamic> call) {
            if (!call.containsKey('function_name') ||
                !call.containsKey('arguments')) {
              return null;
            }

            var name = call['function_name'] as String;
            final rawArgs = call['arguments'];
            Map<String, dynamic> args = {};

            if (name == 'toggle_garage_light') name = 'toggle_light_garage';
            if (name == 'toggle_garage_door') name = 'toggle_garage_gate';
            if (name == 'toggle_room_page') name = 'switch_room_page';

            if (rawArgs is List) {
              debugPrint(
                '⚠️ Warning: LLM returned arguments as List. Attempting to map to parameters.',
              );

              final toolDef = tools.firstWhere(
                (t) => t['function']['name'] == name,
                orElse: () => {},
              );

              if (toolDef.isNotEmpty) {
                final params =
                    toolDef['function']['parameters']['properties']
                        as Map<String, dynamic>;
                final paramNames = params.keys.toList();

                for (
                  var i = 0;
                  i < rawArgs.length && i < paramNames.length;
                  i++
                ) {
                  args[paramNames[i]] = rawArgs[i];
                }
              }
            } else if (rawArgs is Map) {
              args = Map<String, dynamic>.from(rawArgs);
            }

            final convertedArgs = <String, dynamic>{};
            args.forEach((k, v) {
              if (v is int) {
                convertedArgs[k] = v.toDouble();
              } else if (v is String) {
                if (v.toLowerCase() == 'true') {
                  convertedArgs[k] = true;
                } else if (v.toLowerCase() == 'false') {
                  convertedArgs[k] = false;
                } else {
                  convertedArgs[k] = v;
                }
              } else {
                convertedArgs[k] = v;
              }
            });

            return LlmFunctionCall(
              name,
              convertedArgs,
              continueAfterNavigation: name == 'switch_room_page',
            );
          }

          if (jsonResponse is Map &&
              jsonResponse.containsKey('function_name') &&
              jsonResponse.containsKey('arguments')) {
            final call = processCall(jsonResponse as Map<String, dynamic>);
            if (call != null) {
              return LlmResponse(functionCalls: [call]);
            }
          } else if (jsonResponse is Map &&
              jsonResponse.containsKey('function_calls')) {
            final calls = jsonResponse['function_calls'] as List;
            final functionCalls = <LlmFunctionCall>[];

            for (final callItem in calls) {
              if (callItem is Map) {
                final call = processCall(callItem as Map<String, dynamic>);
                if (call != null) {
                  functionCalls.add(call);
                }
              }
            }
            return LlmResponse(functionCalls: functionCalls);
          }
        } catch (e) {
          debugPrint('JSON parse failed: $e');
        }
      }

      return LlmResponse(text: response.toString().trim());
    } catch (e) {
      await model.close();
      return LlmResponse(text: 'Error generating response: $e');
    } finally {
      await model.close();
    }
  }

  List<Tool> _buildToolsDescription(List<Map<String, dynamic>> tools) {
    final toolsList = <Tool>[];

    for (final tool in tools) {
      final funcMap = tool['function'] as Map<String, dynamic>;
      final name = funcMap['name'] as String;
      final description = funcMap['description'] as String;
      final params = funcMap['parameters'] as Map<String, dynamic>?;

      toolsList.add(
        Tool(name: name, description: description, parameters: params ?? {}),
      );
    }

    return toolsList;
  }

  ({bool shouldSwitch, String? targetRoom, String hint}) _getNavigationInfo(
    String userMessage,
    String currentRoom,
    List<dynamic>? knownRooms,
  ) {
    final lowerMsg = userMessage.toLowerCase();
    final lowerCurrent = currentRoom.toLowerCase();

    if (knownRooms != null) {
      for (final room in knownRooms) {
        final lowerRoom = room.toString().toLowerCase();
        if (lowerMsg.contains(lowerRoom) && lowerRoom != lowerCurrent) {
          debugPrint(
            'Navigation Info: Switching to $room (User: "$userMessage", Current: "$currentRoom")',
          );
          return (
            shouldSwitch: true,
            targetRoom: room.toString(),
            hint:
                'HINT: User mentioned "$room". You are currently in "$currentRoom". You MUST use `switch_room_page` to go to "$room" first.',
          );
        }
      }

      if (lowerMsg.contains(lowerCurrent)) {
        debugPrint('Navigation Info: Staying in $currentRoom');
        return (
          shouldSwitch: false,
          targetRoom: null,
          hint:
              'HINT: You are already in "$currentRoom". The user wants to control a device in "$currentRoom". DO NOT use `switch_room_page`. Use the specific device tool immediately.',
        );
      }
    }

    return (shouldSwitch: false, targetRoom: null, hint: '');
  }
}
