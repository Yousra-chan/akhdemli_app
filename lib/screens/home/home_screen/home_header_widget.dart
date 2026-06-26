import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' as ui;
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/image_utils.dart';
import 'home_constants.dart';

class HomeHeader extends StatelessWidget {
  final UserModel? currentUser;
  final TextEditingController searchController;
  final Function(String) onSearchChanged;
  final Function(String)? onSearchSubmitted;
  final int notificationCount;
  final VoidCallback onNotificationPressed;

  const HomeHeader({
    super.key,
    required this.currentUser,
    required this.searchController,
    required this.onSearchChanged,
    this.onSearchSubmitted,
    required this.notificationCount,
    required this.onNotificationPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Directionality(
          textDirection: languageProvider.isRtl
              ? ui.TextDirection.rtl
              : ui.TextDirection.ltr,
          child: Container(
            width: double.infinity,
            padding:
            const EdgeInsets.fromLTRB(20, 60, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  kPrimaryBlue,
                  Color(0xFF4A6FDC),
                  Color(0xFF667EEA),
                  Color(0xFF764BA2),
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Top row: avatar + greeting + notification ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildAvatar(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getSubtitle(languageProvider),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                              fontFamily: 'Exo2',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getGreeting(languageProvider),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Exo2',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildNotificationIcon(),
                  ],
                ),
                const SizedBox(height: 20),
                // ── Search bar ────────────────────────────────
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    onSubmitted: onSearchSubmitted,
                    decoration: InputDecoration(
                      hintText: _getSearchHint(languageProvider),
                      hintStyle: const TextStyle(
                        color: kMutedTextColor,
                        fontSize: 14,
                        fontFamily: 'Exo2',
                      ),
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.search_rounded,
                            color: kPrimaryBlue, size: 20),
                        onPressed: () => onSearchSubmitted?.call(searchController.text),
                      ),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: kMutedTextColor, size: 18),
                              onPressed: () {
                                searchController.clear();
                                onSearchChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Avatar ────────────────────────────────────────────────
  Widget _buildAvatar() {
    final photoUrl = currentUser?.photoUrl;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
        color: Colors.white.withOpacity(0.2),
      ),
      child: ClipOval(
        child: photoUrl != null && photoUrl.isNotEmpty
            ? (ImageUtils.isBase64Image(photoUrl)
                ? Builder(
                    builder: (context) {
                      final bytes = ImageUtils.decodeBase64Image(photoUrl);
                      if (bytes == null) return _defaultAvatarIcon();
                      return Image.memory(bytes, fit: BoxFit.cover);
                    },
                  )
                : CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _defaultAvatarIcon(),
                  ))
            : _defaultAvatarIcon(),
      ),
    );
  }

  Widget _defaultAvatarIcon() {
    return Container(
      color: Colors.white.withOpacity(0.2),
      child: const Icon(Icons.person, color: Colors.white, size: 26),
    );
  }

  // ── Notification icon ─────────────────────────────────────
  Widget _buildNotificationIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: onNotificationPressed,
            icon: const Icon(Icons.notifications_outlined,
                color: Colors.white, size: 22),
            padding: EdgeInsets.zero,
          ),
        ),
        if (notificationCount > 0)
          PositionedDirectional(
            end: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints:
              const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                notificationCount > 9 ? '9+' : notificationCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // ── Text helpers ──────────────────────────────────────────
  String _getGreeting(LanguageProvider lang) {
    final userName = currentUser?.name.split(' ').first;
    if (userName != null && userName.isNotEmpty) {
      return lang.trParams('hello_user',
          category: 'home_page', params: {'name': userName});
    }
    return lang.tr('hello_guest', category: 'home_page');
  }

  String _getSubtitle(LanguageProvider lang) {
    final isProvider = currentUser?.isProvider ?? false;
    if (isProvider) {
      return lang.tr('manage_services', category: 'home_page');
    }
    return lang.tr('find_service_providers', category: 'home_page');
  }

  String _getSearchHint(LanguageProvider lang) {
    final isProvider = currentUser?.isProvider ?? false;
    if (isProvider) {
      return lang.tr('search_services_listings', category: 'home_page');
    }
    return lang.tr('search_services_providers', category: 'home_page');
  }
}