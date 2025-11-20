import 'package:flutter/material.dart';
import 'package:flutter_ui_agent/flutter_ui_agent.dart';

import 'features/home/ui/pages/home_page.dart';

class SmartHomeApp extends StatelessWidget {
  final AgentService agentService;
  const SmartHomeApp({super.key, required this.agentService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agentic Smart Home',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ).copyWith(surface: const Color(0xFF121212)),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1F1F1F),
          elevation: 0,
        ),
      ),
      home: SmartHomePage(agentService: agentService),
      debugShowCheckedModeBanner: false,
    );
  }
}
