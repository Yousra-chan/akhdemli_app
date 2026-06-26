import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../ViewModel/admin_view_model.dart';
import '../../../providers/language_provider.dart';
import '../../../utils/ui_widgets.dart';
import '../admin_components.dart';

class DashboardOverview extends StatelessWidget {
  final ValueChanged<int>? onNavigate;
  const DashboardOverview({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminViewModel>();
    final lang = context.watch<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (vm.isLoading) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonLoader(width: 200, height: 30),
            const SizedBox(height: 8),
            SkeletonLoader(width: 150, height: 16),
            const SizedBox(height: 36),
            SkeletonLoader(width: 300, height: 100, borderRadius: 22),
            const SizedBox(height: 44),
            SkeletonLoader(width: 180, height: 20),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 2.9,
              children: List.generate(4, (index) => SkeletonLoader(borderRadius: 18)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => vm.init(),
      color: AdminColors.primary,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- Page Header ----------
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdminColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.dashboard_rounded,
                    color: AdminColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.tr('dashboard_overview', category: 'admin'),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : AdminColors.textMain,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lang.tr('dashboard_welcome', category: 'admin'),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 36),

            // ---------- Statistics ----------
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth > 480
                    ? 320.0
                    : constraints.maxWidth;
                return _StatCard(
                  width: cardWidth,
                  title: lang.tr('total_platform_users', category: 'admin'),
                  value: vm.totalUsers.toString(),
                  icon: Icons.people_alt_rounded,
                  color: AdminColors.primary,
                  isDark: isDark,
                );
              },
            ),

            const SizedBox(height: 44),

            // ---------- Quick Actions ----------
            Row(
              children: [
                Flexible(
                  child: Text(
                    lang.tr('quick_management_actions', category: 'admin'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : AdminColors.textMain,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Divider(
                    color: isDark ? Colors.white12 : Colors.black12,
                    thickness: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount =
                width > 1200 ? 4 : (width > 800 ? 2 : 1);
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 2.9,
                  children: [
                    _QuickActionTile(
                      icon: Icons.vpn_key_rounded,
                      label: lang.tr('generate_sub_code', category: 'admin'),
                      color: AdminColors.primary,
                      isDark: isDark,
                      onTap: () => onNavigate?.call(5),
                    ),
                    _QuickActionTile(
                      icon: Icons.category_rounded,
                      label: lang.tr('manage_categories', category: 'admin'),
                      color: AdminColors.success,
                      isDark: isDark,
                      onTap: () => onNavigate?.call(4),
                    ),
                    _QuickActionTile(
                      icon: Icons.miscellaneous_services_rounded,
                      label: lang.tr('moderate_services', category: 'admin'),
                      color: AdminColors.warning,
                      isDark: isDark,
                      onTap: () => onNavigate?.call(2),
                    ),
                    _QuickActionTile(
                      icon: Icons.person_search_rounded,
                      label: lang.tr('manage_users', category: 'admin'),
                      color: Colors.purple,
                      isDark: isDark,
                      onTap: () => onNavigate?.call(1),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------- Stat Card ----------------
class _StatCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1F26) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withOpacity(0.18), color.withOpacity(0.06)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : AdminColors.textMain,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------- Quick Action Tile ----------------
class _QuickActionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final isDark = widget.isDark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..scale(_hovering ? 1.015 : 1.0),
        decoration: BoxDecoration(
          color: isDark
              ? (_hovering ? color.withOpacity(0.14) : const Color(0xFF1C1F26))
              : (_hovering ? color.withOpacity(0.08) : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hovering
                ? color.withOpacity(0.35)
                : (isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.25)
                  : Colors.black.withOpacity(0.03),
              blurRadius: _hovering ? 16 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: isDark ? Colors.white : color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        letterSpacing: -0.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
