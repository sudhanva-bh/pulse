import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/chat/presentation/chat_provider.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  String _status = "Initializing sync...";
  double? _progress; // null means indeterminate
  bool _isFinished = false;
  int _totalMessagesLoaded = 0;

  @override
  void initState() {
    super.initState();
    _startSync();
  }

  Future<void> _startSync() async {
    try {
      final convRepo = ref.read(conversationRepositoryProvider);
      final msgRepo = ref.read(messageRepositoryProvider);

      setState(() {
        _status = "Fetching conversations...";
      });

      await convRepo.fetchConversations();

      // Get the local list of conversations we just fetched
      final conversations = await ref
          .read(conversationDaoProvider)
          .getAllConversations();

      if (conversations.isEmpty) {
        setState(() {
          _status = "No conversations found.";
          _progress = 1.0;
          _isFinished = true;
        });
        _proceed();
        return;
      }

      int i = 0;
      for (final conv in conversations) {
        setState(() {
          _status =
              "Syncing messages for conversation ${i + 1} of ${conversations.length}...";
          _progress = i / conversations.length;
        });

        int loaded = await msgRepo.fetchMessagesForConversation(conv.id);
        _totalMessagesLoaded += loaded;

        i++;
      }

      setState(() {
        _status = "Sync complete! $_totalMessagesLoaded messages loaded.";
        _progress = 1.0;
        _isFinished = true;
      });

      _proceed();
    } catch (e) {
      setState(() {
        _status = "Sync failed. Proceeding anyway...";
        _progress = 1.0;
        _isFinished = true;
      });
      _proceed();
    }
  }

  Future<void> _proceed() async {
    // Show the final message for a brief moment before proceeding
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sync, size: 64, color: Colors.blue),
              const SizedBox(height: 24),
              Text(
                "Syncing Data",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 16),
              Text(
                _status,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (_isFinished) ...[
                const SizedBox(height: 24),
                const Icon(Icons.check_circle, color: Colors.green, size: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
