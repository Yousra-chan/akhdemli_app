import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:service_app/providers/language_provider.dart';
import 'posts_constants.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/ViewModel/chat_view_model.dart';
import 'package:service_app/screens/chat/disscussion/disscussion_page.dart';
import 'package:service_app/utils/image_utils.dart';
import 'package:service_app/utils/ui_widgets.dart';
import 'package:shimmer/shimmer.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final bool showFullDescription;

  const PostCard({
    super.key,
    required this.post,
    this.showFullDescription = false,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isChatLoading = false;

  String _formatTime(BuildContext context, DateTime timestamp) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
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
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final user = authVM.currentUser;

    if (user == null) {
      AppSnackBar.showError(context, lang.tr('please_sign_in_to_contact', category: 'posts'));
      return;
    }

    if (user.uid == widget.post.userId) {
      AppSnackBar.showWarning(context, lang.tr('cannot_message_yourself', category: 'posts'));
      return;
    }

    setState(() => _isChatLoading = true);

    // Try to get ChatViewModel from context
    final chatVM = Provider.of<ChatViewModel?>(context, listen: false);
    
    // If chatVM is null (happens if ProxyProvider hasn't updated), 
    // we can fallback to creating a temporary one if we have the userId
    final activeChatVM = chatVM ?? ChatViewModel(userId: user.uid);

    try {
      // 1. Create/Get Chat
      final chatId = await activeChatVM.createChat(
        clientId: user.uid,
        providerId: widget.post.userId,
      );

      if (chatId == null) {
        if (context.mounted) {
          AppSnackBar.showError(context, lang.tr('chat_creation_error', category: 'chat'));
        }
        return;
      }

      // 2. Pre-fetch profile image for better UX
      final profileImageUrl = await activeChatVM.getUserProfileImageUrl(widget.post.userId);

      // 3. Navigate
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => DiscussionPage(
              contactName: widget.post.user,
              isOnline: true,
              chatId: chatId,
              currentUserId: user.uid,
              chatViewModel: activeChatVM,
              contactUserId: widget.post.userId,
              profileImageUrl: profileImageUrl,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error in _handleChatPress: $e');
      if (context.mounted) {
        AppSnackBar.showError(
          context,
          lang.trParams(
            'error_prefix',
            category: 'chat',
            params: {'error': e.toString()},
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isChatLoading = false);
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
        border: Border.all(color: typeColor.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: typeColor.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Exo2'),
        ),
      ),
    );
  }

  Widget _buildHorizontalImageRow(BuildContext context, List<String> imageUrls) {
    final lang = Provider.of<LanguageProvider>(context);
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(CupertinoIcons.photo_fill_on_rectangle_fill, color: Theme.of(context).primaryColor.withOpacity(0.8), size: 14),
                const SizedBox(width: 6),
                Text(
                  '${imageUrls.length} ${imageUrls.length == 1 ? lang.tr('photo', category: 'posts') : lang.tr('photos', category: 'posts')}',
                  style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : kMutedTextColor, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 180,
                  margin: EdgeInsets.only(right: index < imageUrls.length - 1 ? 12 : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).cardColor,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.08), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: GestureDetector(
                    onTap: () => _showImageDialog(context, imageUrls, index),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildImageWidget(context, imageUrls[index]),
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
    final imageProvider = ImageUtils.getImageProvider(imageString);

    if (imageProvider == null) {
      return Center(child: Icon(CupertinoIcons.photo, color: Colors.grey.shade300, size: 40));
    }

    return Image(
      image: imageProvider,
      fit: BoxFit.cover,
      errorBuilder: (ctx, err, stack) => Center(child: Icon(Icons.error_outline, color: Colors.red.shade300)),
    );
  }

  void _showImageDialog(BuildContext context, List<String> imageUrls, int index) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ImageViewerDialog(imageUrls: imageUrls, initialIndex: index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color typeColor = widget.post.type == PostType.seeking ? kSeekingColor : kOfferingColor;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserAvatar(typeColor, widget.post.user),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(widget.post.user, style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Exo2'))),
                            Text(_formatTime(context, widget.post.timestamp), style: TextStyle(color: isDark ? Colors.white38 : kMutedTextColor, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                              child: Text(widget.post.type == PostType.seeking ? lang.tr('looking_for', category: 'posts') : lang.tr('offering', category: 'posts'), style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Text(lang.tr(widget.post.categoryTranslationKey, category: 'categories'), style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.post.title, style: TextStyle(color: theme.textTheme.titleLarge?.color, fontWeight: FontWeight.bold, fontSize: 17, fontFamily: 'Exo2')),
                  const SizedBox(height: 8),
                  Text(widget.post.body, style: const TextStyle(fontSize: 14, height: 1.5), maxLines: widget.showFullDescription ? null : 3, overflow: widget.showFullDescription ? null : TextOverflow.ellipsis),
                ],
              ),
            ),
            if (widget.post.imageUrls.isNotEmpty) _buildHorizontalImageRow(context, widget.post.imageUrls),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _isChatLoading ? null : () => _handleChatPress(context),
                icon: _isChatLoading 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(CupertinoIcons.chat_bubble_text_fill, size: 16),
                label: Text(lang.tr('contact', category: 'posts'), style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
          ],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

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
              color: Colors.black.withOpacity(0.9),
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
                        color: Colors.white,
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
                              color: Colors.grey.shade800,
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
                    color: Colors.black.withOpacity(0.5),
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
          if (widget.imageUrls.length > 1)
            PositionedDirectional(
              start: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Icon(
                    languageProvider.isRtl ? Icons.chevron_right : Icons.chevron_left,
                    color: Colors.white,
                    size: 40,
                  ),
                  onPressed: _currentIndex > 0
                      ? () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                      : null,
                ),
              ),
            ),
          if (widget.imageUrls.length > 1)
            PositionedDirectional(
              end: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Icon(
                    languageProvider.isRtl ? Icons.chevron_left : Icons.chevron_right,
                    color: Colors.white,
                    size: 40,
                  ),
                  onPressed: _currentIndex < widget.imageUrls.length - 1
                      ? () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
