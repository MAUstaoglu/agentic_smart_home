import 'package:flutter/material.dart';

class PulsingMicIcon extends StatefulWidget {
  final bool isListening;
  final VoidCallback onPressed;

  const PulsingMicIcon({
    super.key,
    required this.isListening,
    required this.onPressed,
  });

  @override
  State<PulsingMicIcon> createState() => _PulsingMicIconState();
}

class _PulsingMicIconState extends State<PulsingMicIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.isListening) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulsingMicIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening != oldWidget.isListening) {
      if (widget.isListening) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      child: widget.isListening
          ? FadeTransition(
              opacity: _animation,
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.8),
                ),
                child: const Icon(Icons.mic, color: Colors.white),
              ),
            )
          : Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
              ),
              child: const Icon(Icons.mic_none, color: Colors.black),
            ),
    );
  }
}
