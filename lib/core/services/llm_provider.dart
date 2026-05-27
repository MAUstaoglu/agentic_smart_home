import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_ui_agent/flutter_ui_agent.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'resumable_downloader.dart';

class GemmaLlmProvider extends ChangeNotifier implements LlmProvider {
  bool _isInitialized = false;
  ModelFileType _modelFileType = ModelFileType.binary;
  bool _isMockMode = false;

  // Download States
  bool isInstalled = false;
  bool isDownloading = false;
  double downloadProgress = 0.0;
  double downloadSpeedMb = 0.0;
  Duration downloadTimeRemaining = Duration.zero;
  String downloadStatus = 'idle'; // 'downloading', 'paused', 'failed', 'completed', 'idle'
  String? downloadError;
  ResumableDownloader? _downloader;

  // Model Memory Cache States
  bool isLoading = false;
  double loadProgress = 0.0;
  bool isModelLoaded = false;
  String loadStatus = 'Not Loaded'; // 'Not Loaded', 'Loading...', 'Ready'
  InferenceModel? _activeModel;

  // Config & Energy Telemetry
  PreferredBackend preferredBackend = PreferredBackend.gpu;
  int maxTokens = 1024;
  int cacheTimeoutSeconds = 120; // 2 minutes idle timeout
  Timer? _idleTimer;

  Duration lastInferenceDuration = Duration.zero;
  int lastTokensGenerated = 0;
  double lastInferenceSpeed = 0.0; // tokens/s
  double estimatedEnergyConsumed = 0.0; // Joules

  /// Get the standard path where the model binary should be stored locally
  Future<String> getModelPath() async {
    final docDir = await getApplicationDocumentsDirectory();
    return p.join(docDir.path, 'gemma-2b-it-gpu-int4.bin');
  }

  /// Check if the model is currently downloaded and installed
  Future<bool> checkInstallationStatus() async {
    final path = await getModelPath();
    final file = File(path);
    final marker = File('$path.completed');
    final exists = await file.exists() && await marker.exists();
    
    if (exists) {
      final length = await file.length();
      _isMockMode = length < 10 * 1024 * 1024; // Less than 10MB is Mock Mode
    } else {
      _isMockMode = false;
    }
    
    isInstalled = exists;
    notifyListeners();
    return exists;
  }

  /// Start downloading the model (supports resuming)
  Future<void> startDownload({required bool isMock}) async {
    if (isDownloading) return;

    isDownloading = true;
    downloadError = null;
    notifyListeners();

    try {
      final savePath = await getModelPath();
      
      // Gemma 2B IT quantized model or a small configuration file for quick mock testing
      final mockUrl = 'https://raw.githubusercontent.com/DenisovAV/flutter_gemma/main/example/pubspec.yaml';
      final realUrl = 'https://huggingface.co/alexdlov/gemma-2b-it-gpu-int4.bin/resolve/main/gemma-2b-it-gpu-int4.bin';
      final downloadUrl = isMock ? mockUrl : realUrl;

      _downloader?.dispose();
      _downloader = ResumableDownloader(url: downloadUrl, savePath: savePath);

      _downloader!.progressStream.listen((info) async {
        downloadProgress = info.progress;
        downloadSpeedMb = info.speedMbBytesPerSec;
        downloadTimeRemaining = info.estimatedTimeRemaining;
        downloadStatus = info.status;
        downloadError = info.errorMessage;

        if (info.status == 'completed') {
          isDownloading = false;
          _downloader?.dispose();
          _downloader = null;

          // Create completed marker file
          final marker = File('$savePath.completed');
          await marker.create(recursive: true);

          // Register model with FlutterGemma
          await FlutterGemma.installModel(
            modelType: ModelType.gemmaIt,
            fileType: ModelFileType.binary,
          ).fromFile(savePath).install();

          isInstalled = true;
          _isInitialized = true;
        } else if (info.status == 'failed') {
          isDownloading = false;
        } else if (info.status == 'paused') {
          isDownloading = false;
        }
        notifyListeners();
      });

      await _downloader!.start();
    } catch (e) {
      isDownloading = false;
      downloadError = e.toString();
      notifyListeners();
    }
  }

  /// Pause the download
  void pauseDownload() {
    _downloader?.pause();
    isDownloading = false;
    notifyListeners();
  }

  /// Reset the download (delete partial download)
  Future<void> resetDownload() async {
    final path = await getModelPath();
    final marker = File('$path.completed');
    if (await marker.exists()) {
      await marker.delete();
    }

    if (_downloader != null) {
      await _downloader!.reset();
      _downloader?.dispose();
      _downloader = null;
    } else {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    isInstalled = false;
    _isInitialized = false;
    downloadProgress = 0.0;
    downloadSpeedMb = 0.0;
    downloadTimeRemaining = Duration.zero;
    downloadStatus = 'idle';
    downloadError = null;
    notifyListeners();
  }

  /// Load the model into memory (RAM/VRAM)
  Future<void> loadModel() async {
    if (isLoading || isModelLoaded) return;
    isLoading = true;
    loadStatus = 'Loading model file...';
    loadProgress = 0.0;
    notifyListeners();

    // Simulate progress bar smoothly to wow the user (Requirement 4)
    final progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (loadProgress < 0.9) {
        loadProgress += 0.05;
        if (loadProgress > 0.3 && loadProgress < 0.6) {
          loadStatus = 'Allocating memory buffer (VRAM)...';
        } else if (loadProgress >= 0.6) {
          loadStatus = 'Compiling compute shaders...';
        }
        notifyListeners();
      }
    });

    try {
      if (!_isMockMode) {
        // Load active model into memory
        _activeModel = await FlutterGemma.getActiveModel(
          maxTokens: maxTokens,
          preferredBackend: preferredBackend,
        );
      } else {
        await Future.delayed(const Duration(seconds: 1));
      }

      progressTimer.cancel();
      loadProgress = 1.0;
      loadStatus = 'Model loaded successfully!';
      isModelLoaded = true;
      isLoading = false;
      _resetIdleTimer();
      notifyListeners();

      // Show "ready" status briefly
      await Future.delayed(const Duration(milliseconds: 500));
      loadProgress = 0.0;
      notifyListeners();
    } catch (e) {
      progressTimer.cancel();
      isLoading = false;
      isModelLoaded = false;
      loadStatus = 'Load failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Unload model to conserve memory and battery
  Future<void> unloadModel() async {
    _idleTimer?.cancel();
    if (_activeModel != null) {
      await _activeModel!.close();
      _activeModel = null;
    }
    isModelLoaded = false;
    loadStatus = 'Not Loaded';
    notifyListeners();
    debugPrint('ℹ️ LLM Model unloaded from memory to conserve battery.');
  }

  /// Set the preferred backend (GPU or CPU)
  void setPreferredBackend(PreferredBackend backend) {
    if (preferredBackend != backend) {
      preferredBackend = backend;
      // If model was loaded, reload it with the new backend configuration
      if (isModelLoaded) {
        unloadModel().then((_) => loadModel());
      } else {
        notifyListeners();
      }
    }
  }

  /// Set the cache idle timeout
  void setCacheTimeout(int seconds) {
    cacheTimeoutSeconds = seconds;
    _resetIdleTimer();
    notifyListeners();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (cacheTimeoutSeconds > 0 && isModelLoaded) {
      _idleTimer = Timer(Duration(seconds: cacheTimeoutSeconds), () {
        debugPrint('⏰ Cache timeout reached: Unloading model.');
        unloadModel();
      });
    }
  }

  @override
  Future<void> configure({required String apiKey, String? modelName}) async {
    try {
      final hasModel = await checkInstallationStatus();
      if (hasModel) {
        if (_isMockMode) {
          _isInitialized = true;
        } else {
          final path = await getModelPath();
          final extension = path.split('.').last.toLowerCase();

          if (extension == 'task' || extension == 'litertlm') {
            _modelFileType = ModelFileType.task;
          } else {
            _modelFileType = ModelFileType.binary;
          }

          await FlutterGemma.installModel(
            modelType: ModelType.gemmaIt,
            fileType: _modelFileType,
          ).fromFile(path).install();
          _isInitialized = true;
        }
      } else {
        _isInitialized = false;
      }
    } catch (e) {
      debugPrint('Failed to configure Gemma model: $e');
      _isInitialized = false;
    }
    notifyListeners();
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
        'Gemma provider not initialized. Download and register the model first.',
      );
    }

    // Lazy load model into memory if it was unloaded due to idle timeout
    if (_activeModel == null || !isModelLoaded) {
      await loadModel();
    } else {
      _resetIdleTimer();
    }

    final startTime = DateTime.now();

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

    if (_isMockMode) {
      await Future.delayed(const Duration(milliseconds: 600));

      final lowerMsg = finalUserMessage.toLowerCase();
      final targetRoom = navInfo.targetRoom;
      final targetRoomSnake = targetRoom?.toLowerCase().replaceAll(' ', '_') ?? currentPage.replaceAll(' ', '_');

      // Check for navigation first
      if (navInfo.shouldSwitch && targetRoom != null) {
        final elapsed = const Duration(milliseconds: 600);
        lastInferenceDuration = elapsed;
        lastTokensGenerated = 15;
        lastInferenceSpeed = 25.0;
        estimatedEnergyConsumed = 3.0 * 0.6; // Mock mode uses CPU profile
        
        notifyListeners();
        
        return LlmResponse(
          functionCalls: [
            LlmFunctionCall('switch_room_page', {
              'room_name': targetRoom,
            }, continueAfterNavigation: true),
          ],
        );
      }

      final calls = <LlmFunctionCall>[];

      // Lights
      if (lowerMsg.contains('light')) {
        bool turnOn = true;
        if (lowerMsg.contains('off') || lowerMsg.contains('close') || lowerMsg.contains('shut')) {
          turnOn = false;
        }
        calls.add(LlmFunctionCall('toggle_light_$targetRoomSnake', {'on': turnOn}));
      }

      // TV
      if (lowerMsg.contains('tv') || lowerMsg.contains('television')) {
        bool turnOn = true;
        if (lowerMsg.contains('off')) {
          turnOn = false;
        }
        calls.add(LlmFunctionCall('toggle_tv_$targetRoomSnake', {'on': turnOn}));
      }

      // Garage Gate
      if (lowerMsg.contains('gate') || lowerMsg.contains('door') || lowerMsg.contains('garage')) {
        if (!lowerMsg.contains('light')) {
          bool open = true;
          if (lowerMsg.contains('close') || lowerMsg.contains('shut')) {
            open = false;
          }
          calls.add(LlmFunctionCall('toggle_gate_$targetRoomSnake', {'open': open}));
        }
      }

      // Color
      if (lowerMsg.contains('color') || lowerMsg.contains('red') || lowerMsg.contains('blue') || lowerMsg.contains('green')) {
        String color = 'blue'; // default
        if (lowerMsg.contains('red')) color = 'red';
        if (lowerMsg.contains('green')) color = 'green';
        calls.add(LlmFunctionCall('set_color_${color}_$targetRoomSnake', {}));
      }

      // Temperature / Thermostat
      if (lowerMsg.contains('temp') || lowerMsg.contains('temperature') || lowerMsg.contains('thermostat') || lowerMsg.contains('degree')) {
        double temp = 22.0;
        final tempMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(lowerMsg);
        if (tempMatch != null) {
          temp = double.tryParse(tempMatch.group(1)!) ?? 22.0;
        }
        calls.add(LlmFunctionCall('set_temperature_$targetRoomSnake', {'temperature': temp}));
      }

      if (calls.isEmpty) {
        return LlmResponse(text: "I didn't understand that command in mock mode.");
      }

      final elapsed = const Duration(milliseconds: 600);
      lastInferenceDuration = elapsed;
      final responseText = jsonEncode({
        "function_calls": calls.map((c) => {
          "function_name": c.name,
          "arguments": c.args
        }).toList()
      });
      lastTokensGenerated = (responseText.length / 4).ceil();
      lastInferenceSpeed = lastTokensGenerated / 0.6;
      estimatedEnergyConsumed = 3.0 * 0.6;

      notifyListeners();
      return LlmResponse(functionCalls: calls);
    }

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
- Do NOT perform any actions that were not explicitly requested.
- Return ONLY a valid JSON object.
- ALWAYS use the following format:
  {"function_calls": [{"function_name": "...", "arguments": {...}}, ...]}
- Combine ALL actions into a SINGLE list.
- Do NOT create multiple "function_calls" keys.
- Do NOT include any other text or markdown formatting.

${fewShotExample ?? ''}

EXAMPLES:

User: "Turn on the light"
CORRECT RESPONSE:
{
  "function_calls": [
    {"function_name": "toggle_light_living_room", "arguments": {"on": true}}
  ]
}

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

    try {
      final chat = await _activeModel!.createChat(
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

      // Update Telemetry metrics
      final elapsed = DateTime.now().difference(startTime);
      lastInferenceDuration = elapsed;
      
      final textResponse = response.toString();
      lastTokensGenerated = (textResponse.length / 4).ceil(); // Average 4 characters per token
      lastInferenceSpeed = elapsed.inMilliseconds > 0 
          ? (lastTokensGenerated / (elapsed.inMilliseconds / 1000.0))
          : 0.0;
      
      // Peak GPU is ~6 Watts, CPU is ~3 Watts. Estimating Joule usage:
      final power = preferredBackend == PreferredBackend.gpu ? 6.0 : 3.0;
      estimatedEnergyConsumed = power * (elapsed.inMilliseconds / 1000.0);

      _resetIdleTimer();
      notifyListeners();

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
      return LlmResponse(text: 'Error generating response: $e');
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

  @override
  void dispose() {
    _downloader?.dispose();
    _idleTimer?.cancel();
    _activeModel?.close();
    super.dispose();
  }
}
