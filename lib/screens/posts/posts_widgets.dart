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

class PostCard extends StatelessWidget {
  final Post post;
  final bool showFullDescription;

  const PostCard({
    super.key,
    required this.post,
    this.showFullDescription = false,
  });

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

    if (user.uid == post.userId) {
      AppSnackBar.showWarning(context, lang.tr('cannot_message_yourself', category: 'posts'));
      return;
    }

    // Try to get ChatViewModel from context
    final chatVM = Provider.of<ChatViewModel?>(context, listen: false);
    
    // If chatVM is null (happens if ProxyProvider hasn't updated), 
    // we can fallback to creating a temporary one if we have the userId
    final activeChatVM = chatVM ?? ChatViewModel(userId: user.uid);

    try {
      // 1. Create/Get Chat
      final chatId = await activeChatVM.createChat(
        clientId: user.uid,
        providerId: post.userId,
      );

      if (chatId == null) {
        if (context.mounted) {
          AppSnackBar.showError(context, lang.tr('chat_creation_error', category: 'chat'));
        }
        return;
      }

      // 2. Pre-fetch profile image for better UX
      final profileImageUrl = await activeChatVM.getUserProfileImageUrl(post.userId);

      // 3. Navigate
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => DiscussionPage(
              contactName: post.user,
              isOnline: true,
              chatId: chatId,
              currentUserId: user.uid,
              chatViewModel: activeChatVM,
              contactUserId: post.userId,
              profileImageUrl: profileImageUrl,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error in _handleChatPress: $e');
      if (context.mounted) {
        // Show the actual error message to help debug
        AppSnackBar.showError(
          context,
          lang.trParams(
            'error_prefix',
            category: 'chat',
            params: {'error': e.toString()},
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
            typeColor.withValues(alpha: 0.8),
            typeColor.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: typeColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [BoxShadow(color: typeColor.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
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
                Icon(CupertinoIcons.photo_fill_on_rectangle_fill, color: Theme.of(context).primaryColor.withValues(alpha: 0.8), size: 14),
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
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.08), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: GestureDetector(
                    onTap: () => _showImageDialog(context, imageUrls[index], index, imageUrls),
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
    final lang = Provider.of<LanguageProvider>(context);
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

  void _showImageDialog(BuildContext context, String imageUrl, int index, List<String> imageUrls) {
    showDialog(context: context, builder: (ctx) => ImageDialog(imageUrls: imageUrls, initialIndex: index));
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color typeColor = post.type == PostType.seeking ? kSeekingColor : kOfferingColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserAvatar(typeColor, post.user),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(post.user, style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Exo2'))),
                          Text(_formatTime(context, post.timestamp), style: TextStyle(color: isDark ? Colors.white38 : kMutedTextColor, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text(post.type == PostType.seeking ? lang.tr('looking_for', category: 'posts') : lang.tr('offering', category: 'posts'), style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Text(lang.tr(post.categoryTranslationKey, category: 'categories'), style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 11)),
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
                Text(post.title, style: TextStyle(color: theme.textTheme.titleLarge?.color, fontWeight: FontWeight.bold, fontSize: 17, fontFamily: 'Exo2')),
                const SizedBox(height: 8),
                Text(post.body, style: const TextStyle(fontSize: 14, height: 1.5), maxLines: showFullDescription ? null : 3, overflow: showFullDescription ? null : TextOverflow.ellipsis),
              ],
            ),
          ),
          if (post.imageUrls.isNotEmpty) _buildHorizontalImageRow(context, post.imageUrls),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => _handleChatPress(context),
              icon: const Icon(CupertinoIcons.chat_bubble_text_fill, size: 16),
              label: Text(lang.tr('contact', category: 'posts'), style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ],
      ),
    );
  }
}

class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
      child: Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Column(
          children: [
            Row(children: [const CircleAvatar(radius: 22), const SizedBox(width: 12), Container(width: 100, height: 12, color: Colors.white)]),
            const SizedBox(height: 20),
            Container(width: double.infinity, height: 16, color: Colors.white),
            const SizedBox(height: 10),
            Container(width: 200, height: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class ImageDialog extends StatelessWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ImageDialog({super.key, required this.imageUrls, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: imageUrls.length,
            controller: PageController(initialPage: initialIndex),
            itemBuilder: (ctx, idx) => InteractiveViewer(child: Center(child: Image(image: ImageUtils.getImageProvider(imageUrls[idx])!, fit: BoxFit.contain))),
          ),
          Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))),
        ],
      ),
    );
  }
}
