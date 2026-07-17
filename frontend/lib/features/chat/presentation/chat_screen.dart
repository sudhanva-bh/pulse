import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/storage/secure_storage.dart';
import 'package:frontend/features/chat/presentation/chat_provider.dart';
import 'package:frontend/features/chat/presentation/widgets/message_bubble.dart';
import 'package:frontend/features/chat/presentation/widgets/message_input.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:frontend/core/network/websocket_manager.dart';
class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final id = await SecureStorage.getUserId();
    if (mounted) {
      setState(() {
        _currentUserId = id ?? 'unknown';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsyncValue = ref.watch(messagesProvider(widget.conversationId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chat'),
            Consumer(
              builder: (context, ref, child) {
                final stateAsync = ref.watch(connectionStateProvider);
                return stateAsync.when(
                  data: (state) {
                    if (state == WsConnectionState.connected) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FaIcon(FontAwesomeIcons.wifi, size: 12, color: Colors.green),
                          const SizedBox(width: 4),
                          Text('Connected', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      );
                    } else if (state == WsConnectionState.reconnecting) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LoadingAnimationWidget.progressiveDots(color: Colors.orange, size: 12),
                          const SizedBox(width: 4),
                          Text('Reconnecting...', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      );
                    }
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(FontAwesomeIcons.wifi, size: 12, color: Colors.red),
                        const SizedBox(width: 4),
                        Text('Disconnected', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _currentUserId == null 
              ? const Center(child: CircularProgressIndicator())
              : messagesAsyncValue.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }
                return ListView.builder(
                  reverse: true, // Display bottom-up
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return MessageBubble(
                      message: message,
                      isMe: message.senderId == _currentUserId,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
          Consumer(
            builder: (context, ref, child) {
              final typingAsync = ref.watch(typingStreamProvider);
              return typingAsync.when(
                data: (data) {
                  if (data['conversation_id'] == widget.conversationId && data['sender_id'] != _currentUserId) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: Row(
                        children: [
                          LoadingAnimationWidget.waveDots(color: Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Text('Typing...', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    );
                  }
                  return const SizedBox();
                },
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              );
            },
          ),
          MessageInput(
            conversationId: widget.conversationId,
            onSend: (content) {
              if (_currentUserId != null) {
                ref.read(messageRepositoryProvider).sendMessage(
                  widget.conversationId, 
                  content, 
                  _currentUserId!
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
