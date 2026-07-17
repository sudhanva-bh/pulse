import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/storage/secure_storage.dart';
import 'package:frontend/core/network/websocket_manager.dart';
import 'dart:async';

class MessageInput extends ConsumerStatefulWidget {
  final String conversationId;
  final Function(String content) onSend;

  const MessageInput({
    super.key,
    required this.conversationId,
    required this.onSend,
  });

  @override
  ConsumerState<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<MessageInput> {
  late TextEditingController _controller;
  Timer? _debounce;
  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadDraft();
    _controller.addListener(_onTextChanged);
  }

  Future<void> _loadDraft() async {
    final draft = await SecureStorage.getDraft(widget.conversationId);
    if (draft != null && draft.isNotEmpty && mounted) {
      _controller.text = draft;
    }
  }

  void _onTextChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        SecureStorage.saveDraft(widget.conversationId, _controller.text);
      }
    });

    if (!(_typingDebounce?.isActive ?? false) && _controller.text.isNotEmpty) {
      ref.read(webSocketManagerProvider).sendTyping(widget.conversationId);
      _typingDebounce = Timer(const Duration(seconds: 2), () {});
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _typingDebounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    widget.onSend(text);
    _controller.clear();
    SecureStorage.clearDraft(widget.conversationId);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            color: Theme.of(context).colorScheme.primary,
            onPressed: _handleSend,
          ),
        ],
      ),
    );
  }
}
