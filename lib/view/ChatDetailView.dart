import 'package:flutter/material.dart';

import '../model/AppUserModel.dart';
import '../model/ChatChannelModel.dart';
import '../model/ChatMessageModel.dart';
import '../viewModel/AppServicesViewModel.dart';
import 'shared/AppColorsView.dart';
import 'shared/AppRoutesView.dart';
import 'shared/AsyncStateView.dart';

class ChatDetailView extends StatefulWidget {
  const ChatDetailView({super.key, required this.chatId});

  final String chatId;

  @override
  State<ChatDetailView> createState() => _ChatDetailViewState();
}

class _ChatDetailViewState extends State<ChatDetailView> {
  final _chatRepository = AppServicesViewModel.instance.chatRepository;
  final _userRepository = AppServicesViewModel.instance.userRepository;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late Future<List<Object>> _chatFuture;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _chatFuture = _loadChat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object>>(
      future: _chatFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AsyncStateView(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: () => setState(() => _chatFuture = _loadChat()),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final currentUser = snapshot.data![0] as AppUserModel;
        final chat = snapshot.data![1] as ChatChannelModel;
        final messages = _normalizedMessages(chat.messages);
        _scheduleScrollToBottom();

        final otherUserId = chat.participantIds.firstWhere(
          (id) => id != currentUser.id,
          orElse: () => currentUser.id,
        );
        final otherUserName = chat.participantNames[otherUserId] ?? 'Usuario';

        return Scaffold(
          backgroundColor: const Color(0xFFF5F8F8),
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    Container(
                      color: Colors.white.withOpacity(0.85),
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Text(otherUserName.substring(0, 1)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  otherUserName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF004E5E),
                                  ),
                                ),
                                const Text(
                                  'Activo ahora',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColorsView.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No hay acciones adicionales en este chat.'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.more_vert_rounded),
                          ),
                        ],
                      ),
                    ),
                    if (chat.relatedProductId != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFDCC4B8), Color(0xFFF6EDE3)],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    chat.relatedProductName ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColorsView.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${(chat.relatedProductPrice ?? 0).toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pushNamed(
                                AppRoutesView.productDetail,
                                arguments: chat.relatedProductId!,
                              ),
                              child: const Text('Ver detalle'),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isCurrentUser = message.senderId == currentUser.id;
                          return Align(
                            alignment: isCurrentUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: isCurrentUser
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    constraints: const BoxConstraints(maxWidth: 280),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCurrentUser
                                          ? AppColorsView.primary
                                          : Colors.white.withOpacity(0.7),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: Radius.circular(
                                          isCurrentUser ? 16 : 4,
                                        ),
                                        bottomRight: Radius.circular(
                                          isCurrentUser ? 4 : 16,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      message.text,
                                      style: TextStyle(
                                        color: isCurrentUser
                                            ? Colors.white
                                            : AppColorsView.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _timeString(message.timestamp),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColorsView.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Adjuntar archivos aun no esta disponible.'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_rounded),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Escribe un mensaje...',
                              border: InputBorder.none,
                              filled: false,
                            ),
                          ),
                        ),
                        CircleAvatar(
                          backgroundColor: AppColorsView.primary,
                          child: IconButton(
                            onPressed: _controller.text.trim().isEmpty || _isSending
                                ? null
                                : _sendMessage,
                            icon: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<Object>> _loadChat() {
    return Future.wait<Object>([
      _userRepository.getCurrentUser(),
      _chatRepository.getChatById(widget.chatId),
    ]);
  }

  List<ChatMessageModel> _normalizedMessages(List<ChatMessageModel> original) {
    final unique = <String, ChatMessageModel>{};
    for (final message in original) {
      final key =
          '${message.id}_${message.senderId}_${message.timestamp.toIso8601String()}_${message.text}';
      unique[key] = message;
    }
    final messages = unique.values.toList();
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await _chatRepository.sendMessage(widget.chatId, text);
      if (!mounted) return;
      _controller.clear();
      setState(() => _chatFuture = _loadChat());
      await _chatFuture;
      if (!mounted) return;
      _scheduleScrollToBottom();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _timeString(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}
