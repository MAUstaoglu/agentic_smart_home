import 'package:flutter/material.dart';

/// A widget for user input, including a text field and buttons for sending
/// a command or initiating speech-to-text.
class ChatBar extends StatefulWidget {
  final TextEditingController textController;
  final bool isAgentProcessing;
  final bool isListening;
  final bool speechAvailable;
  final double soundLevel;
  final VoidCallback onToggleListening;
  final ValueChanged<String> onProcessCommand;

  const ChatBar({
    super.key,
    required this.textController,
    required this.isAgentProcessing,
    required this.isListening,
    required this.speechAvailable,
    this.soundLevel = 0.0,
    required this.onToggleListening,
    required this.onProcessCommand,
  });

  @override
  State<ChatBar> createState() => _ChatBarState();
}

class _ChatBarState extends State<ChatBar> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.fromLTRB(16, widget.isListening ? 24 : 8, 16, 16),
      decoration: BoxDecoration(
        color: widget.isListening
            ? theme.primaryColor.withValues(alpha: 0.1)
            : theme.scaffoldBackgroundColor,
        border: widget.isListening
            ? Border(top: BorderSide(color: theme.primaryColor, width: 2))
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status indicator when listening
          if (widget.isListening) ...[
            Row(
              children: [
                _buildPulsingMicIcon(theme),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.textController.text.isEmpty
                        ? 'Listening...'
                        : 'Hearing you...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          // Input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.textController,
                  maxLines: 5,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: widget.isListening
                        ? 'Your command appears here...'
                        : 'Enter a command...',
                    filled: true,
                    fillColor: theme.brightness == Brightness.dark
                        ? Colors.white10
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    prefixIcon: widget.isListening
                        ? Icon(Icons.mic, color: theme.primaryColor)
                        : null,
                  ),
                  onSubmitted: widget.onProcessCommand,
                ),
              ),
              const SizedBox(width: 8),
              if (widget.isAgentProcessing)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                )
              else ...[
                // Mic button with animation
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isListening
                        ? theme.primaryColor
                        : (widget.speechAvailable
                              ? theme.primaryColor.withValues(alpha: 0.1)
                              : Colors.transparent),
                  ),
                  child: IconButton(
                    icon: Icon(
                      widget.isListening ? Icons.stop : Icons.mic,
                      color: widget.isListening
                          ? Colors.white
                          : (widget.speechAvailable
                                ? theme.primaryColor
                                : theme.disabledColor),
                    ),
                    onPressed: widget.speechAvailable
                        ? widget.onToggleListening
                        : null,
                    tooltip: widget.isListening
                        ? 'Stop listening'
                        : 'Start speech recognition',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: theme.primaryColor,
                  onPressed: () =>
                      widget.onProcessCommand(widget.textController.text),

                  tooltip: 'Send command',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingMicIcon(ThemeData theme) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.primaryColor.withValues(alpha: 0.2),
        ),
        child: Icon(Icons.mic, color: theme.primaryColor, size: 20),
      ),
    );
  }
}
