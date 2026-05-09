import 'package:flutter/material.dart';

import '../model/AppUserModel.dart';
import '../model/ChatChannelModel.dart';
import '../viewModel/AppServicesViewModel.dart';
import 'shared/AppColorsView.dart';
import 'shared/AppRoutesView.dart';
import 'shared/AsyncStateView.dart';
import 'shared/GradientScaffoldView.dart';
import 'shared/SwapioBottomNavView.dart';

class ChatListView extends StatelessWidget {
  const ChatListView({super.key});

  @override
  Widget build(BuildContext context) {
    final chatRepository = AppServicesViewModel.instance.chatRepository;
    final userRepository = AppServicesViewModel.instance.userRepository;

    return FutureBuilder<List<Object>>(
      future: Future.wait<Object>([
        userRepository.getCurrentUser(),
        chatRepository.getChatsForCurrentUser(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AsyncStateView(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final currentUser = snapshot.data![0] as AppUserModel;
        final chats = snapshot.data![1] as List<ChatChannelModel>;
        final now = DateTime.now();
        final recentChats = chats
            .where((chat) => now.difference(chat.lastMessageTimestamp).inDays < 1)
            .toList();
        final olderChats = chats
            .where((chat) => now.difference(chat.lastMessageTimestamp).inDays >= 1)
            .toList();
        final items = <_ChatListItem>[
          if (recentChats.isNotEmpty) const _ChatListItem.header('Recientes'),
          ...recentChats.map(_ChatListItem.chat),
          if (olderChats.isNotEmpty) const _ChatListItem.header('Anteriores'),
          ...olderChats.map(_ChatListItem.chat),
        ];

        return GradientScaffoldView(
          bottomNavigationBar: const SwapioBottomNavView(
            currentRoute: AppRoutesView.chatList,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const Expanded(
                          child: Text(
                            'Mensajes',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No tienes notificaciones nuevas.'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.notifications_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar conversaciones...',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: chats.isEmpty
                    ? const Center(child: Text('No tienes mensajes aun.'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          if (item.header != null) {
                            return Padding(
                              padding: EdgeInsets.only(
                                left: 8,
                                top: index == 0 ? 0 : 12,
                                bottom: 4,
                              ),
                              child: Text(
                                item.header!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColorsView.primary,
                                ),
                              ),
                            );
                          }

                          final chat = item.chat!;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ChatCard(
                              chat: chat,
                              currentUserId: currentUser.id,
                              onTap: () => Navigator.of(context).pushNamed(
                                AppRoutesView.chatDetail,
                                arguments: chat.id,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatListItem {
  const _ChatListItem.header(this.header) : chat = null;
  const _ChatListItem.chat(this.chat) : header = null;

  final String? header;
  final ChatChannelModel? chat;
}

class _ChatCard extends StatelessWidget {
  const _ChatCard({
    required this.chat,
    required this.currentUserId,
    required this.onTap,
  });

  final ChatChannelModel chat;
  final String currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final otherUserId = chat.participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => currentUserId,
    );
    final otherName = chat.participantNames[otherUserId] ?? 'Usuario';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.45)),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Text(otherName.substring(0, 1)),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: chat.unreadCount > 0
                          ? const Color(0xFF4CAF50)
                          : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        _formatTime(chat.lastMessageTimestamp),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: chat.unreadCount > 0
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: chat.unreadCount > 0
                              ? AppColorsView.primary
                              : AppColorsView.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chat.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColorsView.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(now, timestamp)) {
      return _timeString(timestamp);
    }
    if (DateUtils.isSameDay(now.subtract(const Duration(days: 1)), timestamp)) {
      return 'Ayer';
    }
    if (now.difference(timestamp).inDays < 7) {
      const weekdays = [
        'Lunes',
        'Martes',
        'Miercoles',
        'Jueves',
        'Viernes',
        'Sabado',
        'Domingo',
      ];
      return weekdays[timestamp.weekday - 1];
    }
    return '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}';
  }

  String _timeString(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}
