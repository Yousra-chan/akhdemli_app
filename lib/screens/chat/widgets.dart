import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:service_app/ViewModel/chat_view_model.dart';
import 'constants.dart';
import 'package:service_app/screens/chat/disscussion/disscussion_page.dart';
import 'package:service_app/models/chatmodel.dart';
import 'package:intl/intl.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:provider/provider.dart';

// --- Reusable Widget Builders ---

Widget buildAvatar(int index) {
  bool isSearchIcon = index == 0;
  return Container(
    width: 55,
    height: 55,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: isSearchIcon ? Colors.transparent : Colors.white54,
        width: 2.5,
      ),
      boxShadow: [
        BoxShadow(
          color: kSoftShadowColor.withOpacity(isSearchIcon ? 0.0 : 0.4),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: CircleAvatar(
      radius: 25,
      backgroundColor: isSearchIcon ? Colors.white : kLightGreyBlue,
      child: Icon(
        isSearchIcon ? CupertinoIcons.search : CupertinoIcons.person_fill,
        color: kPrimaryBlue,
        size: 26,
      ),
    ),
  );
}

Widget buildChatTile(
  BuildContext context,
  ChatModel chat,
  String currentUserId, {
  int unreadCount = 0,
}) {
  final languageProvider =
      Provider.of<LanguageProvider>(context, listen: false);
  final bool isUnread = unreadCount > 0;

  // Déterminer l'autre utilisateur
  final otherUserId =
      chat.clientId == currentUserId ? chat.providerId : chat.clientId;
  final String chatName = languageProvider.trParams(
    'contact_with_id',
    category: 'chat',
    params: {'id': otherUserId.substring(0, 5)},
  );

  // Dernier message
  final String lastMessageText = chat.lastMessage.isEmpty
      ? languageProvider.tr('start_discussion', category: 'chat')
      : chat.lastMessage;

  // Statut en ligne simulé
  final bool isOnline = otherUserId.hashCode % 2 == 0;

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: kSoftShadowColor.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: kLightGreyBlue,
            child: Icon(
              CupertinoIcons.person_fill, // Icône de personne
              color: kPrimaryBlue,
              size: 30,
            ),
          ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.greenAccent[400],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        chatName,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isUnread ? FontWeight.w900 : FontWeight.w700,
          color: kPrimaryBlue,
          fontFamily: 'Exo2',
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          lastMessageText,
          style: TextStyle(
            fontSize: 13,
            color: isUnread ? kPrimaryBlue.withOpacity(0.8) : Colors.grey[600],
            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'Exo2',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTimestamp(chat.lastMessageTime.toDate(), languageProvider),
            style: TextStyle(
              fontSize: 11,
              color: isUnread ? kPrimaryBlue : Colors.grey[500],
              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Exo2',
            ),
          ),
          const SizedBox(height: 6),
          if (isUnread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              constraints: const BoxConstraints(minWidth: 20),
              decoration: BoxDecoration(
                color: kPrimaryBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount > 99 ? "99+" : "$unreadCount",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Exo2',
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        final chatVM = Provider.of<ChatViewModel?>(context, listen: false);
        if (chatVM == null) return;
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DiscussionPage(
              contactName: chatName,
              isOnline: isOnline,
              chatId: chat.chatId,
              currentUserId: currentUserId,
              chatViewModel: chatVM,
              contactUserId: otherUserId,
            ),
          ),
        );
      },
      // Le onLongPress qui appelait les options de suppression/blocage est maintenant retiré.
    ),
  );
}

// --- Fonctions utilitaires conservées ---

String _formatTimestamp(DateTime timestamp, LanguageProvider lang) {
  final now = DateTime.now();
  final difference = now.difference(timestamp);

  if (difference.inDays == 0) {
    final hours = timestamp.hour.toString().padLeft(2, '0');
    final minutes = timestamp.minute.toString().padLeft(2, '0');
    return "$hours:$minutes";
  } else if (difference.inDays == 1) {
    return lang.tr('yesterday', category: 'chat');
  } else if (difference.inDays < 7) {
    return lang.trParams(
      'days_ago',
      category: 'chat',
      params: {'days': difference.inDays.toString()},
    );
  } else {
    return DateFormat('dd/MM/yy').format(timestamp);
  }
}

// --- Fonctions de suppression/blocage/signalement SUPPRIMÉES ---
// Les fonctions _showChatOptions et _confirmDeleteChat ont été retirées.

// --- Animation Widget (reste le même) ---
class AnimatedChatListItem extends StatefulWidget {
  final Widget child;
  final int index;

  const AnimatedChatListItem({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  State<AnimatedChatListItem> createState() => _AnimatedChatListItemState();
}

class _AnimatedChatListItemState extends State<AnimatedChatListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final delay = Duration(milliseconds: 50 * widget.index);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    Future.delayed(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(opacity: _fadeAnimation, child: widget.child),
    );
  }
}
