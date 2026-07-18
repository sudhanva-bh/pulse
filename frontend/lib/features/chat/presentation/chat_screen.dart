import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/storage/secure_storage.dart';
import 'package:frontend/features/chat/presentation/chat_provider.dart';
import 'package:frontend/features/chat/presentation/widgets/message_bubble.dart';
import 'package:frontend/features/chat/presentation/widgets/message_input.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:frontend/core/network/websocket_manager.dart';
import 'package:frontend/features/chat/domain/message.dart';
import 'package:go_router/go_router.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  String? _currentUserId;
  bool _isTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    super.dispose();
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
    ref.listen(typingStreamProvider, (prev, next) {
      if (next.hasValue && next.value != null) {
        final data = next.value!;
        if (data['conversation_id'] == widget.conversationId &&
            data['sender_id'] != _currentUserId) {
          setState(() {
            _isTyping = true;
          });
          _typingTimer?.cancel();
          _typingTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _isTyping = false;
              });
            }
          });
        }
      }
    });

    final messagesAsyncValue = ref.watch(
      messagesProvider(widget.conversationId),
    );
    final conversationsAsyncValue = ref.watch(conversationsProvider);

    final conversation = conversationsAsyncValue.value?.firstWhere(
      (c) => c.id == widget.conversationId,
      orElse: () => throw Exception('Conversation not found'),
    );

    Widget bottomWidget;
    if (conversation == null) {
      bottomWidget = const SizedBox.shrink();
    } else if (conversation.status == 'pending') {
      bottomWidget = Container(
        color: Colors.orange.withValues(alpha: 0.1),
        padding: const EdgeInsets.all(16),
        child: Text(
          conversation.initiatorId == _currentUserId
              ? 'Waiting for user to accept your chat request...'
              : 'Accept request from the Chat Requests tab to reply.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (conversation.status == 'rejected') {
      bottomWidget = Container(
        color: Colors.red.withValues(alpha: 0.1),
        padding: const EdgeInsets.all(16),
        child: const Text(
          'Your chat request was declined.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
      );
    } else {
      bottomWidget = MessageInput(
        conversationId: widget.conversationId,
        onSend: (content) {
          if (_currentUserId != null) {
            ref
                .read(messageRepositoryProvider)
                .sendMessage(widget.conversationId, content, _currentUserId!);
          }
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(conversation?.title ?? 'Chat'),
            Consumer(
              builder: (context, ref, child) {
                final state = ref.watch(connectionStateProvider);
                if (state == WsConnectionState.connected) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.wifi,
                        size: 12,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Connected',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  );
                } else if (state == WsConnectionState.reconnecting) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LoadingAnimationWidget.progressiveDots(
                        color: Colors.orange,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Reconnecting...',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  );
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.wifi,
                      size: 12,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Disconnected',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(connectionStateProvider);
              final isDisconnected = state != WsConnectionState.connected;
              if (isDisconnected) {
                return PopupMenuButton<String>(
                  icon: const FaIcon(FontAwesomeIcons.networkWired, size: 20),
                  onSelected: (value) {
                    if (value == 'share') {
                      context.push('/lan/share');
                    } else if (value == 'scan') {
                      context.push('/lan/scan');
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'share',
                      child: Text('Send via Local Network'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'scan',
                      child: Text('Receive via Local Network'),
                    ),
                  ],
                );
              }
              return const SizedBox();
            },
          ),
          const SizedBox(width: 16),
        ],
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
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                  ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
              child: Row(
                children: [
                  LoadingAnimationWidget.waveDots(color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Typing...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(connectionStateProvider);
              final isDisconnected = state != WsConnectionState.connected;
              
              bool hasUnsynced = false;
              if (messagesAsyncValue.hasValue) {
                final messages = messagesAsyncValue.value!;
                hasUnsynced = messages.any((m) => 
                  !m.syncedToCloud && 
                  m.senderId == _currentUserId && 
                  m.status != MessageStatus.deliveredLocally
                );
              }

              return _LanBanner(shouldShow: isDisconnected && hasUnsynced);
            },
          ),
          bottomWidget,
        ],
      ),
    );
  }
}

class _LanBanner extends StatefulWidget {
  final bool shouldShow;
  
  const _LanBanner({required this.shouldShow});

  @override
  State<_LanBanner> createState() => _LanBannerState();
}

class _LanBannerState extends State<_LanBanner> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateState(widget.shouldShow);
  }

  @override
  void didUpdateWidget(covariant _LanBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shouldShow != widget.shouldShow) {
      _updateState(widget.shouldShow);
    }
  }

  void _updateState(bool shouldShow) {
    if (shouldShow) {
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _visible = true);
        }
      });
    } else {
      _timer?.cancel();
      if (_visible && mounted) {
        setState(() => _visible = false);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    
    return Container(
      color: Colors.blue.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          const FaIcon(FontAwesomeIcons.networkWired, color: Colors.blue, size: 16),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'You have queued messages. Send via Local Network?',
              style: TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () {
              context.push('/lan/share');
            },
            child: const Text('Share QR'),
          )
        ],
      ),
    );
  }
}
