import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:service_app/utils/image_utils.dart';
import 'package:provider/provider.dart';
import 'package:service_app/ViewModel/chat_view_model.dart';
import 'package:service_app/models/ChatModel.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/models/ProviderModel.dart';
import 'package:service_app/screens/profile/provider_profile/provider_profile_page.dart';
import 'package:service_app/screens/chat/disscussion/disscussion_page.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';
import 'constants.dart';
import 'dart:ui' as ui;

// Beautiful avatar builder
Widget buildAvatar(String imageUrl, String name, {double size = 60, VoidCallback? onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.blue.shade100, Colors.purple.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _buildAvatarImage(imageUrl, name, size),
    ),
  );
}

Widget _buildAvatarImage(String imageUrl, String name, double size) {
  if (imageUrl.isEmpty) return _buildAvatarPlaceholder(name, size * 0.5);
  
  if (ImageUtils.isNetworkImage(imageUrl)) {
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => Center(child: SizedBox(width: size*0.3, height: size*0.3, child: const CircularProgressIndicator(strokeWidth: 2))),
        errorWidget: (context, url, error) => _buildAvatarPlaceholder(name, size * 0.5),
      ),
    );
  } else {
    final provider = ImageUtils.getImageProvider(imageUrl);
    if (provider != null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: provider,
        backgroundColor: Colors.transparent,
      );
    }
    return _buildAvatarPlaceholder(name, size * 0.5);
  }
}

Widget _buildAvatarPlaceholder(String name, double iconSize) {
  return Center(
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(
        color: Colors.white,
        fontSize: iconSize * 0.8,
        fontWeight: FontWeight.w800,
        fontFamily: 'Exo2',
      ),
    ),
  );
}

// Beautiful chat tile
Widget buildChatTile(
    BuildContext context,
    ChatModel chat,
    String userId, {
      required int unreadCount,
      required String contactName,
      String? profileImageUrl,
      required VoidCallback onTap,
      VoidCallback? onLongPress,
    }) {
  final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
  final bool isUnread = unreadCount > 0;
  final String lastMessageText = chat.lastMessage.isEmpty
      ? languageProvider.tr('start_discussion', category: 'chat')
      : chat.lastMessage;
  final String formattedTime = _formatTimestamp(chat.lastMessageTime.toDate(), languageProvider);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUnread 
              ? (isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFF))
              : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Hero(
                tag: 'chat_avatar_${chat.chatId}',
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isUnread ? kPrimaryBlue.withOpacity(0.3) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: _buildAvatarImage(profileImageUrl ?? '', contactName, 58),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          contactName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF1B1B1B),
                            fontFamily: 'Exo2',
                          ),
                        ),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 11,
                            color: isUnread ? kPrimaryBlue : Colors.grey.shade500,
                            fontWeight: isUnread ? FontWeight.w800 : FontWeight.w500,
                            fontFamily: 'Exo2',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessageText,
                            style: TextStyle(
                              fontSize: 14,
                              color: isUnread 
                                ? (isDark ? Colors.white : Colors.black87) 
                                : (isDark ? Colors.white60 : Colors.grey.shade600),
                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                              fontFamily: 'Exo2',
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [kPrimaryBlue, Color(0xFF073C63)]),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: kPrimaryBlue.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              unreadCount > 99 ? "99+" : "$unreadCount",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _formatTimestamp(DateTime timestamp, LanguageProvider lang) {
  final now = DateTime.now();
  final difference = now.difference(timestamp);

  if (difference.inDays == 0) {
    return DateFormat('HH:mm').format(timestamp);
  } else if (difference.inDays == 1) {
    return lang.tr('yesterday', category: 'chat');
  } else if (difference.inDays < 7) {
    return DateFormat('EEEE').format(timestamp).substring(0, 3);
  } else {
    return DateFormat('dd/MM').format(timestamp);
  }
}

class ChatPage extends StatefulWidget {
  final String userId;
  const ChatPage({super.key, required this.userId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late ChatViewModel _chatViewModel;
  final Map<String, String> _profileImages = {};
  final Map<String, String> _contactNames = {};
  final RefreshController _refreshController = RefreshController();
  final Set<String> _dismissedChatIds = {}; // Local state for optimistic dismissal
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    _chatViewModel = Provider.of<ChatViewModel>(context, listen: false);
    setState(() => _isLoading = false);
  }

  Future<void> _preloadProfileImages(List<ChatModel> chats) async {
    bool updated = false;
    for (final chat in chats) {
      final otherUserId = chat.getOtherParticipantId(widget.userId);
      if (!_contactNames.containsKey(otherUserId)) {
        _contactNames[otherUserId] = chat.getOtherParticipantName(widget.userId);
        updated = true;
      }
      if (!_profileImages.containsKey(otherUserId)) {
        final imageUrl = await _chatViewModel.getUserProfileImageUrl(otherUserId);
        if (imageUrl != null && imageUrl.isNotEmpty) {
          _profileImages[otherUserId] = imageUrl;
          updated = true;
        }
      }
    }
    if (updated && mounted) setState(() {});
  }

  void _onRefresh() async {
    _chatViewModel.updateUser(widget.userId);
    _refreshController.refreshCompleted();
  }

  Widget _buildShimmerLoading() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      itemCount: 8,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Shimmer.fromColors(
          baseColor: isDark ? Colors.white10 : Colors.grey.shade200,
          highlightColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          child: Row(
            children: [
              Container(width: 60, height: 60, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(width: double.infinity, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteChat(String chatId, String contactName) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          lang.tr('delete_chat_title', category: 'chat'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Exo2'),
        ),
        content: Text(
          lang.trParams('delete_chat_confirm', category: 'chat', params: {'name': contactName}),
          style: const TextStyle(fontFamily: 'Exo2'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.tr('cancel', category: 'common'), style: const TextStyle(color: Colors.grey, fontFamily: 'Exo2')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _dismissedChatIds.add(chatId); // Optimistic removal
              });
              try {
                await _chatViewModel.deleteChat(chatId);
                if (mounted) {
                  AppSnackBar.showSuccess(context, lang.tr('chat_deleted', category: 'chat'));
                }
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _dismissedChatIds.remove(chatId); // Revert on failure
                  });
                  AppSnackBar.showError(context, lang.tr('delete_failed', category: 'chat'));
                }
              }
            },
            child: Text(lang.tr('delete', category: 'common'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Exo2')),
          ),
        ],
      ),
    );
  }

  void _showSearchModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SearchModal(
          chatViewModel: _chatViewModel,
          userId: widget.userId,
          onChatSelected: (chatId, contactName, profileImageUrl, otherUserId) {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DiscussionPage(
                  contactName: contactName,
                  isOnline: true,
                  chatId: chatId,
                  currentUserId: widget.userId,
                  chatViewModel: _chatViewModel,
                  profileImageUrl: profileImageUrl,
                  contactUserId: otherUserId,
                  heroTag: 'chat_avatar_$chatId',
                ),
              ),
            );
          },
        );
      },
      useRootNavigator: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: languageProvider.isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFF0C5E99), 
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark 
                ? [const Color(0xFF121212), const Color(0xFF1A1A2E)]
                : [const Color(0xFF0C5E99), const Color(0xFF073C63)],
              stops: const [0.0, 0.4],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Header Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40), // Spacing
                      Text(
                        languageProvider.tr('chat', category: 'chat').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 14, 
                          fontWeight: FontWeight.w800, 
                          letterSpacing: 2,
                          fontFamily: 'Exo2'
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showSearchModal(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(CupertinoIcons.search, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Stories Section
                _buildStoriesSection(languageProvider, _chatViewModel),

                const SizedBox(height: 15),
              
                // Main Content
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
                          child: Text(
                            languageProvider.tr('discussions', category: 'chat'),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF2D3142),
                              fontFamily: 'Exo2',
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        Expanded(
                          child: StreamBuilder<List<ChatModel>>(
                            stream: _chatViewModel.userChatsStream,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting && _isLoading) return _buildShimmerLoading();
                              if (snapshot.hasError) return ErrorStateWidget(onRetry: () => setState(() {}));
                              
                              // Filter out dismissed items
                              final chats = (snapshot.data ?? [])
                                  .where((c) => !_dismissedChatIds.contains(c.chatId))
                                  .toList();

                              if (chats.isEmpty) return _buildEmptyChatState();

                              // Trigger image preloading in background
                              _preloadProfileImages(chats);

                              return SmartRefresher(
                                controller: _refreshController,
                                onRefresh: _onRefresh,
                                enablePullDown: true,
                                header: WaterDropHeader(
                                  waterDropColor: kPrimaryBlue,
                                  refresh: const CircularProgressIndicator(strokeWidth: 2, color: kPrimaryBlue),
                                  complete: const Icon(Icons.check, color: kPrimaryBlue),
                                ),
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
                                  itemCount: chats.length,
                                  physics: const BouncingScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    final chat = chats[index];
                                    final otherUserId = chat.getOtherParticipantId(widget.userId);
                                    final contactName = _contactNames[otherUserId] ?? languageProvider.tr('contact', category: 'chat');
                                    final profileImageUrl = _profileImages[otherUserId] ?? '';

                                    return Dismissible(
                                      key: Key(chat.chatId),
                                      direction: DismissDirection.endToStart,
                                      onDismissed: (direction) {
                                        setState(() {
                                          _dismissedChatIds.add(chat.chatId);
                                        });
                                        _chatViewModel.deleteChat(chat.chatId).catchError((e) {
                                          setState(() {
                                            _dismissedChatIds.remove(chat.chatId);
                                          });
                                        });
                                      },
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 32),
                                        margin: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Icon(CupertinoIcons.delete, color: Colors.red.shade700, size: 28),
                                      ),
                                      child: StreamBuilder<int>(
                                        stream: _chatViewModel.getUnreadCount(chat.chatId),
                                        builder: (context, unreadSnapshot) {
                                          return buildChatTile(
                                            context,
                                            chat,
                                            widget.userId,
                                            unreadCount: unreadSnapshot.data ?? 0,
                                            contactName: contactName,
                                            profileImageUrl: profileImageUrl,
                                            onLongPress: () => _confirmDeleteChat(chat.chatId, contactName),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                PageRouteBuilder(
                                                  pageBuilder: (context, animation, secondaryAnimation) => DiscussionPage(
                                                    contactName: contactName,
                                                    isOnline: true,
                                                    chatId: chat.chatId,
                                                    currentUserId: widget.userId,
                                                    chatViewModel: _chatViewModel,
                                                    profileImageUrl: profileImageUrl,
                                                    contactUserId: otherUserId,
                                                    heroTag: 'chat_avatar_${chat.chatId}',
                                                  ),
                                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                    return SlideTransition(
                                                      position: animation.drive(Tween(begin: const Offset(1, 0), end: Offset.zero).chain(CurveTween(curve: Curves.ease))),
                                                      child: child,
                                                    );
                                                  },
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoriesSection(LanguageProvider languageProvider, ChatViewModel chatViewModel) {
    return StreamBuilder<List<ChatModel>>(
      stream: chatViewModel.userChatsStream,
      builder: (context, snapshot) {
        final chats = (snapshot.data ?? []).where((c) => !_dismissedChatIds.contains(c.chatId)).toList();
        final displayContacts = chats.where((chat) => chat.getOtherParticipantId(widget.userId).isNotEmpty).take(10).toList();
        
        if (displayContacts.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: displayContacts.length,
            itemBuilder: (context, index) {
              final chat = displayContacts[index];
              final otherUserId = chat.getOtherParticipantId(widget.userId);
              final contactName = _contactNames[otherUserId] ?? "User";
              final imageUrl = _profileImages[otherUserId] ?? '';
              
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DiscussionPage(
                        contactName: contactName,
                        isOnline: true,
                        chatId: chat.chatId,
                        currentUserId: widget.userId,
                        chatViewModel: _chatViewModel,
                        profileImageUrl: imageUrl,
                        contactUserId: otherUserId,
                        heroTag: 'story_avatar_${chat.chatId}',
                      ),
                    ),
                  );
                },
                child: _buildStoryItem(imageUrl, contactName, chatId: chat.chatId),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStoryItem(String? imageUrl, String name, {String? chatId}) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.5), Colors.white.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.transparent, shape: BoxShape.circle),
              child: Hero(
                tag: chatId != null ? 'story_avatar_$chatId' : 'avatar_story_$name',
                child: CircleAvatar(
                  radius: 30,
                  backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                      ? ImageUtils.getImageProvider(imageUrl)
                      : null,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: (imageUrl == null || imageUrl.isEmpty)
                      ? const Icon(CupertinoIcons.person_fill, color: Colors.white, size: 28)
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 70,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 12, 
                fontWeight: FontWeight.w600, 
                fontFamily: 'Exo2'
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatState() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.chat_bubble_2, size: 80, color: theme.primaryColor.withOpacity(0.2)),
            const SizedBox(height: 24),
            Text(
              languageProvider.tr('no_chats', category: 'chat'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Exo2'),
            ),
            const SizedBox(height: 12),
            Text(
              languageProvider.tr('start_new_conversation', category: 'chat'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontFamily: 'Exo2'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }
}

class _SearchModal extends StatefulWidget {
  final ChatViewModel chatViewModel;
  final String userId;
  final Function(String chatId, String contactName, String? profileImageUrl, String otherUserId) onChatSelected;

  const _SearchModal({
    required this.chatViewModel,
    required this.userId,
    required this.onChatSelected,
  });

  @override
  State<_SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends State<_SearchModal> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<ChatModel>>(
      stream: widget.chatViewModel.userChatsStream,
      builder: (context, snapshot) {
        final chats = (snapshot.data ?? [])
            .where((c) => c.getOtherParticipantName(widget.userId).toLowerCase().contains(_searchQuery))
            .toList();

        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16213E) : const Color(0xFFF8FAFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2.5))),
              Padding(
                padding: const EdgeInsets.all(24),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: languageProvider.tr('search_hint', category: 'chat'),
                    prefixIcon: const Icon(CupertinoIcons.search),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: chats.isEmpty 
                    ? Center(child: Text(languageProvider.tr('no_results', category: 'chat')))
                    : ListView.builder(
                        itemCount: chats.length,
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          final otherId = chat.getOtherParticipantId(widget.userId);
                          final name = chat.getOtherParticipantName(widget.userId);
                          
                          return ListTile(
                            leading: buildAvatar('', name, size: 50),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Exo2')),
                            subtitle: Text(chat.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () async {
                              final img = await widget.chatViewModel.getUserProfileImageUrl(otherId);
                              widget.onChatSelected(chat.chatId, name, img, otherId);
                            },
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
