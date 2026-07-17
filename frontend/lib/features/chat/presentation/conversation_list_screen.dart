import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/chat/domain/conversation.dart';
import 'package:frontend/features/chat/presentation/chat_provider.dart';
import 'package:uuid/uuid.dart';

class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key});

  @override
  ConsumerState<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends ConsumerState<ConversationListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(conversationRepositoryProvider).fetchConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsyncValue = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pulse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/settings');
            },
          ),
        ],
      ),
      body: conversationsAsyncValue.when(
        data: (conversations) {
          if (conversations.isEmpty) {
            return const Center(child: Text('No conversations yet.'));
          }
          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conv = conversations[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(conv.id.substring(0, 1).toUpperCase()),
                ),
                title: Text('Conversation ${conv.id.substring(0, 4)}'),
                subtitle: const Text('Tap to view messages'),
                onTap: () {
                  context.push('/chat/${conv.id}');
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final controller = TextEditingController();
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('New Conversation'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Username to chat with'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (controller.text.isNotEmpty) {
                      final nav = Navigator.of(context);
                      try {
                        await ref.read(conversationRepositoryProvider).createConversation(controller.text);
                        nav.pop();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create conversation. User may not exist.')));
                        }
                      }
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.message),
      ),
    );
  }
}
