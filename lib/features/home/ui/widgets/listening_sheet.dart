import 'package:flutter/material.dart';

class ListeningSheet extends StatefulWidget {
  final bool isListening;
  final String recognizedText;
  final VoidCallback onStopListening;

  const ListeningSheet({
    super.key,
    required this.isListening,
    required this.recognizedText,
    required this.onStopListening,
  });

  @override
  State<ListeningSheet> createState() => _ListeningSheetState();
}

class _ListeningSheetState extends State<ListeningSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.isListening ? 'Listening...' : 'Processing...',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        _buildMicAnimation(),
        const SizedBox(height: 24),
        if (widget.recognizedText.isNotEmpty)
          Text(
            widget.recognizedText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
          ),
      ],
    );
  }

  Widget _buildMicAnimation() {
    return GestureDetector(
      onTap: widget.onStopListening,
      child: FadeTransition(
        opacity: Tween<double>(
          begin: 0.5,
          end: 1.0,
        ).animate(_animationController),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.2).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeInOut,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isListening
                  ? Colors.deepPurple.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.3),
            ),
            child: Icon(
              widget.isListening ? Icons.mic : Icons.stop,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}
