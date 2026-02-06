import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' hide Widget;
import 'package:http/http.dart' as http;
import 'package:service_app/utils/image_utils.dart';
import 'package:provider/provider.dart';
import 'package:service_app/ViewModel/chat_view_model.dart';
import 'package:service_app/models/ChatModel.dart';
import 'package:service_app/screens/chat/constants.dart';
import 'package:service_app/screens/chat/disscussion/disscussion_page.dart'
    hide Widget;
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

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
  final bool isUnread = unreadCount > 0;
  final bool isOnline = chat.providerId.hashCode % 3 == 0;
  final String lastMessageText =
      chat.lastMessage.isEmpty ? "Démarrer la discussion..." : chat.lastMessage;
  final String formattedTime = _formatTimestamp(chat.lastMessageTime.toDate());

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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isUnread ? Colors.blue.shade100 : Colors.transparent,
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
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green.shade400,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
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
                                  color: Colors.grey.shade800,
                                  fontFamily: 'Exo2',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                lastMessageText,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
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

String _formatTimestamp(DateTime timestamp) {
  final now = DateTime.now();
  final difference = now.difference(timestamp);

  if (difference.inDays == 0) {
    return DateFormat('HH:mm').format(timestamp);
  } else if (difference.inDays == 1) {
    return "Hier";
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
          setState(() {
            _errorMessage = 'Erreur du flux de discussion';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur d\'actualisation'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
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
    if (widget.userId == providerId) {
      _showErrorDialog('Action non autorisée',
          'Vous ne pouvez pas créer une discussion avec vous-même.');
      return;
    }

    _chatViewModel
        .createChat(
      clientId: widget.userId,
      providerId: providerId,
    )
        .then((chatId) {
      if (chatId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Discussion créée avec $providerName!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la création de la discussion'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.red.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoriesSection(List<ChatModel> chats) {
    final displayContacts = chats
        .where((chat) => chat.getOtherParticipantId(widget.userId).isNotEmpty)
        .take(6)
        .toList();

    return Container(
      height: 130, // Increased height to prevent overflow
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Contacts récents',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
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
                          Container(
                            width: 70,
                            child: Text(
                              "Rechercher",
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
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
                final contactName = _contactNames[otherUserId] ?? 'Contact';
                final imageUrl = _profileImages[otherUserId] ?? '';

                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      buildAvatar(imageUrl, size: 60),
                      const SizedBox(height: 6),
                      Container(
                        width: 70,
                        child: Text(
                          contactName,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.purple.shade400],
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Chargement des discussions...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.shade50,
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red.shade400,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Erreur de chargement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ?? 'Une erreur est survenue',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _refreshData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChatState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
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
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.white,
                size: 50,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucune discussion',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Commencez une nouvelle conversation',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _showProviderSelection(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade400,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                shadowColor: Colors.blue.withOpacity(0.3),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 20),
                  SizedBox(width: 8),
                  Text('Nouvelle discussion'),
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
          onChatSelected: (chatId, contactName, profileImageUrl) {
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
                ),
              ),
            );
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
    return ChangeNotifierProvider(
      create: (context) => _chatViewModel,
      child: Consumer<ChatViewModel>(
        builder: (context, chatViewModel, child) {
          return Scaffold(
            body: SafeArea(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.fromARGB(255, 12, 94, 153),
                      Color(0xFF4A6FDC),
                      Color(0xFF667EEA),
                      Color(0xFF764BA2),
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
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Discussions",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Exo2',
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Messages récents",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
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
                                  icon: Icon(
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
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
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
                            textStyle: const TextStyle(color: Colors.grey),
                            refreshingText: 'Actualisation...',
                            completeText: 'Actualisé',
                            failedText: 'Échec',
                            idleText: 'Tirer pour actualiser',
                            releaseText: 'Relâcher pour actualiser',
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
                                  // Stories section (now includes search functionality)
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
                                            'Toutes les discussions',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
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
                                                'Contact';
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
                                              profileImageUrl: profileImageUrl,
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        DiscussionPage(
                                                      contactName: contactName,
                                                      isOnline: true,
                                                      chatId: chat.chatId,
                                                      currentUserId:
                                                          widget.userId,
                                                      chatViewModel:
                                                          _chatViewModel,
                                                      profileImageUrl:
                                                          profileImageUrl,
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
            // Removed the floating action button
          );
        },
      ),
    );
  }

  void _showProviderSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ProviderSelectionModal(
          chatViewModel: _chatViewModel,
          onCreateChat: (providerId, providerName) {
            _createNewChatWithProvider(context, providerId, providerName);
          },
        );
      },
      useRootNavigator: true,
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

class _ProviderSelectionModal extends StatefulWidget {
  final ChatViewModel chatViewModel;
  final Function(String providerId, String providerName) onCreateChat;

  const _ProviderSelectionModal({
    required this.chatViewModel,
    required this.onCreateChat,
  });

  @override
  State<_ProviderSelectionModal> createState() =>
      _ProviderSelectionModalState();
}

class _ProviderSelectionModalState extends State<_ProviderSelectionModal> {
  List<Map<String, dynamic>> _providers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  Widget _buildProviderCard(Map<String, dynamic> provider, String? photoUrl,
      String? name, String? profession) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildProviderAvatar(photoUrl, name),
        title: Text(
          name ?? 'Unknown',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
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
                  fontSize: 12,
                ),
              ),
            Text(
              provider['email'] ?? '',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.purple.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Discuter',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        onTap: () {
          widget.onCreateChat(provider['id']!, name ?? 'Prestataire');
        },
      ),
    );
  }

  Widget _buildProviderAvatar(String? photoUrl, String? name) {
    if (photoUrl == null || photoUrl.isEmpty) {
      final String displayInitial =
          name != null && name.isNotEmpty ? name[0].toUpperCase() : '?';
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.purple.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            displayInitial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      );
    }

    final imageProvider = ImageUtils.getImageProvider(photoUrl);
    final String displayInitial =
        name != null && name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.blue.shade100, Colors.purple.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: imageProvider == null
          ? Center(
              child: Text(
                displayInitial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            )
          : FutureBuilder<bool>(
              future: _checkImageValidity(photoUrl),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  );
                }

                if (snapshot.hasError || !(snapshot.data ?? false)) {
                  return Center(
                    child: Text(
                      displayInitial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  );
                }

                return CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.transparent,
                  backgroundImage: imageProvider,
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Choisir un prestataire',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryBlue,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Chargement des prestataires...'),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 50),
                            const SizedBox(height: 16),
                            const Text(
                              'Erreur de chargement',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      )
                    : _providers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.people_outline,
                                    size: 60, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text(
                                  'Aucun prestataire disponible',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Aucun prestataire n\'est inscrit sur la plateforme pour le moment.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _providers.length,
                            itemBuilder: (context, index) {
                              final provider = _providers[index];
                              final String? photoUrl = provider['photoUrl'];
                              final String? name = provider['name'];
                              final String? profession = provider['profession'];

                              return _buildProviderCard(
                                  provider, photoUrl, name, profession);
                            },
                          ),
          ),
        ],
      ),
    );
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
  List<Map<String, dynamic>> _allProviders = [];
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

        // Filter providers
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
    final otherUserId = chat.getOtherParticipantId(widget.userId);
    final contactName = chat.getOtherParticipantName(widget.userId);

    return FutureBuilder<String?>(
      future: widget.chatViewModel.getUserProfileImageUrl(otherUserId),
      builder: (context, snapshot) {
        final profileImageUrl = snapshot.data;

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
            child: profileImageUrl != null && profileImageUrl.isNotEmpty
                ? CircleAvatar(
                    backgroundImage:
                        ImageUtils.getImageProvider(profileImageUrl),
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
            contactName,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            chat.lastMessage.isEmpty
                ? "Démarrer la discussion..."
                : chat.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          trailing: Icon(
            Icons.chat_bubble_outline,
            color: Colors.blue.shade400,
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
        name ?? 'Prestataire',
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
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
              ),
            ),
          Text(
            provider['email'] ?? '',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
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
          'Nouveau',
          style: TextStyle(
            color: Colors.blue.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      onTap: () => widget.onCreateNewChat(
        provider['id']!,
        name ?? 'Prestataire',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rechercher une discussion',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryBlue,
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
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade200,
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
                        hintText: 'Rechercher par nom, email ou profession...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                      ),
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 14,
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
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Chargement...'),
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
                                  ? 'Aucune discussion ou prestataire disponible'
                                  : 'Aucun résultat pour "$_searchQuery"',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
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
                                    'Discussions existantes',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
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
                                    'Nouvelle discussion',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
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
