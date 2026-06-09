import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:service_app/Models/UserModel.dart';
import 'package:provider/provider.dart';
import 'package:service_app/providers/language_provider.dart';
import 'posts_constants.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/ViewModel/chat_view_model.dart';
import 'package:service_app/screens/chat/disscussion/disscussion_page.dart';
import 'package:service_app/utils/image_utils.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final bool showFullDescription;

  const PostCard({
    super.key,
    required this.post,
    this.showFullDescription = false,
  });

  String _formatTime(BuildContext context, DateTime timestamp) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final difference = DateTime.now().difference(timestamp);

    if (difference.inSeconds < 60) {
      return languageProvider.tr('just_now', category: 'posts');
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? languageProvider.tr('min_ago', category: 'posts') : languageProvider.tr('mins_ago', category: 'posts')}';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? languageProvider.tr('hour_ago', category: 'posts') : languageProvider.tr('hours_ago', category: 'posts')}';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? languageProvider.tr('day_ago', category: 'posts') : languageProvider.tr('days_ago', category: 'posts')}';
    } else {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? languageProvider.tr('week_ago', category: 'posts') : languageProvider.tr('weeks_ago', category: 'posts')}';
    }
  }

  Future<void> _handleChatPress(BuildContext context) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final currentUser = authViewModel.currentUser;

    final String peerId = post.userId;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.tr('please_sign_in_to_contact', category: 'posts'),
          ),
          backgroundColor: kSeekingColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (currentUser.uid == peerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.tr('cannot_message_yourself', category: 'posts'),
          ),
          backgroundColor: kAccentColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: kPrimaryBlue,
          ),
        ),
      );

      final chatViewModel = ChatViewModel(userId: currentUser.uid);
      final chatId = await chatViewModel.createChat(
        clientId: currentUser.uid,
        providerId: peerId,
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        if (chatId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DiscussionPage(
                chatId: chatId,
                currentUserId: currentUser.uid,
                contactName: post.user,
                isOnline: true,
                chatViewModel: chatViewModel,
              ),
            ),
          );
        } else {
          throw Exception("Failed to create chat");
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.trParams(
                'failed_to_start_chat',
                category: 'posts',
                params: {'error': e.toString().split(':').last.trim()},
              ),
            ),
            backgroundColor: kSeekingColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Widget _buildUserAvatar(Color typeColor, String userName) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            typeColor.withOpacity(0.8),
            typeColor.withOpacity(0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: typeColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: typeColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            fontFamily: 'Exo2',
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalImageRow(
      BuildContext context, List<String> imageUrls) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    if (imageUrls.isEmpty) return const SizedBox.shrink();

    final int imageCount = imageUrls.length;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Images label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.photo_fill_on_rectangle_fill,
                  color: kPrimaryBlue.withOpacity(0.8),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  '$imageCount ${imageCount == 1 ? languageProvider.tr('photo', category: 'posts') : languageProvider.tr('photos', category: 'posts')}',
                  style: TextStyle(
                    color: kMutedTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (imageCount > 1)
                  GestureDetector(
                    onTap: () =>
                        _showImageDialog(context, imageUrls[0], 0, imageUrls),
                    child: Row(
                      children: [
                        Text(
                          languageProvider.tr('view_all', category: 'posts'),
                          style: TextStyle(
                            color: kPrimaryBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: kPrimaryBlue,
                          size: 12,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Horizontal scrollable images
          SizedBox(
            height: 200, // Fixed height for all images
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 180, // Fixed width for each image
                  margin: EdgeInsets.only(
                    right: index < imageUrls.length - 1 ? 12 : 0,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: GestureDetector(
                    onTap: () => _showImageDialog(
                        context, imageUrls[index], index, imageUrls),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          _buildImageWidget(context, imageUrls[index]),
                          // Image number indicator for multiple images
                          if (imageCount > 1)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
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

  Widget _buildImageWidget(BuildContext context, String imageString) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final imageProvider = ImageUtils.getImageProvider(imageString);

    if (imageProvider == null) {
      return Container(
        color: Colors.grey.shade50,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.photo_fill_on_rectangle_fill,
                color: Colors.grey.shade300,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                languageProvider.tr('failed_to_load', category: 'posts'),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Image(
      image: imageProvider,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey.shade50,
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              color: kPrimaryBlue,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey.shade50,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_circle,
                  color: Colors.grey.shade300,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  languageProvider.tr('failed_to_load', category: 'posts'),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl, int index,
      List<String> imageUrls) {
    showDialog(
      context: context,
      builder: (context) => ImageDialog(
        imageUrls: imageUrls,
        initialIndex: index,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final Color typeColor =
        post.type == PostType.seeking ? kSeekingColor : kOfferingColor;
    final String typeLabel = post.type == PostType.seeking
        ? languageProvider.tr('looking_for', category: 'posts')
        : languageProvider.tr('offering', category: 'posts');
    final bool hasImages = post.imageUrls.isNotEmpty;
    final bool isExpanded = showFullDescription;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User avatar
                _buildUserAvatar(typeColor, post.user),
                const SizedBox(width: 12),

                // User info and content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User name and timestamp
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              post.user,
                              style: const TextStyle(
                                color: kDarkTextColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                fontFamily: 'Exo2',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(context, post.timestamp),
                            style: TextStyle(
                              color: kMutedTextColor,
                              fontSize: 12,
                              fontFamily: 'Exo2',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Type and category
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  post.type == PostType.seeking
                                      ? CupertinoIcons.search
                                      : CupertinoIcons.briefcase,
                                  size: 12,
                                  color: typeColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  typeLabel,
                                  style: TextStyle(
                                    color: typeColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Exo2',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: kLightBackgroundColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: kMutedTextColor.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              post.serviceCategory,
                              style: const TextStyle(
                                color: kDarkTextColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
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

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  post.title,
                  style: const TextStyle(
                    color: kDarkTextColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    fontFamily: 'Exo2',
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  post.body,
                  style: const TextStyle(
                    color: kDarkTextColor,
                    fontSize: 14,
                    fontFamily: 'Exo2',
                    height: 1.5,
                  ),
                  maxLines: isExpanded ? null : 3,
                  overflow: isExpanded ? null : TextOverflow.ellipsis,
                ),
                SizedBox(height: hasImages ? 16 : 0),
              ],
            ),
          ),

          // Images (if any) - HORIZONTAL SCROLLABLE ROW
          if (hasImages) _buildHorizontalImageRow(context, post.imageUrls),

          // Action buttons
          Padding(
            padding: EdgeInsets.fromLTRB(16, hasImages ? 16 : 8, 16, 16),
            child: Row(
              children: [
                // Contact button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleChatPress(context),
                    icon: const Icon(
                      CupertinoIcons.chat_bubble_text_fill,
                      size: 16,
                    ),
                    label: Text(
                      languageProvider.tr('contact', category: 'posts'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        fontFamily: 'Exo2',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),

                // View images button (only if has images)
                if (hasImages) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      _showImageDialog(
                          context, post.imageUrls[0], 0, post.imageUrls);
                    },
                    icon: Icon(
                      CupertinoIcons.photo_fill_on_rectangle_fill,
                      color: kPrimaryBlue,
                      size: 16,
                    ),
                    label: Text(
                      '${languageProvider.tr('view', category: 'posts')} ${post.imageUrls.length}',
                      style: TextStyle(
                        color: kPrimaryBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        fontFamily: 'Exo2',
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(
                        color: kPrimaryBlue.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced Image Dialog
class ImageDialog extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ImageDialog({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<ImageDialog> createState() => _ImageDialogState();
}

class _ImageDialogState extends State<ImageDialog> {
  late PageController _pageController;
  late int _currentIndex;

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

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(0),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withOpacity(0.95),
        child: Stack(
          children: [
            // Images
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  panEnabled: true,
                  scaleEnabled: true,
                  child: Center(
                    child: _buildImageWidget(context, widget.imageUrls[index]),
                  ),
                );
              },
            ),

            // Close button
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            // Image counter
            if (widget.imageUrls.length > 1)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

            // Navigation dots
            if (widget.imageUrls.length > 1)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(widget.imageUrls.length, (index) {
                      return Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentIndex == index
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                        ),
                      );
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(BuildContext context, String imageString) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final imageProvider = ImageUtils.getImageProvider(imageString);

    if (imageProvider == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_circle,
              color: Colors.grey.shade400,
              size: 50,
            ),
            const SizedBox(height: 12),
            Text(
              languageProvider.tr('unable_to_load_image', category: 'posts'),
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Image(
      image: imageProvider,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
            color: Colors.white,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_circle,
                color: Colors.grey.shade400,
                size: 50,
              ),
              const SizedBox(height: 12),
              Text(
                languageProvider.tr('failed_to_load_image', category: 'posts'),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
