import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_ui_agent/flutter_ui_agent.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/services/llm_provider.dart';
import 'features/home/providers/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterGemma.initialize();

  final agentService = AgentService();
  final llmProvider = GemmaLlmProvider();

  llmProvider.configure(apiKey: '');

  agentService.setLlmProvider(
    llmProvider,
    config: const AgentConfig(
      logLevel: AgentLogLevel.info,
      enableAnalytics: true,
      debugMode: true,
    ),
  );

  runApp(
    AgentHost(
      agentService: agentService,
      child: ChangeNotifierProvider(
        create: (context) => AppState(),
        child: SmartHomeApp(agentService: agentService),
      ),
    ),
  );
}
