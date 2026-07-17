import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/chat/presentation/chat_provider.dart';

class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key});

  @override
  ConsumerState<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends ConsumerState<ConversationListScreen> {

  @override
  Widget build(BuildContext context) {
    final conversationsAsyncValue = ref.watch(acceptedConversationsProvider);
    final requestsCountAsyncValue = ref.watch(unreadRequestsCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pulse'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.person_add),
                onPressed: () {
                  context.push('/requests');
                },
              ),
              requestsCountAsyncValue.when(
                data: (count) {
                  if (count > 0) {
                    return Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
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
              
              String subtitleText = conv.lastMessageContent ?? 'No messages yet';
              Color? subtitleColor;
              if (conv.status == 'pending') {
                subtitleText = 'Pending confirmation...';
                subtitleColor = Colors.orange;
              } else if (conv.status == 'rejected') {
                subtitleText = 'Request was unsuccessful';
                subtitleColor = Colors.red;
              }
              
              return ListTile(
                leading: CircleAvatar(
                  child: Text(conv.title?.substring(0, 1).toUpperCase() ?? conv.id.substring(0, 1).toUpperCase()),
                ),
                title: Text(conv.title ?? 'Conversation ${conv.id.substring(0, 4)}'),
                subtitle: Text(
                  subtitleText, 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: subtitleColor),
                ),
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
              title: const Text('Send Chat Request'),
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
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send request.')));
                        }
                      }
                    }
                  },
                  child: const Text('Send'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add_comment),
      ),
    );
  }
}
