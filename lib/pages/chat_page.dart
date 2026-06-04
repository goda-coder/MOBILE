import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/api_models.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../widgets/app_button.dart';
import '../widgets/status_pill.dart';

final _conversationsProvider = FutureProvider.autoDispose(
  (ref) => ref.read(chatApiProvider).conversations(),
);

final _messagesProvider = FutureProvider.family.autoDispose(
  (ref, String userId) => ref.read(chatApiProvider).messages(userId: userId),
);

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, this.userId});
  final String? userId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(String targetUserId) async {
    if (_controller.text.trim().isEmpty) {
      setState(() => _error = 'Enter a message before sending.');
      return;
    }
    setState(() {
      _error = null;
      _sending = true;
    });
    try {
      await ref.read(chatApiProvider).send(
            content: _controller.text.trim(),
            userId: targetUserId,
          );
      _controller.clear();
      ref.invalidate(_messagesProvider(targetUserId));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider).value;
    final isAdmin = auth?.role == Role.admin;
    final currentUserId = auth?.userId ?? '';
    final targetUserId = isAdmin ? widget.userId : currentUserId;

    if (isAdmin && targetUserId == null) {
      final conv = ref.watch(_conversationsProvider);
      return Scaffold(
        appBar: AppBar(title: const Text('Support chat')),
        body: conv.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: ErrorCard(message: e.toString())),
          data: (list) => ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final conversation = list[index];
              return Card(
                child: ListTile(
                  title: Text('User ${conversation.userId}'),
                  subtitle: Text(conversation.lastMessage.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Text('${conversation.messageCount} msgs'),
                  onTap: () => context.push('/chat?userId=${conversation.userId}'),
                ),
              );
            },
          ),
        ),
      );
    }

    if (targetUserId == null || targetUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Support chat')),
        body: const Center(child: Text('Unable to determine chat conversation.')),
      );
    }

    final messages = ref.watch(_messagesProvider(targetUserId));
    return Scaffold(
      appBar: AppBar(title: const Text('Support chat')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messages.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: ErrorCard(message: e.toString())),
                data: (list) {
                  if (list.isEmpty) {
                    return const Center(child: Text('No messages. Start the conversation.'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (_, index) {
                      final message = list[index];
                      final isMine = message.senderId == currentUserId;
                      return Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isMine ? AppColors.brandPrimary : AppColors.ink700,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(message.content, style: const TextStyle(color: Colors.white)),
                              const SizedBox(height: 8),
                              Text(
                                '${message.senderRole} • ${message.createdAt.toLocal()}',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_error != null) Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ErrorCard(message: _error!),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Type a message...'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AppButton(
                    label: 'Send',
                    icon: Icons.send,
                    loading: _sending,
                    onPressed: () => _send(targetUserId),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
