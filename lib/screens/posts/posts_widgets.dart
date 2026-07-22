import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:service_app/providers/language_provider.dart';
import 'posts_constants.dart';
import 'package:service_app/utils/image_utils.dart';
import 'package:service_app/utils/ui_widgets.dart';
import 'package:service_app/ViewModel/chat_view_model.dart';
import 'package:service_app/screens/chat/disscussion/disscussion_page.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:intl/intl.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/models/ProviderModel.dart';
import 'package:service_app/screens/profile/provider_profile/provider_profile_page.dart';
import 'package:service_app/screens/profile/profile_page.dart';

class PostCard extends StatefulWidget {
  final Post post;

  const PostCard({
    super.key,
    required this.post,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  String _getTimeAgo(DateTime dateTime, LanguageProvider lang) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays >= 7) {
      return DateFormat.yMMMd().format(dateTime);
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m';
    } else {
      return 'just now';
    }
  }

  void _navigateToUserProfile(BuildContext context, String userId) async {
    final chatVM = Provider.of<ChatViewModel>(context, listen: false);
    final authVM = Provider.of<AuthViewModel>(context, listen: false);

    // If it's the current user, use the local data to avoid unnecessary network calls
    if (userId == authVM.currentUser?.uid && authVM.currentUser != null) {
      final user = authVM.currentUser!;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProviderProfileScreen(
            provider: ProviderModel.fromUser(user),
            serviceCategory: user.profession ?? 'Service Provider',
          ),
        ),
      );
      return;
    }

    try {
      final userData = await chatVM.getUserData(userId);
      if (userData != null && mounted) {
        final user = UserModel.fromMap(userData, userId);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProviderProfileScreen(
              provider: ProviderModel.fromUser(user),
              serviceCategory: user.profession ?? 'Service Provider',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error navigating to profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Post Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _navigateToUserProfile(context, widget.post.userId),
                  child: _buildSmallAvatar(widget.post.userPhotoUrl),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _navigateToUserProfile(context, widget.post.userId),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.post.user,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Exo2',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "• ${_getTimeAgo(widget.post.timestamp, languageProvider)}",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : kMutedTextColor,
                                fontFamily: 'Exo2',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 12, color: kPrimaryBlue.withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Text(
                            "${languageProvider.tr(widget.post.categoryTranslationKey, category: 'posts')}",
                            style: TextStyle(
                              fontSize: 12,
                              color: kPrimaryBlue.withValues(alpha: 0.8),
                              fontFamily: 'Exo2',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Post Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (widget.post.type == PostType.seeking ? kSeekingColor : kOfferingColor).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (widget.post.type == PostType.seeking ? kSeekingColor : kOfferingColor).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    languageProvider.tr(widget.post.type.translationKey, category: 'posts').toUpperCase(),
                    style: TextStyle(
                      color: widget.post.type == PostType.seeking ? kSeekingColor : kSuccessGreen,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Exo2',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Post Title & Body
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.post.title.isNotEmpty)
                  Text(
                    widget.post.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Exo2',
                      color: kPrimaryBlue,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  widget.post.body,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    fontFamily: 'Exo2',
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Post Media
          if (widget.post.imageUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => ImageViewerDialog(imageUrls: widget.post.imageUrls),
                  );
                },
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildMainImage(widget.post.imageUrls.first),
                      ),
                    ),
                    if (widget.post.imageUrls.length > 1)
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.layers_fill, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '+${widget.post.imageUrls.length - 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
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

          // 4. Interaction Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Future extension: Like/Comment buttons could go here
                const Spacer(),
                GestureDetector(
                  onTap: () => _openDiscussion(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kPrimaryBlue, Color(0xFF4A6FDC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kPrimaryBlue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Transform.translate(
                      offset: const Offset(-1, 1),
                      child: const Icon(
                        CupertinoIcons.paperplane_fill,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openDiscussion(BuildContext context) async {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final chatVM = Provider.of<ChatViewModel>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (authVM.currentUser == null) {
      AppSnackBar.showError(context, languageProvider.tr('please_sign_in_to_contact', category: 'posts'));
      return;
    }

    if (authVM.currentUser!.uid == widget.post.userId) {
      AppSnackBar.showWarning(context, languageProvider.tr('cannot_message_yourself', category: 'posts'));
      return;
    }

    try {
      final chatId = await chatVM.createChat(
        clientId: authVM.currentUser!.uid,
        providerId: widget.post.userId,
      );

      if (mounted && chatId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DiscussionPage(
              contactName: widget.post.user,
              isOnline: true,
              chatId: chatId,
              currentUserId: authVM.currentUser!.uid,
              chatViewModel: chatVM,
              contactUserId: widget.post.userId,
              heroTag: 'chat_avatar_$chatId',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Error: $e');
      }
    }
  }

  Widget _buildSmallAvatar(String? photoUrl) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kPrimaryBlue.withValues(alpha: 0.1), width: 2),
      ),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: kPrimaryBlue.withValues(alpha: 0.05),
        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
            ? ImageUtils.getImageProvider(photoUrl)
            : null,
        child: (photoUrl == null || photoUrl.isEmpty)
            ? const Icon(Icons.person, color: kPrimaryBlue, size: 24)
            : null,
      ),
    );
  }

  Widget _buildMainImage(String imageString) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final imageProvider = ImageUtils.getImageProvider(imageString);
    if (imageProvider != null) {
      return Image(image: imageProvider, fit: BoxFit.cover);
    }
    return Container(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100);
  }
}

class ImageViewerDialog extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ImageViewerDialog({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<ImageViewerDialog> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToUserProfile(BuildContext context, String userId) async {
    final chatVM = Provider.of<ChatViewModel>(context, listen: false);
    final authVM = Provider.of<AuthViewModel>(context, listen: false);

    // If it's the current user, use the local data to avoid unnecessary network calls
    if (userId == authVM.currentUser?.uid && authVM.currentUser != null) {
      final user = authVM.currentUser!;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProviderProfileScreen(
            provider: ProviderModel.fromUser(user),
            serviceCategory: user.profession ?? 'Service Provider',
          ),
        ),
      );
      return;
    }

    try {
      final userData = await chatVM.getUserData(userId);
      if (userData != null && mounted) {
        final user = UserModel.fromMap(userData, userId);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProviderProfileScreen(
              provider: ProviderModel.fromUser(user),
              serviceCategory: user.profession ?? 'Service Provider',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error navigating to profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(0),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withValues(alpha: 0.9),
            ),
          ),
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final imageProvider =
                ImageUtils.getImageProvider(widget.imageUrls[index]);

                if (imageProvider == null) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.exclamationmark_circle,
                            color: Colors.red,
                            size: 50,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            languageProvider.tr('unable_to_load_image',
                                category: 'posts'),
                            style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return InteractiveViewer(
                  panEnabled: true,
                  scaleEnabled: true,
                  child: Center(
                    child: Image(
                      image: imageProvider,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),
          PositionedDirectional(
            top: 40,
            end: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.imageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
