import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../ViewModel/admin_view_model.dart';
import '../../../providers/language_provider.dart';
import '../admin_components.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  String _filterStatus = 'pending'; // all, pending, resolved, ignored

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final lang = context.watch<LanguageProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- Header ----------
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AdminColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.report_problem_rounded, color: AdminColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.tr('moderation_queue', category: 'admin'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: isDark ? Colors.white : AdminColors.textMain,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      lang.tr('moderation_queue_desc', category: 'admin'),
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? Colors.white70 : AdminColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ---------- Filter Bar ----------
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(lang.tr('all', category: 'admin'), 'all', isDark),
                const SizedBox(width: 10),
                _buildFilterChip(lang.tr('pending', category: 'admin'), 'pending', isDark),
                const SizedBox(width: 10),
                _buildFilterChip(lang.tr('resolved', category: 'admin'), 'resolved', isDark),
                const SizedBox(width: 10),
                _buildFilterChip(lang.tr('ignored', category: 'admin'), 'ignored', isDark),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ---------- Reports List ----------
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      lang.tr('error_loading_reports', category: 'admin'),
                      style: TextStyle(color: isDark ? Colors.white54 : AdminColors.textSecondary),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AdminColors.primary, strokeWidth: 3));
                }

                var docs = snapshot.data!.docs;

                if (_filterStatus != 'all') {
                  docs = docs.where((d) => (d.data() as Map)['status'] == _filterStatus).toList();
                }

                if (docs.isEmpty) {
                  return AdminEmptyState(
                    title: lang.tr('no_reports_title', category: 'admin'),
                    subtitle: lang.tr('no_reports_desc', category: 'admin'),
                    icon: Icons.verified_user_rounded,
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final report = docs[index].data() as Map<String, dynamic>;
                    final reportId = docs[index].id;
                    return _buildReportCard(reportId, report, vm, isDark, lang);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String status, bool isDark) {
    final isSelected = _filterStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() => _filterStatus = status),
      selectedColor: AdminColors.primary,
      backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      avatar: isSelected ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : AdminColors.textSecondary),
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Colors.transparent
              : (isDark ? Colors.white10 : Colors.black.withOpacity(0.08)),
        ),
      ),
    );
  }

  Widget _buildReportCard(String id, Map<String, dynamic> data, AdminViewModel vm, bool isDark, LanguageProvider lang) {
    final timestamp = data['timestamp'] as Timestamp?;
    final dateStr = timestamp != null ? DateFormat('MMM dd, yyyy • HH:mm').format(timestamp.toDate()) : lang.tr('recent', category: 'admin');
    final status = data['status'] ?? 'pending';
    final type = data['type'] ?? 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: AdminCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AdminStatusBadge(
                  label: type.toString().toUpperCase(),
                  color: _getTypeColor(type),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : AdminColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ID: $id',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : AdminColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 13, color: isDark ? Colors.white60 : Colors.black54),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        dateStr,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : AdminColors.textSecondary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              data['reason'] ?? lang.tr('reason_none', category: 'admin'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: isDark ? Colors.white : AdminColors.textMain,
              ),
            ),
            if (data['description'] != null) ...[
              const SizedBox(height: 8),
              Text(
                data['description'],
                style: TextStyle(
                  color: isDark ? Colors.white60 : AdminColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.03) : AdminColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Wrap(
                spacing: 48,
                runSpacing: 16,
                children: [
                  _infoBlock(lang.tr('reporter', category: 'admin').toUpperCase(), data['reporterId'] ?? lang.tr('anonymous', category: 'admin'), isDark),
                  _infoBlock(lang.tr('reported_target', category: 'admin').toUpperCase(), data['reportedId'] ?? lang.tr('unknown', category: 'admin'), isDark),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Divider(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (status == 'pending') ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AdminButton(
                        label: lang.tr('resolve', category: 'admin'),
                        icon: Icons.check_circle_rounded,
                        backgroundColor: AdminColors.success,
                        onPressed: () => vm.resolveReport(id),
                      ),
                      const SizedBox(width: 10),
                      AdminButton(
                        label: lang.tr('ignore', category: 'admin'),
                        isSecondary: true,
                        onPressed: () => vm.ignoreReport(id),
                      ),
                    ],
                  ),
                ] else
                  AdminStatusBadge(
                    label: status.toString().toUpperCase(),
                    color: status == 'resolved' ? AdminColors.success : AdminColors.textSecondary,
                  ),
                AdminButton(
                  label: lang.tr('moderate_content', category: 'admin'),
                  icon: Icons.gavel_rounded,
                  backgroundColor: AdminColors.danger.withOpacity(0.1),
                  foregroundColor: AdminColors.danger,
                  onPressed: () => _showModerationOptions(context, vm, type, data['reportedId'], lang),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBlock(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white60 : AdminColors.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
        const SizedBox(height: 4),
        SizedBox(
          width: 150,
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: isDark ? Colors.white : AdminColors.textMain,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'user': return Colors.blue;
      case 'service': return Colors.orange;
      case 'post': return Colors.purple;
      default: return Colors.grey;
    }
  }

  void _showModerationOptions(BuildContext context, AdminViewModel vm, String type, String? targetId, LanguageProvider lang) {
    if (targetId == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1F26) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Text(
                lang.tr('moderation_actions', category: 'admin'),
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : AdminColors.textMain,
                ),
              ),
              const SizedBox(height: 20),
              _moderationTile(
                icon: Icons.pause_circle_filled_rounded,
                iconColor: Colors.orange,
                title: lang.trParams('suspend_type', category: 'admin', params: {'type': type}),
                subtitle: lang.trParams('suspend_type_desc', category: 'admin', params: {'type': type}),
                isDark: isDark,
                onTap: () async {
                  if (type == 'user') {
                    await vm.updateUserStatus(targetId, isSuspended: true);
                  } else if (type == 'service') {
                    final snap = await FirebaseFirestore.instance.collection('services').doc(targetId).get();
                    if (snap.exists) {
                      final pId = snap.data()?['providerId'];
                      if (pId != null) await vm.updateUserStatus(pId, isSuspended: true);
                    }
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              _moderationTile(
                icon: Icons.block_rounded,
                iconColor: AdminColors.danger,
                title: lang.tr('permanent_ban', category: 'admin'),
                subtitle: lang.trParams('permanent_ban_desc', category: 'admin', params: {'type': type}),
                isDark: isDark,
                onTap: () async {
                  if (type == 'user') {
                    await vm.updateUserStatus(targetId, isBanned: true);
                  } else if (type == 'service') {
                    final snap = await FirebaseFirestore.instance.collection('services').doc(targetId).get();
                    if (snap.exists) {
                      final pId = snap.data()?['providerId'];
                      if (pId != null) await vm.updateUserStatus(pId, isBanned: true);
                    }
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              if (type == 'service')
                _moderationTile(
                  icon: Icons.delete_forever_rounded,
                  iconColor: AdminColors.danger,
                  title: lang.tr('remove_content', category: 'admin'),
                  subtitle: lang.tr('remove_content_desc', category: 'admin'),
                  isDark: isDark,
                  onTap: () async {
                    await vm.deleteService(targetId);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moderationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : AdminColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: isDark ? Colors.white : AdminColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white70 : AdminColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : Colors.black26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
