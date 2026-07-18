import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/chat/domain/message.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:frontend/core/services/file_transfer_service.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';

class MessageBubble extends ConsumerWidget {
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
      case MessageStatus.deliveredLocally:
        return FontAwesomeIcons.networkWired;
      case MessageStatus.failed:
        return FontAwesomeIcons.circleExclamation;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final transferState = ref.watch(fileTransferProvider)[message.id];

    final bool hasAttachment = message.attachmentName != null;
    final bool isDownloaded =
        message.attachmentUri != null &&
        File(message.attachmentUri!).existsSync();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasAttachment) ...[
              GestureDetector(
                onTap: isDownloaded
                    ? () {
                        OpenFilex.open(message.attachmentUri!);
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.insert_drive_file, size: 32),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.attachmentName!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (message.attachmentSize != null)
                              Text(
                                '${(message.attachmentSize! / 1024 / 1024).toStringAsFixed(2)} MB',
                                style: const TextStyle(fontSize: 12),
                              ),
                            if (transferState != null &&
                                transferState.status !=
                                    TransferStatus.completed) ...[
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: transferState.totalBytes > 0
                                    ? transferState.bytesTransferred /
                                          transferState.totalBytes
                                    : 0,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isDownloaded ||
                          (transferState != null &&
                              transferState.status == TransferStatus.completed))
                        const Icon(Icons.check_circle, color: Colors.green)
                      else if (transferState == null && !isMe)
                        IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () {
                            ref
                                .read(fileTransferProvider.notifier)
                                .startDownload(
                                  message.id,
                                  message.attachmentName!,
                                  message.attachmentSize ?? 0,
                                );
                          },
                        )
                      else if (transferState != null &&
                          transferState.status == TransferStatus.paused)
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: () {
                            ref
                                .read(fileTransferProvider.notifier)
                                .startDownload(
                                  message.id,
                                  message.attachmentName!,
                                  message.attachmentSize ?? 0,
                                );
                          },
                        )
                      else if (transferState != null &&
                          (transferState.status == TransferStatus.sending ||
                              transferState.status == TransferStatus.receiving))
                        IconButton(
                          icon: const Icon(Icons.pause),
                          onPressed: () {
                            ref
                                .read(fileTransferProvider.notifier)
                                .pauseTransfer(message.id);
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    hasAttachment
                        ? message.content
                              .replaceFirst(
                                'Attachment: ${message.attachmentName}',
                                '',
                              )
                              .trim()
                        : message.content,
                    style: TextStyle(
                      color: isMe
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
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
          ],
        ),
      ),
    );
  }
}
