import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ui_agent/flutter_ui_agent.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:synced_page_views/synced_page_views.dart';

import '../../providers/app_state.dart';
import '../widgets/chat_bar.dart';
import '../widgets/room_page.dart';

class SmartHomePage extends StatefulWidget {
  final AgentService agentService;
  final AppState appState;

  const SmartHomePage({
    super.key,
    required this.agentService,
    required this.appState,
  });

  @override
  State<SmartHomePage> createState() => _SmartHomePageState();
}

class _SmartHomePageState extends State<SmartHomePage> {
  final _textController = TextEditingController();
  final _syncedController = SyncedPageController(
    secondaryViewportFraction: 0.25,
  );
  bool _isAgentProcessing = false;

  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;
  double _soundLevel = 0.0;

  @override
  void dispose() {
    _syncedController.dispose();
    _textController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.appState.rooms.isNotEmpty) {
        widget.agentService.setCurrentPage(
          widget.appState.rooms[0].name.replaceAll(' ', '_').toLowerCase(),
        );
      }
    });
  }

  void _initSpeech() async {
    _speech = stt.SpeechToText();
    _speechAvailable = await _speech.initialize(
      onStatus: (status) => debugPrint('Speech status: $status'),
      onError: (error) => debugPrint('Speech error: $error'),
    );
    setState(() {});
  }

  void _listen() async {
    if (!_speechAvailable) {
      debugPrint('Speech recognition not available');
      return;
    }
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
      });
      if (_textController.text.isNotEmpty) {
        _processCommand(_textController.text);
      }
    } else {
      setState(() {
        _isListening = true;
        _textController.clear();
        _soundLevel = 0.0;
      });
      _speech.listen(
        onResult: (result) {
          setState(() {
            _textController.text = result.recognizedWords;
          });
          if (result.finalResult) {
            if (mounted) {
              setState(() => _isListening = false);
              if (_textController.text.isNotEmpty) {
                _processCommand(_textController.text);
              }
            }
          }
        },
        onSoundLevelChange: (level) {
          setState(() {
            _soundLevel = level;
          });
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          onDevice: true,
          listenMode: stt.ListenMode.confirmation,
        ),
      );
    }
  }

  Future<void> _processCommand(String command) async {
    if (command.isEmpty || _isAgentProcessing || !mounted) return;
    setState(() => _isAgentProcessing = true);

    try {
      final result = await widget.agentService.processQueryWithNavigation(
        command,
      );
      debugPrint('Agent response: $result');
    } catch (e) {
      debugPrint('Error processing command: $e');
    } finally {
      if (mounted) {
        setState(() => _isAgentProcessing = false);
        _textController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, child) {
        final appState = widget.appState;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Agentic Smart Home'),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: AiActionWidget(
                    actionId: 'switch_room_page',
                    description: 'Switch to a different room page',
                    parameters: [
                      AgentActionParameter.string(
                        name: 'room_name',
                        enumValues: appState.rooms.map((r) => r.name).toList(),
                      ),
                    ],
                    onExecuteWithParamsAsync: (params) async {
                      final roomName = params['room_name'] as String?;
                      if (roomName != null) {
                        final index = appState.rooms.indexWhere(
                          (room) =>
                              room.name.toLowerCase() == roomName.toLowerCase(),
                        );
                        if (index != -1) {
                          await _syncedController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      }
                    },
                    child: SyncedPageViews(
                      controller: _syncedController,
                      itemCount: appState.rooms.length,
                      onPageChanged: (index) {
                        widget.agentService.setCurrentPage(
                          appState.rooms[index].name
                              .replaceAll(' ', '_')
                              .toLowerCase(),
                        );
                      },
                      primaryItemBuilder: (context, index) {
                        return RoomPage(
                          room: appState.rooms[index],
                          appState: appState,
                        );
                      },
                      secondaryItemBuilder: (context, index) {
                        final room = appState.rooms[index];
                        return SizedBox(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F1F1F),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            width: 50,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    room.lightOn
                                        ? Icons.lightbulb
                                        : Icons.lightbulb_outline,
                                    color: room.lightOn
                                        ? room.ambientColor
                                        : Colors.grey,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    room.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      layoutBuilder: (primary, secondary) => Column(
                        children: [
                          Expanded(child: primary),
                          SizedBox(height: 80, child: secondary),
                        ],
                      ),
                      onSecondaryPageTap: (index) {
                        _syncedController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
                ),
                ChatBar(
                  textController: _textController,
                  isAgentProcessing: _isAgentProcessing,
                  isListening: _isListening,
                  speechAvailable: _speechAvailable,
                  soundLevel: _soundLevel,
                  onToggleListening: _listen,
                  onProcessCommand: _processCommand,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
