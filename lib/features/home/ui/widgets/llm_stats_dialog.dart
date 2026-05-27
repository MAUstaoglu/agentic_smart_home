import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import '../../../../core/services/llm_provider.dart';

class LlmStatsDialog extends StatefulWidget {
  final GemmaLlmProvider provider;

  const LlmStatsDialog({super.key, required this.provider});

  @override
  State<LlmStatsDialog> createState() => _LlmStatsDialogState();
}

class _LlmStatsDialogState extends State<LlmStatsDialog> {
  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        return Dialog(
          backgroundColor: const Color(0xFF15102A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24.0),
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.query_stats, color: Colors.cyanAccent),
                          SizedBox(width: 8),
                          Text(
                            'LLM & Energy Monitor',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white60),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),

                  // Section 1: Telemetry Dashboard
                  const Text(
                    'LATEST INFERENCE METRICS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Stats Grid
                  _buildStatsGrid(provider),
                  const SizedBox(height: 24),

                  // Section 2: Model Memory Status
                  const Text(
                    'MODEL MEMORY CACHE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCacheStatusCard(provider),
                  const SizedBox(height: 24),

                  // Section 3: Energy Settings
                  const Text(
                    'ENERGY SAVER CONFIGURATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Preferred Backend
                  _buildSettingRow(
                    title: 'Execution Backend',
                    subtitle: 'GPU is ~60% more energy efficient due to speed.',
                    trailing: DropdownButton<PreferredBackend>(
                      value: provider.preferredBackend,
                      dropdownColor: const Color(0xFF1F1A3A),
                      underline: const SizedBox(),
                      style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                      onChanged: (backend) {
                        if (backend != null) {
                          provider.setPreferredBackend(backend);
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                          value: PreferredBackend.gpu,
                          child: Text('GPU (Fast)'),
                        ),
                        DropdownMenuItem(
                          value: PreferredBackend.cpu,
                          child: Text('CPU (Slow)'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Idle Timeout
                  _buildSettingRow(
                    title: 'Memory Standby Timeout',
                    subtitle: 'Auto-unload the model after inactivity.',
                    trailing: DropdownButton<int>(
                      value: provider.cacheTimeoutSeconds,
                      dropdownColor: const Color(0xFF1F1A3A),
                      underline: const SizedBox(),
                      style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                      onChanged: (seconds) {
                        if (seconds != null) {
                          provider.setCacheTimeout(seconds);
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 30,
                          child: Text('30 sec'),
                        ),
                        DropdownMenuItem(
                          value: 60,
                          child: Text('1 min'),
                        ),
                        DropdownMenuItem(
                          value: 120,
                          child: Text('2 min'),
                        ),
                        DropdownMenuItem(
                          value: 300,
                          child: Text('5 min'),
                        ),
                        DropdownMenuItem(
                          value: 0,
                          child: Text('Never'),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Reset Button
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      provider.resetDownload();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: const Text('Uninstall Model Weights'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(GemmaLlmProvider provider) {
    final latencyText = provider.lastInferenceDuration == Duration.zero
        ? 'N/A'
        : '${provider.lastInferenceDuration.inMilliseconds} ms';

    final speedText = provider.lastInferenceSpeed == 0.0
        ? 'N/A'
        : '${provider.lastInferenceSpeed.toStringAsFixed(1)} tok/s';

    final energyText = provider.estimatedEnergyConsumed == 0.0
        ? 'N/A'
        : '${provider.estimatedEnergyConsumed.toStringAsFixed(2)} J';

    final tokensText = provider.lastTokensGenerated == 0
        ? 'N/A'
        : '${provider.lastTokensGenerated}';

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _buildStatCard('Inference Speed', speedText, Icons.bolt, Colors.amberAccent),
        _buildStatCard('Latency Duration', latencyText, Icons.timer, Colors.cyanAccent),
        _buildStatCard('Tokens Output', tokensText, Icons.text_fields, Colors.greenAccent),
        _buildStatCard('Est. Energy Cost', energyText, Icons.battery_charging_full, Colors.lightGreenAccent),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.4),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheStatusCard(GemmaLlmProvider provider) {
    final loaded = provider.isModelLoaded;
    final statusColor = loaded ? Colors.greenAccent : Colors.white24;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            height: 12,
            width: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: loaded ? [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ] : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loaded ? 'Active Cache: Loaded in RAM' : 'Standby Cache: Closed',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  loaded
                      ? 'Inference starts instantly. Consuming low memory standby power.'
                      : 'Next query will load the model (takes ~3s) and compile shaders.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          if (loaded) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: provider.unloadModel,
              style: TextButton.styleFrom(
                foregroundColor: Colors.orangeAccent,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Unload'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        trailing,
      ],
    );
  }
}
