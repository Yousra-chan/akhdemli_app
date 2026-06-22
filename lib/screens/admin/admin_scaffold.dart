import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ViewModel/admin_view_model.dart';
import '../../ViewModel/auth_view_model.dart';
import '../../providers/language_provider.dart';
import '../auth/login/login_screen.dart';
import 'admin_components.dart';
import 'tabs/dashboard_overview.dart';
import 'tabs/users_tab.dart';
import 'tabs/services_tab.dart';
import 'tabs/reports_tab.dart';
import 'tabs/settings_tab.dart';
import 'tabs/subscription_codes_tab.dart';
import 'tabs/categories_tab.dart';
import 'tabs/notifications_tab.dart';

class AdminScaffold extends StatefulWidget {
  const AdminScaffold({super.key});

  @override
  State<AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends State<AdminScaffold> {
  int _selectedIndex = 0;

  // _tabs is now a getter so DashboardOverview receives the live callback
  List<Widget> get _tabs => [
    DashboardOverview(onNavigate: _onSelect),
    const UsersTab(),
    const ServicesTab(),
    const ReportsTab(),
    const CategoriesTab(),
    const SubscriptionCodesTab(),
    const NotificationsTab(),
    const AdminSettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1200;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<LanguageProvider>();

    return ChangeNotifierProvider(
      create: (_) => AdminViewModel(),
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF13151A)
            : const Color(0xFFF6F7FB),
        drawer: !isDesktop ? _buildSidebar(context, lang, isDark) : null,
        appBar: !isDesktop
            ? AppBar(
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          iconTheme: IconThemeData(color: Theme.of(context).primaryColor),
          title: Text(
            _getTabTitle(lang),
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        )
            : null,
        body: Row(
          children: [
            if (isDesktop) _buildSidebar(context, lang, isDark),
            Expanded(
              child: Column(
                children: [
                  if (isDesktop) _buildHeader(context, lang, isDark),
                  Expanded(
                    child: _tabs[_selectedIndex],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTabTitle(LanguageProvider lang) {
    switch (_selectedIndex) {
      case 0: return lang.tr('dashboard', category: 'admin');
      case 1: return lang.tr('users', category: 'admin');
      case 2: return lang.tr('services', category: 'admin');
      case 3: return lang.tr('reports', category: 'admin');
      case 4: return lang.tr('categories', category: 'admin');
      case 5: return lang.tr('codes', category: 'admin');
      case 6: return lang.tr('broadcast', category: 'admin');
      case 7: return lang.tr('settings', category: 'admin');
      default: return lang.tr('admin_panel', category: 'admin');
    }
  }

  Widget _buildSidebar(BuildContext context, LanguageProvider lang, bool isDark) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // ---------- Brand ----------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AdminColors.primary, Color(0xFF5B6CFF)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AdminColors.primary.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.security_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    lang.tr('app_name', category: 'auth').toUpperCase(),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      letterSpacing: 1.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                lang.tr('admin_console', category: 'admin'),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  AdminSidebarItem(index: 0, selectedIndex: _selectedIndex, icon: Icons.grid_view_rounded, title: lang.tr('dashboard', category: 'admin'), onTap: () => _onSelect(0)),
                  AdminSidebarItem(index: 1, selectedIndex: _selectedIndex, icon: Icons.people_rounded, title: lang.tr('users', category: 'admin'), onTap: () => _onSelect(1)),
                  AdminSidebarItem(index: 2, selectedIndex: _selectedIndex, icon: Icons.miscellaneous_services_rounded, title: lang.tr('services', category: 'admin'), onTap: () => _onSelect(2)),
                  AdminSidebarItem(index: 3, selectedIndex: _selectedIndex, icon: Icons.report_problem_rounded, title: lang.tr('reports', category: 'admin'), onTap: () => _onSelect(3)),
                  AdminSidebarItem(index: 4, selectedIndex: _selectedIndex, icon: Icons.category_rounded, title: lang.tr('categories', category: 'admin'), onTap: () => _onSelect(4)),
                  AdminSidebarItem(index: 5, selectedIndex: _selectedIndex, icon: Icons.vpn_key_rounded, title: lang.tr('codes', category: 'admin'), onTap: () => _onSelect(5)),
                  AdminSidebarItem(index: 6, selectedIndex: _selectedIndex, icon: Icons.campaign_rounded, title: lang.tr('broadcast', category: 'admin'), onTap: () => _onSelect(6)),
                  AdminSidebarItem(index: 7, selectedIndex: _selectedIndex, icon: Icons.settings_rounded, title: lang.tr('settings', category: 'admin'), onTap: () => _onSelect(7)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Divider(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
              height: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _handleLogout(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AdminColors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded, color: AdminColors.danger, size: 20),
                      const SizedBox(width: 14),
                      Text(
                        lang.tr('logout', category: 'common'),
                        style: const TextStyle(
                          color: AdminColors.danger,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _onSelect(int index) {
    setState(() => _selectedIndex = index);
    // Only close the drawer on mobile, and only if it's actually open
    if (MediaQuery.of(context).size.width <= 1200) {
      final scaffold = Scaffold.maybeOf(context);
      if (scaffold != null && scaffold.isDrawerOpen) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final auth = Provider.of<AuthViewModel>(context, listen: false);
    await auth.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  Widget _buildHeader(BuildContext context, LanguageProvider lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.tr('admin_panel', category: 'admin').toUpperCase(),
                  style: TextStyle(
                    color: isDark ? Colors.white60 : AdminColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getTabTitle(lang),
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.25)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: isDark ? Colors.white70 : AdminColors.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 1,
                  height: 22,
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.08),
                ),
                const SizedBox(width: 14),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AdminColors.primary,
                  child: Text(lang.tr('super_admin', category: 'admin').substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Text(
                  lang.tr('super_admin', category: 'admin'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  onPressed: () {},
                  splashRadius: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
