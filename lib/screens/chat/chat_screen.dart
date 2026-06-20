import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:service_app/utils/image_utils.dart';
import 'package:provider/provider.dart';
import 'package:service_app/ViewModel/chat_view_model.dart';
import 'package:service_app/models/ChatModel.dart';
import 'package:service_app/screens/chat/disscussion/disscussion_page.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';
import 'dart:ui' as ui;

// Cache for image validity checks
final Map<String, bool> _imageValidityCache = {};

// Optimized image validity check with caching
Future<bool> _checkImageValidity(String imageUrl) async {
  if (imageUrl.isEmpty) return false;

  // Check cache first
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
Widget buildAvatar(String imageUrl, {bool isSearch = false, double size = 60}) {
  return Container(
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
        : _buildAvatarWithImage(imageUrl, size),
  );
}

Widget _buildAvatarWithImage(String imageUrl, double size) {
  final imageProvider = ImageUtils.getImageProvider(imageUrl);

  return Stack(
    children: [
      // Background gradient
      Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade100,
              Colors.purple.shade100,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      // Image
      if (imageProvider != null)
        CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.transparent,
          backgroundImage: imageProvider,
          child: _buildImageLoadingFallback(imageUrl),
        )
      else
        Center(
          child: Icon(
            CupertinoIcons.person_fill,
            color: Colors.blue.shade700,
            size: size * 0.5,
          ),
        ),
    ],
  );
}

Widget _buildImageLoadingFallback(String imageUrl) {
  return FutureBuilder<bool>(
    future: _checkImageValidity(imageUrl),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
        );
      }

      if (snapshot.hasError || !(snapshot.data ?? false)) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade100,
                Colors.purple.shade100,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Icon(
              CupertinoIcons.person_fill,
              color: Colors.blue.shade700,
              size: 24,
            ),
          ),
        );
      }

      return Container();
    },
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
    }) {
  final languageProvider =
  Provider.of<LanguageProvider>(context, listen: false);
  final bool isUnread = unreadCount > 0;
  final bool isOnline = chat.providerId.hashCode % 3 == 0;
  final String lastMessageText = chat.lastMessage.isEmpty
      ? languageProvider.tr('start_discussion', category: 'chat')
      : chat.lastMessage;
  final String formattedTime =
  _formatTimestamp(chat.lastMessageTime.toDate(), languageProvider);

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isUnread ? Colors.blue.shade100.withOpacity(0.5) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Avatar with online indicator
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade100,
                          Colors.purple.shade100,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: profileImageUrl != null && profileImageUrl.isNotEmpty
                        ? CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.transparent,
                      backgroundImage:
                      ImageUtils.getImageProvider(profileImageUrl),
                      child: _buildImageLoadingFallback(profileImageUrl),
                    )
                        : Center(
                      child: Icon(
                        CupertinoIcons.person_fill,
                        color: Colors.blue.shade700,
                        size: 28,
                      ),
                    ),
                  ),
                  if (isOnline)
                    PositionedDirectional(
                      end: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green.shade400,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).cardColor,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 16),

              // Chat content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contactName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.white 
                                      : Colors.grey.shade800,
                                  fontFamily: 'Exo2',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                lastMessageText,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.white70 
                                      : Colors.grey.shade600,
                                  fontFamily: 'Exo2',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formattedTime,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontFamily: 'Exo2',
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (isUnread)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade400,
                                      Colors.purple.shade400,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  unreadCount > 99 ? "99+" : "$unreadCount",
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
    _chatViewModel = ChatViewModel(userId: widget.userId);
    _setupChatStream();
    _startAutoRefresh();
  }

  void _setupChatStream() {
    _chatSubscription?.cancel();
    _chatSubscription = _chatViewModel.userChatsStream.listen(
      _handleChatsUpdate,
      onError: (error) {
        print('❌ Chat stream error: $error');
        if (mounted) {
          final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);
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

    try {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });

      _preloadProfileImages(chats);
    } catch (e) {
      print('❌ Error handling chats update: $e');
    }
  }

  Future<void> _preloadProfileImages(List<ChatModel> chats) async {
    for (final chat in chats) {
      try {
        final otherUserId = chat.getOtherParticipantId(widget.userId);

        if (!_contactNames.containsKey(otherUserId)) {
          _contactNames[otherUserId] =
              chat.getOtherParticipantName(widget.userId);
        }

        if (!_profileImages.containsKey(otherUserId)) {
          final imageUrl =
          await _chatViewModel.getUserProfileImageUrl(otherUserId);
          if (imageUrl != null && imageUrl.isNotEmpty && mounted) {
            setState(() {
              _profileImages[otherUserId] = imageUrl;
            });
          }
        }
      } catch (e) {
        // Silent fail for background loading
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
    } catch (e) {
      // Silent fail for background refresh
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      _imageValidityCache.clear();
      _setupChatStream();
      _chatViewModel.updateUser(widget.userId);
    } catch (e) {
      print('❌ Refresh error: $e');
      if (mounted) {
        final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
        AppSnackBar.showError(
          context,
          languageProvider.tr('refresh_error', category: 'chat'),
        );
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _silentRefresh();
    }
  }

  void _createNewChatWithProvider(
      BuildContext context,
      String providerId,
      String providerName,
      ) {
    final languageProvider =
    Provider.of<LanguageProvider>(context, listen: false);

    if (widget.userId == providerId) {
      _showErrorDialog(
        languageProvider.tr('action_not_allowed', category: 'chat'),
        languageProvider.tr('cannot_chat_self', category: 'chat'),
      );
      return;
    }

    _chatViewModel
        .createChat(
      clientId: widget.userId,
      providerId: providerId,
    )
        .then((chatId) {
      if (chatId != null) {
        AppSnackBar.showSuccess(
          context,
          languageProvider.trParams(
            'chat_created',
            category: 'chat',
            params: {'name': providerName},
          ),
        );

        Navigator.pop(context);
      } else {
        AppSnackBar.showError(
          context,
          languageProvider.tr('chat_creation_error', category: 'chat'),
        );
      }
    }).catchError((error) {
      AppSnackBar.showError(
        context,
        languageProvider.trParams(
          'error_prefix',
          category: 'chat',
          params: {'error': error.toString()},
        ),
      );
    });
  }

  void _showErrorDialog(String title, String message) {
    final languageProvider =
    Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: languageProvider.isRtl
            ? ui.TextDirection.rtl
            : ui.TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w600,
              fontFamily: 'Exo2',
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              fontFamily: 'Exo2',
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                languageProvider.tr('ok', category: 'chat'),
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Exo2',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoriesSection(List<ChatModel> chats) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    final displayContacts = chats
        .where((chat) => chat.getOtherParticipantId(widget.userId).isNotEmpty)
        .take(6)
        .toList();

    return Container(
      height: 130,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              languageProvider.tr('recent_contacts', category: 'chat'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.grey.shade700,
                fontFamily: 'Exo2',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: displayContacts.length + 1,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return GestureDetector(
                    onTap: () => _showSearchModal(context),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          buildAvatar('', isSearch: true, size: 60),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 70,
                            child: Text(
                              languageProvider.tr('search', category: 'chat'),
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.white70 
                                    : Colors.grey.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
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
                }

                final chat = displayContacts[index - 1];
                final otherUserId = chat.getOtherParticipantId(widget.userId);
                final contactName = _contactNames[otherUserId] ??
                    languageProvider.tr('contact', category: 'chat');
                final imageUrl = _profileImages[otherUserId] ?? '';

                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      buildAvatar(imageUrl, size: 60),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 70,
                        child: Text(
                          contactName,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white70 
                                : Colors.grey.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Exo2',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(List<ChatModel> chats) {
    return ListView.builder(
      itemCount: chats.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final chat = chats[index];
        final otherUserId = chat.getOtherParticipantId(widget.userId);
        final contactName = _contactNames[otherUserId] ?? 'Contact';
        final profileImageUrl = _profileImages[otherUserId] ?? '';

        return StreamBuilder<int>(
          stream: _chatViewModel.getUnreadCount(chat.chatId),
          builder: (context, unreadSnapshot) {
            final unreadCount = unreadSnapshot.data ?? 0;

            return buildChatTile(
              context,
              chat,
              widget.userId,
              unreadCount: unreadCount,
              contactName: contactName,
              profileImageUrl: profileImageUrl,
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
    );
  }

  Widget _buildLoadingState() {
    return const LoadingWidget();
  }

  Widget _buildErrorState() {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return ErrorStateWidget(
      message: _errorMessage ?? languageProvider.tr('error_occurred', category: 'chat'),
      onRetry: _refreshData,
    );
  }

  Widget _buildEmptyChatState() {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return EmptyStateWidget(
      icon: Icons.chat_bubble_outline_rounded,
      message: languageProvider.tr('no_chats', category: 'chat'),
      subtitle: languageProvider.tr('start_new_conversation', category: 'chat'),
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
          onChatSelected: (chatId, contactName, profileImageUrl) async {
            Navigator.pop(context);
            
            // Need to get otherUserId for onChatSelected
            final chat = await _chatViewModel.getChatById(chatId);
            final otherUserId = chat?.getOtherParticipantId(widget.userId);

            if (mounted) {
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
                  ),
                ),
              );
            }
          },
          onCreateNewChat: (providerId, providerName) {
            _createNewChatWithProvider(context, providerId, providerName);
          },
        );
      },
      useRootNavigator: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return ChangeNotifierProvider(
      create: (context) => _chatViewModel,
      child: Consumer<ChatViewModel>(
        builder: (context, chatViewModel, child) {
          return Directionality(
            textDirection: languageProvider.isRtl
                ? ui.TextDirection.rtl
                : ui.TextDirection.ltr,
            child: Scaffold(
              body: SafeArea(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: Theme.of(context).brightness == Brightness.dark
                          ? [
                              const Color(0xFF16213E),
                              const Color(0xFF0F3460),
                              const Color(0xFF1A1A2E),
                              const Color(0xFF16213E),
                            ]
                          : [
                              const Color.fromARGB(255, 12, 94, 153),
                              const Color(0xFF4A6FDC),
                              const Color(0xFF667EEA),
                              const Color(0xFF764BA2),
                            ],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Beautiful header with gradient background
                      Container(
                        padding: EdgeInsets.only(
                          top: 10,
                          left: 25,
                          right: 25,
                          bottom: 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      languageProvider.tr('discussions',
                                          category: 'chat'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'Exo2',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      languageProvider.tr('recent_messages',
                                          category: 'chat'),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontFamily: 'Exo2',
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.2),
                                        Colors.white.withOpacity(0.1),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.refresh,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    onPressed: _refreshData,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),

                      // Main content
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(40),
                              topRight: Radius.circular(40),
                            ),
                          ),
                          child: SmartRefresher(
                            controller: _refreshController,
                            onRefresh: _onRefresh,
                            enablePullDown: true,
                            enablePullUp: false,
                            header: ClassicHeader(
                              height: 60,
                              refreshStyle: RefreshStyle.Follow,
                              completeIcon:
                              const Icon(Icons.check, color: Colors.green),
                              failedIcon:
                              const Icon(Icons.error, color: Colors.red),
                              textStyle: const TextStyle(
                                  color: Colors.grey, fontFamily: 'Exo2'),
                              refreshingText: languageProvider.tr('refreshing',
                                  category: 'chat'),
                              completeText: languageProvider.tr('refreshed',
                                  category: 'chat'),
                              failedText: languageProvider.tr('failed',
                                  category: 'chat'),
                              idleText: languageProvider.tr('pull_to_refresh',
                                  category: 'chat'),
                              releaseText: languageProvider
                                  .tr('release_to_refresh', category: 'chat'),
                            ),
                            child: StreamBuilder<List<ChatModel>>(
                              stream: chatViewModel.userChatsStream,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return _buildLoadingState();
                                }

                                if (snapshot.hasError) {
                                  return _buildErrorState();
                                }

                                final chats = snapshot.data ?? [];

                                if (chats.isEmpty) {
                                  return _buildEmptyChatState();
                                }

                                return CustomScrollView(
                                  slivers: [
                                    // Stories section
                                    SliverToBoxAdapter(
                                      child: _buildStoriesSection(chats),
                                    ),

                                    // Divider
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20),
                                        child: Divider(
                                          color: Colors.grey.shade200,
                                          thickness: 1,
                                        ),
                                      ),
                                    ),

                                    // Chat list title
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 10),
                                        child: Row(
                                          children: [
                                            Text(
                                              languageProvider.tr(
                                                  'all_discussions',
                                                  category: 'chat'),
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context).brightness == Brightness.dark 
                                                    ? Colors.white 
                                                    : Colors.grey.shade700,
                                                fontFamily: 'Exo2',
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius:
                                                BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '${chats.length}',
                                                style: TextStyle(
                                                  color: Colors.blue.shade700,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  fontFamily: 'Exo2',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Chat list
                                    SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                            (context, index) {
                                          final chat = chats[index];
                                          final otherUserId =
                                          chat.getOtherParticipantId(
                                              widget.userId);
                                          final contactName =
                                              _contactNames[otherUserId] ??
                                                  languageProvider.tr('contact',
                                                      category: 'chat');
                                          final profileImageUrl =
                                              _profileImages[otherUserId] ?? '';

                                          return StreamBuilder<int>(
                                            stream: _chatViewModel
                                                .getUnreadCount(chat.chatId),
                                            builder: (context, unreadSnapshot) {
                                              final unreadCount =
                                                  unreadSnapshot.data ?? 0;

                                              return buildChatTile(
                                                context,
                                                chat,
                                                widget.userId,
                                                unreadCount: unreadCount,
                                                contactName: contactName,
                                                profileImageUrl:
                                                profileImageUrl,
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          DiscussionPage(
                                                            contactName:
                                                            contactName,
                                                            isOnline: true,
                                                            chatId: chat.chatId,
                                                            currentUserId:
                                                            widget.userId,
                                                            chatViewModel:
                                                            _chatViewModel,
                                                            profileImageUrl:
                                                            profileImageUrl,
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

                                    // Add some bottom padding
                                    SliverToBoxAdapter(
                                      child: SizedBox(height: 80),
                                    ),
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
  final Function(String chatId, String contactName, String? profileImageUrl)
  onChatSelected;
  final Function(String providerId, String providerName) onCreateNewChat;

  const _SearchModal({
    required this.chatViewModel,
    required this.userId,
    required this.onChatSelected,
    required this.onCreateNewChat,
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
    setState(() => _isLoading = true);

    try {
      // Listen to chat stream to get existing chats
      _chatSubscription = widget.chatViewModel.userChatsStream.listen(
            (chats) {
          setState(() {
            _allChats = chats;
            _filteredChats = chats;
          });
        },
        onError: (error) {
          print('❌ Error loading chats: $error');
        },
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading search data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _searchQuery = query;

      if (query.isEmpty) {
        _filteredChats = _allChats;
        _filteredProviders = _allProviders;
      } else {
        // Filter existing chats
        _filteredChats = _allChats.where((chat) {
          final contactName = chat.getOtherParticipantName(widget.userId);
          return contactName.toLowerCase().contains(query);
        }).toList();

        // Filter providers - but _allProviders is always empty in original code
        _filteredProviders = _allProviders.where((provider) {
          final name = provider['name']?.toLowerCase() ?? '';
          final email = provider['email']?.toLowerCase() ?? '';
          final profession = provider['profession']?.toLowerCase() ?? '';

          return name.contains(query) ||
              email.contains(query) ||
              profession.contains(query);
        }).toList();
      }
    });
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
        final imageProvider = profileImageUrl != null && profileImageUrl.isNotEmpty
            ? ImageUtils.getImageProvider(profileImageUrl)
            : null;

        return ListTile(
          leading: Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isDark 
                    ? [const Color(0xFF1E2A4A), const Color(0xFF16213E)]
                    : [Colors.blue.shade100, Colors.purple.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: imageProvider != null
                ? CircleAvatar(
                    backgroundImage: imageProvider,
                    backgroundColor: Colors.transparent,
                  )
                : Center(
                    child: Icon(
                      CupertinoIcons.person_fill,
                      color: isDark ? const Color(0xFF8B9EFF) : Colors.blue.shade700,
                      size: 20,
                    ),
                  ),
          ),
          title: Text(
            contactName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black87,
              fontFamily: 'Exo2',
            ),
          ),
          subtitle: Text(
            chat.lastMessage.isEmpty
                ? languageProvider.tr('start_discussion', category: 'chat')
                : chat.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey.shade600,
              fontSize: 13,
              fontFamily: 'Exo2',
            ),
          ),
          trailing: Icon(
            Icons.chat_bubble_outline,
            color: isDark ? const Color(0xFF8B9EFF) : Colors.blue.shade400,
            size: 20,
          ),
          onTap: () => widget.onChatSelected(
            chat.chatId,
            contactName,
            profileImageUrl,
          ),
        );
      },
    );
  }

  Widget _buildProviderItem(Map<String, dynamic> provider) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final String? photoUrl = provider['photoUrl'];
    final String? name = provider['name'];
    final String? profession = provider['profession'];

    return ListTile(
      leading: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.purple.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: photoUrl != null && photoUrl.isNotEmpty
            ? CircleAvatar(
          backgroundImage: ImageUtils.getImageProvider(photoUrl),
          backgroundColor: Colors.transparent,
        )
            : Center(
          child: Icon(
            CupertinoIcons.person_fill,
            color: Colors.blue.shade700,
            size: 20,
          ),
        ),
      ),
      title: Text(
        name ?? languageProvider.tr('provider', category: 'chat'),
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
          fontFamily: 'Exo2',
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profession != null && profession.isNotEmpty)
            Text(
              profession,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontFamily: 'Exo2',
              ),
            ),
          Text(
            provider['email'] ?? '',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontFamily: 'Exo2',
            ),
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          languageProvider.tr('new', category: 'chat'),
          style: TextStyle(
            color: Colors.blue.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFamily: 'Exo2',
          ),
        ),
      ),
      onTap: () => widget.onCreateNewChat(
        provider['id']!,
        name ?? languageProvider.tr('provider', category: 'chat'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Directionality(
      textDirection:
      languageProvider.isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    languageProvider.tr('search_discussion', category: 'chat'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                      fontFamily: 'Exo2',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.grey.shade900 
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.white10 
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: languageProvider.tr('search_hint',
                              category: 'chat'),
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                            fontFamily: 'Exo2',
                          ),
                          border: InputBorder.none,
                        ),
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white 
                              : Colors.grey.shade800,
                          fontSize: 14,
                          fontFamily: 'Exo2',
                        ),
                        autofocus: true,
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.clear,
                            color: Colors.grey.shade500, size: 20),
                        onPressed: () {
                          _searchController.clear();
                        },
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      languageProvider.tr('loading', category: 'chat'),
                      style: const TextStyle(fontFamily: 'Exo2'),
                    ),
                  ],
                ),
              )
                  : (_filteredChats.isEmpty && _filteredProviders.isEmpty)
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isEmpty
                          ? languageProvider.tr(
                          'no_chats_or_providers',
                          category: 'chat')
                          : languageProvider.trParams(
                        'no_results_for',
                        category: 'chat',
                        params: {'query': _searchQuery},
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontFamily: 'Exo2',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_filteredChats.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            languageProvider.tr('existing_chats',
                                category: 'chat'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white 
                                  : Colors.grey.shade700,
                              fontFamily: 'Exo2',
                            ),
                          ),
                        ),
                        ..._filteredChats.map(_buildChatItem),
                        const SizedBox(height: 16),
                      ],
                    ),
                  if (_filteredProviders.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            languageProvider.tr('new_discussion',
                                category: 'chat'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white 
                                  : Colors.grey.shade700,
                              fontFamily: 'Exo2',
                            ),
                          ),
                        ),
                        ..._filteredProviders.map(_buildProviderItem),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
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