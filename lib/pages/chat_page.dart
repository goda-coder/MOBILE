import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' hide ChatMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/api_models.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
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
  final _chatController = InMemoryChatController();

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  void _syncMessages(AsyncValue<List<ChatMessage>> asyncMessages) {
    asyncMessages.whenData((messages) {
      final converted = messages
          .map((m) => Message.text(
                id: m.id,
                authorId: m.senderId,
                createdAt: m.createdAt,
                text: m.content,
              ))
          .toList(growable: false);
      _chatController.setMessages(converted);
    });
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
        appBar: AppBar(
          title: const Text('Support chat'),
          centerTitle: true,
          forceMaterialTransparency: true,
        ),
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
                  subtitle: Text(conversation.lastMessage.content,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Text('${conversation.messageCount} msgs'),
                  onTap: () =>
                      context.push('/chat?userId=${conversation.userId}'),
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
        body:
            const Center(child: Text('Unable to determine chat conversation.')),
      );
    }

    final messages = ref.watch(_messagesProvider(targetUserId));
    ref.listen(_messagesProvider(targetUserId), (_, next) {
      _syncMessages(next);
    });
    _syncMessages(messages);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          spacing: 16.0,
          children: [
            CircleAvatar(
              child: Icon(Icons.support_agent_outlined),
            ),
            Text("Support")
          ],
        ),
      ),
      body: Chat(
        chatController: _chatController,
        currentUserId: currentUserId,
        theme: ChatTheme.fromThemeData(AppTheme.darkTheme),
        onMessageSend: (text) async {
          final msg = Message.text(
            id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
            authorId: currentUserId,
            createdAt: DateTime.now().toUtc(),
            text: text,
            status: MessageStatus.sending,
          );
          await _chatController.insertMessage(msg);
          try {
            await ref
                .read(chatApiProvider)
                .send(content: text, userId: targetUserId);
            _chatController.updateMessage(
              msg,
              msg.copyWith(
                status: MessageStatus.sent,
                sentAt: DateTime.now().toUtc(),
              ),
            );
            ref.invalidate(_messagesProvider(targetUserId));
          } catch (e) {
            _chatController.updateMessage(
              msg,
              msg.copyWith(
                status: MessageStatus.error,
                failedAt: DateTime.now().toUtc(),
              ),
            );
          }
        },
        resolveUser: (id) async {
          final name =
              id == currentUserId ? (auth?.fullName ?? 'You') : 'Support';
          return User(id: id, name: name);
        },
      ),
    );
  }
}
