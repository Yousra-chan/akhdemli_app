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
  final FocusNode? focusNode;
  final Function(String) onSearchChanged;
  final Function(String)? onSearchSubmitted;
  final int notificationCount;
  final VoidCallback onNotificationPressed;

  const HomeHeader({
    super.key,
    required this.currentUser,
    required this.searchController,
    this.focusNode,
    required this.onSearchChanged,
    this.onSearchSubmitted,
    required this.notificationCount,
    required this.onNotificationPressed,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isRtl = languageProvider.isRtl;

    return Directionality(
      textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Column(
        children: [
          // ── Top Row: Avatar, Location, Notification ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAvatar(),
                _buildLocationInfo(languageProvider),
                _buildNotificationIcon(),
              ],
            ),
          ),
          const SizedBox(height: 15),

          // ── Weather/Promo Card with Search Bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildPromoCard(languageProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final photoUrl = currentUser?.photoUrl;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
      color: kPrimaryBlue.withOpacity(0.1),
      child: const Icon(Icons.person, color: kPrimaryBlue, size: 22),
    );
  }

  Widget _buildLocationInfo(LanguageProvider lang) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lang.tr('my_location', category: 'home_page'),
              style: const TextStyle(
                fontSize: 12,
                color: kMutedTextColor,
                fontFamily: 'Exo2',
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 14, color: kMutedTextColor),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, size: 14, color: kPrimaryBlue),
            const SizedBox(width: 4),
            Text(
              currentUser?.commune ?? "Algeria",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: kDarkTextColor,
                fontFamily: 'Exo2',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationIcon() {
    return Stack(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onNotificationPressed,
            icon: const Icon(Icons.notifications_none_rounded, color: kDarkTextColor, size: 20),
            padding: EdgeInsets.zero,
          ),
        ),
        if (notificationCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPromoCard(LanguageProvider lang) {
    // Making weather dynamic using user's context or a placeholder that sounds dynamic
    final hour = DateTime.now().hour;
    String timeGreeting = "Good Morning";
    IconData weatherIcon = Icons.wb_sunny_rounded;
    
    if (hour >= 12 && hour < 17) {
      timeGreeting = "Good Afternoon";
      weatherIcon = Icons.wb_cloudy_rounded;
    } else if (hour >= 17 || hour < 5) {
      timeGreeting = "Good Evening";
      weatherIcon = Icons.nightlight_round;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        image: const DecorationImage(
          image: AssetImage('assets/images/home_pic.png'),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: kPrimaryBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              kPrimaryBlue.withOpacity(0.4),
              kPrimaryBlue.withOpacity(0.8),
            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.tr(timeGreeting.toLowerCase().replaceAll(' ', '_'), category: 'home_page'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontFamily: 'Exo2',
                          shadows: [Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
                        ),
                      ),
                      Text(
                        lang.tr('ready_to_work', category: 'home_page'),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Exo2',
                          shadows: const [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
                        ),
                      ),
                    ],
                  ),
                  Icon(weatherIcon, color: Colors.white, size: 50, shadows: const [Shadow(color: Colors.black26, blurRadius: 10)]),
                ],
              ),
            ),
            // ── Search Bar inside Card ──
            Container(
              margin: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: TextField(
                controller: searchController,
                focusNode: focusNode,
                onChanged: onSearchChanged,
                onSubmitted: onSearchSubmitted,
                decoration: InputDecoration(
                  hintText: lang.tr('search_hint', category: 'home_page'),
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontFamily: 'Exo2'),
                  prefixIcon: IconButton(
                    icon: const Icon(Icons.search, color: kPrimaryBlue, size: 20),
                    onPressed: () {
                      if (searchController.text.trim().isNotEmpty) {
                        onSearchSubmitted?.call(searchController.text);
                      }
                    },
                  ),
                  suffixIcon: InkWell(
                    onTap: () {
                      if (searchController.text.isNotEmpty) {
                        searchController.clear();
                        onSearchChanged('');
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: kPrimaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        searchController.text.isNotEmpty ? Icons.close : Icons.tune_rounded,
                        color: kPrimaryBlue,
                        size: 16,
                      ),
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
