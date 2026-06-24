import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
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
import 'dart:ui' as ui;

// Cache for image validity checks
final Map<String, bool> _imageValidityCache = {};

// Optimized image validity check with caching
Future<bool> _checkImageValidity(String imageUrl) async {
  if (imageUrl.isEmpty) return false;
  if (_imageValidityCache.containsKey(imageUrl)) {
    return _imageValidityCache[imageUrl]!;
  }

  try {
    bool isValid;
    if (ImageUtils.isNetworkImage(imageUrl)) {
      final response = await http.head(Uri.parse(imageUrl));
      isValid = response.statusCode == 200;
    } else if (ImageUtils.isBase64Image(imageUrl)) {
      final bytes = ImageUtils.decodeBase64Image(imageUrl);
      isValid = bytes != null && bytes.isNotEmpty;
    } else {
      isValid = false;
    }
    _imageValidityCache[imageUrl] = isValid;
    return isValid;
  } catch (e) {
    _imageValidityCache[imageUrl] = false;
    return false;
  }
}

// Beautiful avatar builder
Widget buildAvatar(String imageUrl, String name, {bool isSearch = false, double size = 60, VoidCallback? onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isSearch
            ? LinearGradient(
                colors: [Colors.white, Colors.grey.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
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
      child: isSearch
          ? Center(
              child: Icon(
                CupertinoIcons.search,
                color: Colors.blue.shade700,
                size: 24,
              ),
            )
          : _buildAvatarImage(imageUrl, name, size),
    ),
  );
}

Widget _buildAvatarImage(String imageUrl, String name, double size) {
  if (imageUrl.isEmpty) return _buildAvatarPlaceholder(name, size * 0.5);
  
  if (imageUrl.startsWith('http')) {
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => Center(child: SizedBox(width: size*0.3, height: size*0.3, child: CircularProgressIndicator(strokeWidth: 2))),
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
      VoidCallback? onAvatarTap,
      VoidCallback? onLongPress,
    }) {
  final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
  final bool isUnread = unreadCount > 0;
  final bool isOnline = chat.providerId.hashCode % 3 == 0;
  final String lastMessageText = chat.lastMessage.isEmpty
      ? languageProvider.tr('start_discussion', category: 'chat')
      : chat.lastMessage;
  final String formattedTime = _formatTimestamp(chat.lastMessageTime.toDate(), languageProvider);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2A4A).withOpacity(0.5) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isUnread 
                  ? Colors.blue.withOpacity(0.3) 
                  : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05)),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onAvatarTap,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isDark 
                              ? [const Color(0xFF4A6FDC), const Color(0xFF764BA2)]
                              : [Colors.blue.shade100, Colors.purple.shade50],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: _buildAvatarImage(profileImageUrl ?? '', contactName, 58),
                    ),
                    if (isOnline)
                      PositionedDirectional(
                        end: 2,
                        bottom: 2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D261),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E2A4A) : Colors.white,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            contactName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF2D3142),
                              fontFamily: 'Exo2',
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white54 : Colors.grey.shade500,
                            fontFamily: 'Exo2',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessageText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                              color: isUnread 
                                  ? (isDark ? Colors.white : const Color(0xFF4A6FDC))
                                  : (isDark ? Colors.white60 : Colors.grey.shade600),
                              fontFamily: 'Exo2',
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUnread)
                          Container(
                            margin: const EdgeInsetsDirectional.only(start: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4A6FDC), Color(0xFF667EEA)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4A6FDC).withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              unreadCount > 99 ? "99+" : "$unreadCount",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Exo2',
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

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  late ChatViewModel _chatViewModel;
  final Map<String, String> _profileImages = {};
  final Map<String, String> _contactNames = {};
  StreamSubscription<List<ChatModel>>? _chatSubscription;
  final RefreshController _refreshController = RefreshController();
  Timer? _refreshTimer;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  void _initialize() {
    _chatViewModel = Provider.of<ChatViewModel>(context, listen: false);
    _setupChatStream();
    _startAutoRefresh();
  }

  void _setupChatStream() {
    _chatSubscription?.cancel();
    _chatSubscription = _chatViewModel.userChatsStream.listen(
      _handleChatsUpdate,
      onError: (error) {
        debugPrint('❌ Chat stream error: $error');
        if (mounted) {
          final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
          setState(() {
            _errorMessage = languageProvider.tr('chat_stream_error', category: 'chat');
            _isLoading = false;
          });
        }
      },
    );
  }

  void _handleChatsUpdate(List<ChatModel> chats) async {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isRefreshing = false;
    });
    _preloadProfileImages(chats);
  }

  Future<void> _preloadProfileImages(List<ChatModel> chats) async {
    for (final chat in chats) {
      try {
        final otherUserId = chat.getOtherParticipantId(widget.userId);
        if (!_contactNames.containsKey(otherUserId)) {
          _contactNames[otherUserId] = chat.getOtherParticipantName(widget.userId);
        }
        if (!_profileImages.containsKey(otherUserId)) {
          final imageUrl = await _chatViewModel.getUserProfileImageUrl(otherUserId);
          if (imageUrl != null && imageUrl.isNotEmpty && mounted) {
            setState(() {
              _profileImages[otherUserId] = imageUrl;
            });
          }
        }
      } catch (e) {
        // Silent fail
      }
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && !_isRefreshing) {
        _silentRefresh();
      }
    });
  }

  Future<void> _silentRefresh() async {
    if (_isRefreshing) return;
    try {
      _chatViewModel.updateUser(widget.userId);
    } catch (e) {}
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      _imageValidityCache.clear();
      _setupChatStream();
      _chatViewModel.updateUser(widget.userId);
    } catch (e) {
      debugPrint('❌ Refresh error: $e');
      if (mounted) {
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        AppSnackBar.showError(context, languageProvider.tr('refresh_error', category: 'chat'));
      }
    } finally {
      if (mounted) {
        _refreshController.refreshCompleted();
      }
    }
  }

  void _onRefresh() async {
    await _refreshData();
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
              try {
                await _chatViewModel.deleteChat(chatId);
                if (mounted) {
                  AppSnackBar.showSuccess(context, lang.tr('chat_deleted', category: 'chat'));
                }
              } catch (e) {
                if (mounted) {
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

  void _navigateToUserProfile(String userId) async {
    try {
      final userData = await _chatViewModel.getUserData(userId);
      if (userData != null && mounted) {
        final user = UserModel.fromMap(userData, userId);
        if (user.isProvider) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProviderProfileScreen(
                provider: ProviderModel.fromUser(user),
                serviceCategory: user.profession ?? 'Service Provider',
              ),
            ),
          );
        } else {
          AppSnackBar.showInfo(context, "Public profile not available for this user");
        }
      }
    } catch (e) {
      debugPrint('Error navigating to profile: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _silentRefresh();
    }
  }

  void _createNewChatWithProvider(BuildContext context, String providerId, String providerName, String? photoUrl) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    
    if (widget.userId == providerId) {
      _showErrorDialog(
        languageProvider.tr('action_not_allowed', category: 'chat'),
        languageProvider.tr('cannot_chat_self', category: 'chat'),
      );
      return;
    }

    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final chatId = await _chatViewModel.createChat(clientId: widget.userId, providerId: providerId);
      
      if (mounted) {
        navigator.pop(); // Remove loading
        if (chatId != null) {
          navigator.pop(); // Close search modal
          navigator.push(
            MaterialPageRoute(
              builder: (context) => DiscussionPage(
                contactName: providerName,
                isOnline: true,
                chatId: chatId,
                currentUserId: widget.userId,
                chatViewModel: _chatViewModel,
                profileImageUrl: photoUrl,
                contactUserId: providerId,
              ),
            ),
          );
        } else {
          AppSnackBar.showError(context, languageProvider.tr('chat_creation_error', category: 'chat'));
        }
      }
    } catch (error) {
      if (mounted) {
        navigator.pop(); // Remove loading
        AppSnackBar.showError(context, languageProvider.trParams('error_prefix', category: 'chat', params: {'error': error.toString()}));
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: languageProvider.isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600, fontFamily: 'Exo2')),
          content: Text(message, style: TextStyle(fontFamily: 'Exo2', color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(languageProvider.tr('ok', category: 'chat'), style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600, fontFamily: 'Exo2')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoriesSection(List<ChatModel> chats) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayContacts = chats.where((chat) => chat.getOtherParticipantId(widget.userId).isNotEmpty).take(10).toList();

    return Container(
      height: 155,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              languageProvider.tr('recent_contacts', category: 'chat'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF2D3142),
                fontFamily: 'Exo2',
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: displayContacts.length + 1,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                if (index == 0) return _buildSearchCircle(isDark, languageProvider);

                final chat = displayContacts[index - 1];
                final otherUserId = chat.getOtherParticipantId(widget.userId);
                final contactName = _contactNames[otherUserId] ?? languageProvider.tr('contact', category: 'chat');
                final imageUrl = _profileImages[otherUserId] ?? '';

                return Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: GestureDetector(
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
                          ),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        buildAvatar(
                          imageUrl,
                          contactName,
                          size: 62,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 65,
                          child: Text(
                            contactName,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF4F5E7B),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Exo2',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
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
    );
  }

  Widget _buildSearchCircle(bool isDark, LanguageProvider languageProvider) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: GestureDetector(
        onTap: () => _showSearchModal(context),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200, width: 2),
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              ),
              child: const Center(
                child: Icon(CupertinoIcons.search, color: Color(0xFF4A6FDC), size: 26),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              languageProvider.tr('search', category: 'chat'),
              style: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF4F5E7B),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'Exo2',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChatState() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(CupertinoIcons.chat_bubble_2, size: 80, color: theme.primaryColor.withOpacity(0.2)),
            ),
            const SizedBox(height: 32),
            Text(
              languageProvider.tr('no_chats', category: 'chat'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF2D3142),
                fontFamily: 'Exo2',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              languageProvider.tr('start_new_conversation', category: 'chat'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                fontFamily: 'Exo2',
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => _showSearchModal(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: theme.primaryColor.withOpacity(0.4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.plus_bubble_fill, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    languageProvider.tr('search_discussion', category: 'chat'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Exo2'),
                  ),
                ],
              ),
            ),
          ],
        ),
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
          onAvatarTap: _navigateToUserProfile,
          onChatSelected: (chatId, contactName, profileImageUrl) async {
            if (!mounted) return;
            final navigator = Navigator.of(context);
            navigator.pop();
            
            final chat = await _chatViewModel.getChatById(chatId);
            final otherUserId = chat?.getOtherParticipantId(widget.userId);
            
            if (mounted) {
              navigator.push(
                MaterialPageRoute(
                  builder: (context) => DiscussionPage(
                    contactName: contactName,
                    isOnline: true,
                    chatId: chatId,
                    currentUserId: widget.userId,
                    chatViewModel: _chatViewModel,
                    profileImageUrl: profileImageUrl,
                    contactUserId: otherUserId,
                  ),
                ),
              );
            }
          },
          onCreateNewChat: (providerId, providerName, photoUrl) {
            _createNewChatWithProvider(context, providerId, providerName, photoUrl);
          },
        );
      },
      useRootNavigator: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return ChangeNotifierProvider.value(
      value: _chatViewModel,
      child: Consumer<ChatViewModel>(
        builder: (context, chatViewModel, child) {
          return Directionality(
            textDirection: languageProvider.isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            child: Scaffold(
              body: SafeArea(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: Theme.of(context).brightness == Brightness.dark
                          ? [const Color(0xFF16213E), const Color(0xFF1A1A2E)]
                          : [const Color(0xFF4A6FDC), const Color(0xFF667EEA)],
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(25, 20, 25, 25),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  languageProvider.tr('discussions', category: 'chat'),
                                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, fontFamily: 'Exo2', letterSpacing: -1),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF00D261), shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Text(
                                      languageProvider.tr('recent_messages', category: 'chat'),
                                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Exo2'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: _refreshData,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: const Icon(CupertinoIcons.refresh, color: Colors.white, size: 22),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
                          ),
                          child: SmartRefresher(
                            controller: _refreshController,
                            onRefresh: _onRefresh,
                            enablePullDown: true,
                            header: ClassicHeader(
                              height: 60,
                              completeIcon: const Icon(Icons.check, color: Colors.green),
                              failedIcon: const Icon(Icons.error, color: Colors.red),
                              textStyle: const TextStyle(color: Colors.grey, fontFamily: 'Exo2'),
                              refreshingText: languageProvider.tr('refreshing', category: 'chat'),
                              completeText: languageProvider.tr('refreshed', category: 'chat'),
                              failedText: languageProvider.tr('failed', category: 'chat'),
                              idleText: languageProvider.tr('pull_to_refresh', category: 'chat'),
                              releaseText: languageProvider.tr('release_to_refresh', category: 'chat'),
                            ),
                            child: StreamBuilder<List<ChatModel>>(
                              stream: chatViewModel.userChatsStream,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) return _buildShimmerLoading();
                                if (snapshot.hasError) return ErrorStateWidget(onRetry: _refreshData);
                                final chats = snapshot.data ?? [];
                                if (chats.isEmpty) return _buildEmptyChatState();

                                return CustomScrollView(
                                  slivers: [
                                    SliverToBoxAdapter(child: _buildStoriesSection(chats)),
                                    SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Divider(color: Colors.grey.shade200, thickness: 1))),
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                        child: Row(
                                          children: [
                                            Text(
                                              languageProvider.tr('all_discussions', category: 'chat'),
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.grey.shade700, fontFamily: 'Exo2'),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                                              child: Text('${chats.length}', style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Exo2')),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                            (context, index) {
                                          final chat = chats[index];
                                          final otherUserId = chat.getOtherParticipantId(widget.userId);
                                          final contactName = _contactNames[otherUserId] ?? languageProvider.tr('contact', category: 'chat');
                                          final profileImageUrl = _profileImages[otherUserId] ?? '';

                                          return StreamBuilder<int>(
                                            stream: chatViewModel.getUnreadCount(chat.chatId),
                                            builder: (context, unreadSnapshot) {
                                              final unreadCount = unreadSnapshot.data ?? 0;
                                              return buildChatTile(
                                                context,
                                                chat,
                                                widget.userId,
                                                unreadCount: unreadCount,
                                                contactName: contactName,
                                                profileImageUrl: profileImageUrl,
                                                onLongPress: () => _confirmDeleteChat(chat.chatId, contactName),
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => DiscussionPage(
                                                            contactName: contactName,
                                                            isOnline: true,
                                                            chatId: chat.chatId,
                                                            currentUserId: widget.userId,
                                                            chatViewModel: chatViewModel,
                                                            profileImageUrl: profileImageUrl,
                                                            contactUserId: otherUserId,
                                                          ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          );
                                        },
                                        childCount: chats.length,
                                      ),
                                    ),
                                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _chatSubscription?.cancel();
    _refreshController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class _SearchModal extends StatefulWidget {
  final ChatViewModel chatViewModel;
  final String userId;
  final Function(String chatId, String contactName, String? profileImageUrl) onChatSelected;
  final Function(String providerId, String providerName, String? photoUrl) onCreateNewChat;
  final Function(String userId)? onAvatarTap;

  const _SearchModal({
    required this.chatViewModel,
    required this.userId,
    required this.onChatSelected,
    required this.onCreateNewChat,
    this.onAvatarTap,
  });

  @override
  State<_SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends State<_SearchModal> {
  final TextEditingController _searchController = TextEditingController();
  List<ChatModel> _allChats = [];
  List<ChatModel> _filteredChats = [];
  final List<Map<String, dynamic>> _allProviders = [];
  List<Map<String, dynamic>> _filteredProviders = [];
  bool _isLoading = true;
  String _searchQuery = '';
  StreamSubscription<List<ChatModel>>? _chatSubscription;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadData();
  }

  void _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    _chatSubscription = widget.chatViewModel.userChatsStream.listen(
      (chats) {
        if (mounted) {
          setState(() {
            _allChats = chats;
            _filterLists();
          });
        }
      },
    );

    try {
      final providers = await widget.chatViewModel.getAvailableProviders();
      if (mounted) {
        setState(() {
          _allProviders.clear();
          _allProviders.addAll(providers);
          _filterLists();
        });
      }
    } catch (e) {
      debugPrint('Error loading providers for search: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
      _filterLists();
    });
  }

  void _filterLists() {
    if (_searchQuery.isEmpty) {
      _filteredChats = _allChats;
      _filteredProviders = _allProviders;
    } else {
      _filteredChats = _allChats.where((chat) {
        final contactName = chat.getOtherParticipantName(widget.userId);
        return contactName.toLowerCase().contains(_searchQuery);
      }).toList();
      _filteredProviders = _allProviders.where((provider) {
        final name = (provider['name'] ?? '').toString().toLowerCase();
        final email = (provider['email'] ?? '').toString().toLowerCase();
        final profession = (provider['profession'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) || email.contains(_searchQuery) || profession.contains(_searchQuery);
      }).toList();
    }
  }

  Widget _buildChatItem(ChatModel chat) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final otherUserId = chat.getOtherParticipantId(widget.userId);
    final contactName = chat.getOtherParticipantName(widget.userId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<String?>(
      future: widget.chatViewModel.getUserProfileImageUrl(otherUserId),
      builder: (context, snapshot) {
        final profileImageUrl = snapshot.data;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: buildAvatar(
              profileImageUrl ?? '',
              contactName,
              size: 52,
            ),
            title: Text(
              contactName, 
              style: TextStyle(
                fontWeight: FontWeight.w800, 
                fontSize: 16, 
                color: isDark ? Colors.white : const Color(0xFF2D3142), 
                fontFamily: 'Exo2'
              )
            ),
            subtitle: Text(
              chat.lastMessage.isEmpty ? languageProvider.tr('start_discussion', category: 'chat') : chat.lastMessage, 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis, 
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey.shade600, 
                fontSize: 13, 
                fontFamily: 'Exo2'
              )
            ),
            onTap: () => widget.onChatSelected(chat.chatId, contactName, profileImageUrl),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      },
    );
  }

  Widget _buildProviderItem(Map<String, dynamic> provider) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final String? photoUrl = provider['photoUrl'];
    final String name = provider['name'] ?? languageProvider.tr('provider', category: 'chat');
    final String? providerId = provider['id'];
    final String? profession = provider['profession'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: buildAvatar(
          photoUrl ?? '',
          name,
          size: 52,
        ),
        title: Text(
          name, 
          style: TextStyle(
            fontWeight: FontWeight.w800, 
            fontSize: 16, 
            color: isDark ? Colors.white : const Color(0xFF2D3142), 
            fontFamily: 'Exo2'
          )
        ),
        subtitle: profession != null && profession.isNotEmpty 
          ? Text(
              profession, 
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey.shade600, 
                fontSize: 13, 
                fontFamily: 'Exo2'
              )
            )
          : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF4A6FDC), Color(0xFF667EEA)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            languageProvider.tr('new', category: 'chat').toUpperCase(), 
            style: const TextStyle(
              color: Colors.white, 
              fontSize: 10, 
              fontWeight: FontWeight.w900, 
              fontFamily: 'Exo2'
            )
          ),
        ),
        onTap: () => widget.onCreateNewChat(provider['id']!, name, photoUrl),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: languageProvider.isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16213E) : const Color(0xFFF8FAFF),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        ),
        child: Column(
          children: [
            // Handle & Title
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          languageProvider.tr('search_discussion', category: 'chat'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF2D3142),
                            fontFamily: 'Exo2',
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                  ],
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: languageProvider.tr('search_hint', category: 'chat'),
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                      fontSize: 15,
                      fontFamily: 'Exo2',
                    ),
                    prefixIcon: Icon(CupertinoIcons.search, color: isDark ? Colors.white38 : Colors.grey.shade400, size: 22),
                    suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: Icon(CupertinoIcons.xmark_circle_fill, color: isDark ? Colors.white38 : Colors.grey.shade400, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged();
                          },
                        ) 
                      : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF2D3142),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Exo2',
                  ),
                  autofocus: true,
                ),
              ),
            ),
            
            // Results
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(strokeWidth: 3),
                          const SizedBox(height: 20),
                          Text(
                            languageProvider.tr('loading', category: 'chat'),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Exo2'),
                          ),
                        ],
                      ),
                    )
                  : (_filteredChats.isEmpty && _filteredProviders.isEmpty)
                      ? _buildNoResults(languageProvider, isDark)
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          physics: const BouncingScrollPhysics(),
                          children: [
                            if (_filteredChats.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                                child: Text(
                                  languageProvider.tr('existing_chats', category: 'chat').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                                    letterSpacing: 1.2,
                                    fontFamily: 'Exo2',
                                  ),
                                ),
                              ),
                              ..._filteredChats.map(_buildChatItem),
                              const SizedBox(height: 16),
                            ],
                            if (_filteredProviders.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                                child: Text(
                                  languageProvider.tr('new_discussion', category: 'chat').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                                    letterSpacing: 1.2,
                                    fontFamily: 'Exo2',
                                  ),
                                ),
                              ),
                              ..._filteredProviders.map(_buildProviderItem),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults(LanguageProvider languageProvider, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.search_circle_fill,
            size: 80,
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
          const SizedBox(height: 20),
          Text(
            _searchQuery.isEmpty 
              ? languageProvider.tr('no_chats_or_providers', category: 'chat')
              : languageProvider.trParams('no_results_for', category: 'chat', params: {'query': _searchQuery}),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white38 : Colors.grey.shade400,
              fontFamily: 'Exo2',
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _chatSubscription?.cancel();
    super.dispose();
  }
}
