import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/providers/language_provider.dart';
import 'home_constants.dart';

class HomeHeader extends StatelessWidget {
  final UserModel? currentUser;
  final TextEditingController searchController;
  final Function(String) onSearchChanged;
  final int notificationCount;
  final VoidCallback onNotificationPressed;

  const HomeHeader({
    super.key,
    required this.currentUser,
    required this.searchController,
    required this.onSearchChanged,
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
                const EdgeInsets.only(top: 60, left: 25, right: 25, bottom: 25),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  kPrimaryBlue,
                  const Color(0xFF4A6FDC),
                  const Color(0xFF667EEA),
                  const Color(0xFF764BA2),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(languageProvider),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Exo2',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getSubtitle(languageProvider),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              fontFamily: 'Exo2',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Stack(
                      children: [
                        IconButton(
                          onPressed: onNotificationPressed,
                          icon: const Icon(Icons.notifications_outlined,
                              color: Colors.white, size: 26),
                        ),
                        if (notificationCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                  minWidth: 16, minHeight: 16),
                              child: Text(
                                notificationCount > 9
                                    ? '9+'
                                    : notificationCount.toString(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: _getSearchHint(languageProvider),
                      hintStyle: TextStyle(
                        color: kMutedTextColor,
                        fontSize: 14,
                        fontFamily: 'Exo2',
                      ),
                      prefixIcon:
                          Icon(Icons.search, color: kPrimaryBlue, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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

  String _getGreeting(LanguageProvider lang) {
    final userName = currentUser?.name.split(' ').first;
    if (userName != null && userName.isNotEmpty) {
      return lang.trParams(
        'hello_user',
        category: 'home_page',
        params: {'name': userName},
      );
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
