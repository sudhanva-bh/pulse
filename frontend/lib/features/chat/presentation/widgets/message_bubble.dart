import 'package:flutter/material.dart';
import 'package:frontend/features/chat/domain/message.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  FaIconData _getStatusIcon() {
    switch (message.status) {
      case MessageStatus.pending:
      case MessageStatus.sending:
      case MessageStatus.queued:
        return FontAwesomeIcons.clock;
      case MessageStatus.sent:
        return FontAwesomeIcons.check;
      case MessageStatus.delivered:
      case MessageStatus.read:
        return FontAwesomeIcons.checkDouble;
      case MessageStatus.failed:
        return FontAwesomeIcons.circleExclamation;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isMe
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe ? const Radius.circular(0) : null,
            bottomLeft: !isMe ? const Radius.circular(0) : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isMe
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            if (isMe)
              FaIcon(
                _getStatusIcon(),
                size: 12,
                color: message.status == MessageStatus.failed
                    ? theme.colorScheme.error
                    : theme.colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.7,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
