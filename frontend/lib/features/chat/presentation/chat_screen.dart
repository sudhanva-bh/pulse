import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/storage/secure_storage.dart';
import 'package:frontend/features/chat/presentation/chat_provider.dart';
import 'package:frontend/features/chat/presentation/widgets/message_bubble.dart';
import 'package:frontend/features/chat/presentation/widgets/message_input.dart';

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
        title: const Text('Chat'),
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
