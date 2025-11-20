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

    String finalPrompt;

    String? dynamicHint;
    if (roomEnum != null) {
      for (final room in roomEnum) {
        final roomStr = room.toString();

        if (finalUserMessage.toLowerCase().contains(roomStr.toLowerCase())) {
          if (roomStr.toLowerCase() != currentPage) {
            dynamicHint =
                'HINT: User mentioned "$roomStr". You are currently in "$currentPage". You MUST use `switch_room_page` to go to "$roomStr" first.';
            debugPrint('Injecting Hint: $dynamicHint');
            break;
          } else {
            dynamicHint =
                'HINT: You are already in "$currentPage". The user wants to control a device in "$currentPage". DO NOT use `switch_room_page`. Use the specific device tool immediately.';
            debugPrint('Injecting Stay Hint: $dynamicHint');
            break;
          }
        }
      }
    }

    final promptContent =
        '''
${dynamicHint != null ? '$dynamicHint\n' : ''}
You are an AI Assistant controlling a smart home app.

CONTEXT:
- Current Page: "$currentPage"
- Valid Navigation Targets: [$validRooms]

AVAILABLE TOOLS (STRICT LIST):
$simplifiedTools

DECISION PROTOCOL (FOLLOW IN ORDER):
1. SEARCH: Look for a function in "AVAILABLE TOOLS" that matches the user's request.
2. CHECK: Is the function explicitly listed above?
   - YES: Use it.
   - NO: STOP. Do not invent a name. You MUST navigate to the correct room.

SEMANTIC FILTER (APPLY ONLY IF TOOL IS IN THE LIST):
- If checking "AVAILABLE TOOLS" and user said "Light", pick a function with "_light_" or "_color_".
- If checking "AVAILABLE TOOLS" and user said "Gate", pick a function with "_gate_".
- If the tool is NOT in "AVAILABLE TOOLS", IGNORE these filters and use `switch_room_page`.

USER REQUEST: "$finalUserMessage"

Respond with valid JSON only. Do not use markdown code blocks.
''';
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

      if (response is TextResponse) {
        final responseText = response.token.trim();

        debugPrint('Response text: $responseText');

        try {
          String fixedText = responseText;

          if (fixedText.contains('```')) {
            fixedText = fixedText
                .replaceAll('```json', '')
                .replaceAll('```', '')
                .trim();
          }

          final firstBrace = fixedText.indexOf('{');
          if (firstBrace != -1) {
            int braceCount = 0;
            int lastBrace = firstBrace;

            for (int i = firstBrace; i < fixedText.length; i++) {
              if (fixedText[i] == '{') {
                braceCount++;
              } else if (fixedText[i] == '}') {
                braceCount--;
                if (braceCount == 0) {
                  lastBrace = i;
                  break;
                }
              }
            }

            fixedText = fixedText.substring(firstBrace, lastBrace + 1);
          }

          if (fixedText.startsWith('"') &&
              fixedText.endsWith('"') &&
              fixedText.length > 1) {
            fixedText = fixedText.substring(1, fixedText.length - 1);
          }

          try {
            final decoded = jsonDecode(fixedText);
            if (decoded is String) {
              fixedText = decoded;
            }
          } catch (_) {
            debugPrint('JSON string decoding failed, proceeding with original');
          }

          fixedText = fixedText.replaceAll(
            '"arguments": {"}',
            '"arguments": {}',
          );

          debugPrint('Fixed text: $fixedText');

          if (fixedText.trim().startsWith('"function_calls"')) {
            fixedText = '{${fixedText.trim()}';
          } else if (fixedText.trim().startsWith('"function_calls":')) {
            fixedText = '{${fixedText.trim()}';
          }

          if (fixedText.contains('"function_calls"')) {
            final openBrackets = RegExp(r'\[').allMatches(fixedText).length;
            final closeBrackets = RegExp(r'\]').allMatches(fixedText).length;
            if (openBrackets > closeBrackets) {
              fixedText = fixedText.trim();

              if (fixedText.endsWith('}')) {
                fixedText = fixedText.substring(0, fixedText.length - 1).trim();
              }
              fixedText = '$fixedText]}';
            }
          }

          final jsonResponse = jsonDecode(fixedText);
          if (jsonResponse is Map) {
            if (jsonResponse.containsKey('function_calls')) {
              final calls = jsonResponse['function_calls'] as List;
              final functionCalls = <LlmFunctionCall>[];

              for (final call in calls) {
                if (call is Map &&
                    call.containsKey('function_name') &&
                    call.containsKey('arguments')) {
                  final name = call['function_name'] as String;
                  final args = call['arguments'] as Map<String, dynamic>;

                  final convertedArgs = <String, dynamic>{};
                  args.forEach((k, v) {
                    if (v is int) {
                      convertedArgs[k] = v.toDouble();
                    } else {
                      convertedArgs[k] = v;
                    }
                  });
                  functionCalls.add(
                    LlmFunctionCall(
                      name,
                      convertedArgs,
                      continueAfterNavigation: name == 'switch_room_page',
                    ),
                  );
                }
              }
              return LlmResponse(functionCalls: functionCalls);
            } else if (jsonResponse.containsKey('function_name') &&
                jsonResponse.containsKey('arguments')) {
              final name = jsonResponse['function_name'] as String;
              final args = jsonResponse['arguments'] as Map<String, dynamic>;
              final convertedArgs = <String, dynamic>{};
              args.forEach((k, v) {
                if (v is int) {
                  convertedArgs[k] = v.toDouble();
                } else {
                  convertedArgs[k] = v;
                }
              });
              return LlmResponse(
                functionCalls: [
                  LlmFunctionCall(
                    name,
                    convertedArgs,
                    continueAfterNavigation: name == 'switch_room_page',
                  ),
                ],
              );
            }
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

  Future<void> dispose() async {
    if (_isInitialized) {
      try {
        _isInitialized = false;
      } catch (e) {
        debugPrint('Error during disposal: $e');
      }
    }
  }
}
