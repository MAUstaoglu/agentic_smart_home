import 'package:flutter/material.dart';
import '../../../../core/services/llm_provider.dart';

class LlmSetupWidget extends StatelessWidget {
  final GemmaLlmProvider provider;

  const LlmSetupWidget({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F0C20),
              Color(0xFF15102A),
              Color(0xFF0D0A1C),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Logo / Icon
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(seconds: 1),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.scale(
                            scale: 0.8 + (0.2 * value),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurpleAccent.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                          gradient: const LinearGradient(
                            colors: [Colors.deepPurpleAccent, Colors.indigoAccent],
                          ),
                        ),
                        child: const Icon(
                          Icons.psychology,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title & Description
                    const Text(
                      'Local Intelligence Setup',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Agentic Smart Home processes commands locally using on-device AI. '
                      'Your voice data remains completely private, secure, and offline. '
                      'To begin, please download and initialize the language model.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Setup Card
                    Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!provider.isInstalled) ...[
                            _buildSelectionAndDownloadSection(context)
                          ] else ...[
                            _buildLoadingSection(context)
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Technical Note Footer
                    Text(
                      'Note: Gemma 2B requires at least 2.5 GB of free RAM. '
                      'For evaluating the UI quickly, use the Mock model.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.4),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionAndDownloadSection(BuildContext context) {
    final status = provider.downloadStatus;
    final isIdle = status == 'idle';
    final isDownloading = status == 'downloading';
    final isPaused = status == 'paused';
    final isFailed = status == 'failed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isIdle) ...[
          const Text(
            'Choose Download Option',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          // Option 1: Mock Model
          _buildOptionCard(
            context,
            icon: Icons.speed,
            title: 'Mock Test Model',
            subtitle: 'Size: 10 MB • Instant Setup',
            description: 'Highly recommended for quick testing of resumption, progress bars, and voice control simulations.',
            onTap: () => provider.startDownload(isMock: true),
          ),
          const SizedBox(height: 12),
          
          // Option 2: Full Gemma
          _buildOptionCard(
            context,
            icon: Icons.cloud_download,
            title: 'Full Gemma Model',
            subtitle: 'Size: 1.4 GB • Real On-Device AI',
            description: 'Download the actual Gemma-2B quantized weights to run inference directly on your device\'s GPU.',
            onTap: () => provider.startDownload(isMock: false),
          ),
        ] else ...[
          // Downloading / Paused / Failed Progress UI
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getStatusIcon(status),
                  color: _getStatusColor(status),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getStatusText(status),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Custom Premium Progress Bar (Requirement 3)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
              ),
              child: Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: constraints.maxWidth * provider.downloadProgress,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [Colors.deepPurpleAccent, Colors.cyanAccent],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Download stats details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(provider.downloadProgress * 100).toStringAsFixed(1)}% Completed',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              if (isDownloading)
                Text(
                  '${provider.downloadSpeedMb.toStringAsFixed(2)} MB/s',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.cyanAccent,
                  ),
                ),
            ],
          ),
          
          if (provider.downloadTimeRemaining != Duration.zero && isDownloading) ...[
            const SizedBox(height: 4),
            Text(
              'Estimated time remaining: ${_formatDuration(provider.downloadTimeRemaining)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
          
          if (isFailed && provider.downloadError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
              ),
              child: Text(
                'Error: ${provider.downloadError}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Control Action Buttons (Requirement 1 & 3)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isDownloading) ...[
                ElevatedButton.icon(
                  onPressed: provider.pauseDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.08),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.pause, size: 16),
                  label: const Text('Pause'),
                ),
              ],
              if (isPaused) ...[
                ElevatedButton.icon(
                  onPressed: () => provider.startDownload(isMock: provider.downloadProgress < 0.05), // Resume
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Resume'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: provider.resetDownload,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset'),
                ),
              ],
              if (isFailed) ...[
                ElevatedButton.icon(
                  onPressed: () => provider.startDownload(isMock: provider.downloadProgress < 0.05),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: provider.resetDownload,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withOpacity(0.6),
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset'),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingSection(BuildContext context) {
    final isLoading = provider.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.greenAccent,
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Model Ready to Load',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'The model weights are downloaded successfully. '
          'We now need to load the model into your system memory.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 24),

        if (isLoading) ...[
          // Loading Progress Bar with Micro-Animations (Requirement 4)
          Text(
            provider.loadStatus,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.deepPurpleAccent,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: provider.loadProgress,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(provider.loadProgress * 100).toStringAsFixed(0)}%',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ] else ...[
          // Load Model Call to Action Button
          ElevatedButton(
            onPressed: provider.loadModel,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: Colors.deepPurpleAccent.withOpacity(0.4),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.power, size: 20),
                SizedBox(width: 10),
                Text(
                  'Load Model & Start',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: provider.resetDownload,
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent.withOpacity(0.8),
            ),
            child: const Text('Delete Model File & Restart'),
          ),
        ],
      ],
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.05),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.deepPurpleAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.cyanAccent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'downloading':
        return Colors.cyanAccent;
      case 'paused':
        return Colors.orangeAccent;
      case 'failed':
        return Colors.redAccent;
      case 'completed':
        return Colors.greenAccent;
      default:
        return Colors.white;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'downloading':
        return Icons.downloading;
      case 'paused':
        return Icons.pause_circle_filled;
      case 'failed':
        return Icons.error;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'downloading':
        return 'Downloading model...';
      case 'paused':
        return 'Download Paused';
      case 'failed':
        return 'Download Failed';
      case 'completed':
        return 'Download Completed';
      default:
        return 'Preparing...';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return 'Calculating...';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
