import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_app/screens/chat/chat_screen.dart';
import 'package:service_app/screens/home/home_screen/home_screen.dart'
    hide AuthViewModel;
import 'package:flutter/cupertino.dart';
import 'package:service_app/screens/profile/profile_page_loader.dart';
import 'package:service_app/screens/search/search_screen.dart';
import 'package:service_app/screens/posts/posts_screen.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/ViewModel/chat_view_model.dart';

class NavigatorBottom extends StatefulWidget {
  const NavigatorBottom({super.key});

  @override
  State<NavigatorBottom> createState() => _NavigatorBottomState();
}

class _NavigatorBottomState extends State<NavigatorBottom> {
  int selectorIndex = 0;

  // Updated colors to match header gradient
  final Color selectedColor =
      const Color.fromARGB(255, 12, 94, 153); // kPrimaryBlue
  final Color unselectedColor = const Color.fromARGB(255, 150, 180, 220);
  final Color backgroundColor =
      const Color.fromARGB(255, 248, 249, 255); // kLightBackgroundColor
  final Color navBackgroundColor = const Color.fromARGB(255, 255, 255, 255);

  // Badge widget for unread messages
  Widget _buildMessageBadge(int count, Widget child) {
    if (count <= 0) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -2,
          right: -2,
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
    Color highlight, {
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
                  color: selectedColor.withOpacity(0.3),
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

    // Add badge for chat icon (index 3)
    if (index == 3 && badgeCount > 0) {
      return _buildMessageBadge(badgeCount, iconWidget);
    }

    return iconWidget;
  }

  // New animated label
  Widget _buildLabel(int index, String label) {
    final bool selected = selectorIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 12, 94, 153),
                  Color(0xFF4A6FDC),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 300),
        style: TextStyle(
          fontSize: selected ? 12 : 11,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? Colors.white : unselectedColor,
        ),
        child: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);

    // Vérifier si l'utilisateur est connecté
    if (authViewModel.currentUser == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: selectedColor),
              const SizedBox(height: 20),
              Text(
                'Chargement du profil utilisateur...',
                style: TextStyle(color: unselectedColor),
              ),
            ],
          ),
        ),
      );
    }

    final String userId = authViewModel.currentUser!.uid;

    return ChangeNotifierProvider(
      create: (context) => ChatViewModel(userId: userId),
      child: Consumer<ChatViewModel>(
        builder: (context, chatViewModel, child) {
          return StreamBuilder<int>(
            stream: chatViewModel.getTotalUnreadCount(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;

              return Scaffold(
                backgroundColor: backgroundColor,
                body: IndexedStack(
                  index: selectorIndex,
                  children: [
                    const HomePage(),
                    const MapSearchPage(),
                    const FeedScreen(),
                    ChatPage(userId: userId),
                    const ProfilePageLoader(),
                  ],
                ),
                bottomNavigationBar: Container(
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
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
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
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                      currentIndex: selectorIndex,
                      type: BottomNavigationBarType.fixed,
                      elevation: 0,
                      items: [
                        BottomNavigationBarItem(
                          icon: _buildIcon(
                            0,
                            CupertinoIcons.briefcase,
                            CupertinoIcons.briefcase_fill,
                            selectedColor,
                          ),
                          label: 'Services',
                        ),
                        BottomNavigationBarItem(
                          icon: _buildIcon(
                            1,
                            CupertinoIcons.map,
                            CupertinoIcons.map_fill,
                            selectedColor,
                          ),
                          label: 'Search',
                        ),
                        BottomNavigationBarItem(
                          icon: _buildIcon(
                            2,
                            CupertinoIcons.home,
                            CupertinoIcons.home,
                            selectedColor,
                          ),
                          label: 'Home',
                        ),
                        BottomNavigationBarItem(
                          icon: _buildIcon(
                            3,
                            CupertinoIcons.chat_bubble,
                            CupertinoIcons.chat_bubble_2_fill,
                            selectedColor,
                            badgeCount: unreadCount,
                          ),
                          label: 'Chat',
                        ),
                        BottomNavigationBarItem(
                          icon: _buildIcon(
                            4,
                            CupertinoIcons.person,
                            CupertinoIcons.person_fill,
                            selectedColor,
                          ),
                          label: 'Profile',
                        ),
                      ],
                      onTap: (val) {
                        setState(() {
                          selectorIndex = val;
                        });
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
