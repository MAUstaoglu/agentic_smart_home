import 'package:flutter/material.dart';

class SpeechRecognitionSheet extends StatefulWidget {
  final String recognizedText;
  final bool isListening;
  final double soundLevel; // New: For animation
  final VoidCallback onStopListening;
  final VoidCallback onCancel;
  final Function(String) onSend;

  const SpeechRecognitionSheet({
    super.key,
    required this.recognizedText,
    required this.isListening,
    this.soundLevel = 0.0,
    required this.onStopListening,
    required this.onCancel,
    required this.onSend,
  });

  @override
  State<SpeechRecognitionSheet> createState() => _SpeechRecognitionSheetState();
}

class _SpeechRecognitionSheetState extends State<SpeechRecognitionSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _textController = TextEditingController(text: widget.recognizedText);
  }

  @override
  void didUpdateWidget(SpeechRecognitionSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recognizedText != oldWidget.recognizedText) {
      _textController.text = widget.recognizedText;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Status Text
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              widget.isListening
                  ? (widget.recognizedText.isEmpty
                        ? 'Listening...'
                        : 'Hearing you...')
                  : 'Tap Send to continue',
              key: ValueKey(widget.isListening),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: widget.isListening ? theme.primaryColor : null,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Microphone Animation
          _buildMicAnimation(theme),
          const SizedBox(height: 32),

          // Text Input
          TextField(
            controller: _textController,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Say something like "Turn on the lights"...',
              filled: true,
              fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: FilledButton.icon(
                  onPressed: _textController.text.isNotEmpty
                      ? () => widget.onSend(_textController.text)
                      : null,
                  icon: Icon(widget.isListening ? Icons.stop : Icons.send),
                  label: Text(widget.isListening ? 'Stop & Send' : 'Send'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMicAnimation(ThemeData theme) {
    // Use sound level to scale the outer ring if available, otherwise pulse
    final double scale = widget.isListening
        ? 1.0 + (widget.soundLevel > 0 ? widget.soundLevel / 10 : 0.0)
        : 1.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer Ripple
        if (widget.isListening)
          ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.4).animate(
              CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
            ),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withValues(alpha: 0.2),
              ),
            ),
          ),
        // Inner Dynamic Ring
        AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 80 * scale.clamp(1.0, 1.5),
          height: 80 * scale.clamp(1.0, 1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.primaryColor.withValues(alpha: 0.3),
          ),
        ),
        // Mic Icon Background
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isListening
                ? theme.primaryColor
                : theme.disabledColor.withValues(alpha: 0.2),
            boxShadow: [
              if (widget.isListening)
                BoxShadow(
                  color: theme.primaryColor.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
            ],
          ),
          child: Icon(
            widget.isListening ? Icons.mic : Icons.mic_none,
            color: Colors.white,
            size: 32,
          ),
        ),
      ],
    );
  }
}
