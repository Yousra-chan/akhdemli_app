import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_app/screens/chat/chat_screen.dart';
import 'package:service_app/screens/home/home_screen/home_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:service_app/screens/profile/profile_page_loader.dart';
import 'package:service_app/screens/search/search_screen.dart';
import 'package:service_app/screens/posts/posts_screen.dart';
import 'package:service_app/screens/admin/admin_scaffold.dart';
import 'package:service_app/screens/auth/account_activation_required_page.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/ViewModel/chat_view_model.dart';
import 'package:service_app/providers/language_provider.dart';
import 'dart:ui' as ui;

class NavigatorBottom extends StatefulWidget {
  const NavigatorBottom({super.key});

  @override
  State<NavigatorBottom> createState() => _NavigatorBottomState();
}

class _NavigatorBottomState extends State<NavigatorBottom> {
  int selectorIndex = 0;

  // Helper method to build navigation children
  List<Widget> _buildNavigationChildren({
    required String userId,
  }) {
    return [
      const HomePage(),
      const MapSearchPage(),
      const FeedScreen(),
      ChatPage(userId: userId),
      const ProfilePageLoader(),
    ];
  }

  // Helper method to build navigation items
  List<BottomNavigationBarItem> _buildNavigationItems({
    required LanguageProvider languageProvider,
    required Color selectedColor,
    required Color unselectedColor,
    required int unreadCount,
  }) {
    return [
      BottomNavigationBarItem(
        icon: _buildIcon(
          0,
          CupertinoIcons.briefcase,
          CupertinoIcons.briefcase_fill,
          selectedColor,
          unselectedColor,
        ),
        label: languageProvider.tr('services', category: 'nav_bottom'),
      ),
      BottomNavigationBarItem(
        icon: _buildIcon(
          1,
          CupertinoIcons.map,
          CupertinoIcons.map_fill,
          selectedColor,
          unselectedColor,
        ),
        label: languageProvider.tr('search', category: 'nav_bottom'),
      ),
      BottomNavigationBarItem(
        icon: _buildIcon(
          2,
          CupertinoIcons.home,
          CupertinoIcons.home,
          selectedColor,
          unselectedColor,
        ),
        label: languageProvider.tr('home', category: 'nav_bottom'),
      ),
      BottomNavigationBarItem(
        icon: _buildIcon(
          3,
          CupertinoIcons.chat_bubble,
          CupertinoIcons.chat_bubble_2_fill,
          selectedColor,
          unselectedColor,
          badgeCount: unreadCount,
        ),
        label: languageProvider.tr('chat', category: 'nav_bottom'),
      ),
      BottomNavigationBarItem(
        icon: _buildIcon(
          4,
          CupertinoIcons.person,
          CupertinoIcons.person_fill,
          selectedColor,
          unselectedColor,
        ),
        label: languageProvider.tr('profile', category: 'nav_bottom'),
      ),
    ];
  }

  // Badge widget for unread messages
  Widget _buildMessageBadge(int count, Widget child) {
    if (count <= 0) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        PositionedDirectional(
          top: -2,
          end: -2,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            child: Text(
              count > 99 ? '99+' : count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(
    int index,
    IconData outline,
    IconData filled,
    Color highlight,
    Color unselectedColor, {
    int badgeCount = 0,
  }) {
    final bool selected = selectorIndex == index;

    Widget iconWidget = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 12, 94, 153),
                  Color(0xFF4A6FDC),
                  Color(0xFF667EEA),
                ],
              )
            : null,
        color: selected ? null : Colors.transparent,
        shape: BoxShape.circle,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: highlight.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return ScaleTransition(
            scale: animation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        child: Icon(
          selected ? filled : outline,
          key: ValueKey<bool>(selected),
          size: selected ? 26 : 24,
          color: selected ? Colors.white : unselectedColor,
        ),
      ),
    );

    // Add badge ONLY for chat messages (index 3)
    if (index == 3 && badgeCount > 0) {
      return _buildMessageBadge(badgeCount, iconWidget);
    }

    return iconWidget;
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);

    // Dynamic colors based on theme
    final Color selectedColor = theme.primaryColor;
    final Color unselectedColor = theme.brightness == Brightness.dark
        ? Colors.white38
        : const Color.fromARGB(255, 150, 180, 220);
    final Color backgroundColor = theme.scaffoldBackgroundColor;
    final Color navBackgroundColor = theme.cardColor;

    // Check if user is logged in
    if (authViewModel.currentUser == null) {
      return Directionality(
        textDirection: languageProvider.isRtl
            ? ui.TextDirection.rtl
            : ui.TextDirection.ltr,
        child: Scaffold(
          backgroundColor: backgroundColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: selectedColor),
                const SizedBox(height: 20),
                Text(
                  languageProvider.tr('loading_profile',
                      category: 'nav_bottom'),
                  style: TextStyle(color: unselectedColor, fontFamily: 'Exo2'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = authViewModel.currentUser!;

    if (user.isAdmin) {
      return Directionality(
        textDirection: languageProvider.isRtl
            ? ui.TextDirection.rtl
            : ui.TextDirection.ltr,
        child: const AdminScaffold(),
      );
    }

    if (user.isProvider && !user.hasValidSubscription) {
      return Directionality(
        textDirection: languageProvider.isRtl
            ? ui.TextDirection.rtl
            : ui.TextDirection.ltr,
        child: const AccountActivationRequiredPage(),
      );
    }

    final String userId = user.uid;

    return Consumer<ChatViewModel?>(
      builder: (context, chatViewModel, child) {
        if (chatViewModel == null) {
          return Directionality(
            textDirection: languageProvider.isRtl
                ? ui.TextDirection.rtl
                : ui.TextDirection.ltr,
            child: Scaffold(
              backgroundColor: backgroundColor,
              body: IndexedStack(
                index: selectorIndex,
                children: _buildNavigationChildren(
                  userId: userId,
                ),
              ),
              bottomNavigationBar: _buildBottomNav(
                navBackgroundColor,
                selectedColor,
                unselectedColor,
                0,
                languageProvider,
              ),
            ),
          );
        }

        return StreamBuilder<int>(
          stream: chatViewModel.getTotalUnreadCount(),
          builder: (context, snapshot) {
            // Only messages from chats.unreadCount (NOT from notifications collection)
            final messageUnreadCount = snapshot.data ?? 0;

            return Directionality(
              textDirection: languageProvider.isRtl
                  ? ui.TextDirection.rtl
                  : ui.TextDirection.ltr,
              child: Scaffold(
                backgroundColor: backgroundColor,
                body: IndexedStack(
                  index: selectorIndex,
                  children: _buildNavigationChildren(
                    userId: userId,
                  ),
                ),
                bottomNavigationBar: _buildBottomNav(
                  navBackgroundColor,
                  selectedColor,
                  unselectedColor,
                  messageUnreadCount,
                  languageProvider,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomNav(
    Color navBackgroundColor,
    Color selectedColor,
    Color unselectedColor,
    int unreadCount,
    LanguageProvider languageProvider,
  ) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: navBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: selectedColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BottomNavigationBar(
          backgroundColor: navBackgroundColor,
          selectedItemColor: selectedColor,
          unselectedItemColor: unselectedColor,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.2,
            fontFamily: 'Exo2',
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.2,
            fontFamily: 'Exo2',
          ),
          currentIndex: selectorIndex,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: _buildNavigationItems(
            languageProvider: languageProvider,
            selectedColor: selectedColor,
            unselectedColor: unselectedColor,
            unreadCount: unreadCount,
          ),
          onTap: (val) {
            setState(() {
              selectorIndex = val;
            });
          },
        ),
      ),
    );
  }
}
