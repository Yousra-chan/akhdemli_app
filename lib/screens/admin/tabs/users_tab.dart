import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../ViewModel/admin_view_model.dart';
import '../../../models/UserModel.dart';
import '../../../providers/language_provider.dart';
import '../../../utils/image_utils.dart';
import '../admin_components.dart';

class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  String _searchQuery = '';
  String _roleFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminViewModel>();
    final lang = context.watch<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                child: const Icon(Icons.people_rounded, color: AdminColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.tr('manage_users', category: 'admin'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: isDark ? Colors.white : AdminColors.textMain,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      lang.tr('manage_users_desc', category: 'admin'),
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

          // ---------- Top Action Bar ----------
          Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 400,
                child: AdminTextField(
                  hintText: lang.tr('search_hint', category: 'admin'),
                  prefixIcon: Icons.search_rounded,
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              _buildRoleFilter(lang, isDark),
              AdminButton(
                label: lang.tr('export_csv', category: 'admin'),
                icon: Icons.download_rounded,
                isSecondary: true,
                onPressed: () => _exportUsersAsCSV(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ---------- User Table Card ----------
          Expanded(
            child: AdminCard(
              padding: EdgeInsets.zero,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        lang.tr('something_went_wrong', category: 'common'),
                        style: TextStyle(color: isDark ? Colors.white54 : AdminColors.textSecondary),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AdminColors.primary, strokeWidth: 3));
                  }

                  final docs = snapshot.data!.docs;
                  final users = docs.map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>, d.id))
                      .where((u) {
                    bool matchesSearch = u.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        u.email.toLowerCase().contains(_searchQuery.toLowerCase());
                    bool matchesRole = _roleFilter == 'all' || u.role == _roleFilter;
                    return matchesSearch && matchesRole;
                  })
                      .toList();

                  if (users.isEmpty) {
                    return AdminEmptyState(
                      title: lang.tr('no_data_found', category: 'admin'),
                      subtitle: lang.tr('search_hint', category: 'admin'),
                      icon: Icons.person_off_rounded,
                    );
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                          child: Text(
                            '${users.length} ${lang.tr('users', category: 'admin')}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AdminColors.textMain,
                            ),
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 340),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                dividerTheme: DividerThemeData(
                                  thickness: 0.6,
                                  space: 0,
                                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                                ),
                              ),
                              child: DataTable(
                                headingRowHeight: 52,
                                dataRowMinHeight: 70,
                                dataRowMaxHeight: 80,
                                horizontalMargin: 24,
                                columnSpacing: 32,
                                headingRowColor: WidgetStateProperty.all(
                                  isDark ? Colors.white.withOpacity(0.02) : AdminColors.background,
                                ),
                                columns: [
                                  DataColumn(label: _headerLabel(lang.tr('users', category: 'admin'), isDark)),
                                  DataColumn(label: _headerLabel(lang.tr('email', category: 'common'), isDark)),
                                  DataColumn(label: _headerLabel(lang.tr('myRole', category: 'common'), isDark)),
                                  DataColumn(label: _headerLabel(lang.tr('status', category: 'admin'), isDark)),
                                  DataColumn(label: _headerLabel(lang.tr('actions', category: 'admin'), isDark)),
                                ],
                                rows: users.map((u) => _buildUserRow(u, context, vm, lang, isDark)).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerLabel(String text, bool isDark) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: isDark ? Colors.white60 : AdminColors.textSecondary,
      ),
    );
  }

  Widget _buildRoleFilter(LanguageProvider lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 52,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.08),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _roleFilter,
          dropdownColor: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white54 : Colors.black54),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AdminColors.textMain,
          ),
          items: [
            DropdownMenuItem(value: 'all', child: Text(lang.tr('all_roles', category: 'admin'))),
            DropdownMenuItem(value: 'client', child: Text(lang.tr('clients', category: 'admin'))),
            DropdownMenuItem(value: 'provider', child: Text(lang.tr('providers', category: 'admin'))),
            DropdownMenuItem(value: 'admin', child: Text(lang.tr('admins', category: 'admin'))),
          ],
          onChanged: (v) => setState(() => _roleFilter = v!),
        ),
      ),
    );
  }

  DataRow _buildUserRow(UserModel user, BuildContext context, AdminViewModel vm, LanguageProvider lang, bool isDark) {
    return DataRow(cells: [
      DataCell(
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AdminColors.primary.withOpacity(0.1),
              backgroundImage: user.photoUrl.isNotEmpty && ImageUtils.isNetworkImage(user.photoUrl) 
                  ? NetworkImage(user.photoUrl) 
                  : (user.photoUrl.isNotEmpty && ImageUtils.isBase64Image(user.photoUrl) 
                      ? MemoryImage(ImageUtils.decodeBase64Image(user.photoUrl)!) as ImageProvider
                      : null),
              child: (user.photoUrl.isEmpty && user.name.isNotEmpty)
                  ? Text(user.name[0].toUpperCase(), style: const TextStyle(color: AdminColors.primary, fontWeight: FontWeight.bold))
                  : (user.name.isEmpty ? const Icon(Icons.person, color: AdminColors.primary) : null),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name.isEmpty ? lang.tr('no_name', category: 'admin') : user.name,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: isDark ? Colors.white : AdminColors.textMain),
                ),
                const SizedBox(height: 2),
                Text(
                  '${lang.tr('id_prefix', category: 'admin')}${user.uid.length > 8 ? user.uid.substring(0, 8) : user.uid}',
                  style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white60 : AdminColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
      DataCell(Text(
        user.email.isEmpty ? lang.tr('no_email', category: 'admin') : user.email,
        style: TextStyle(color: isDark ? Colors.white70 : AdminColors.textSecondary, fontSize: 13),
      )),
      DataCell(
        AdminStatusBadge(
          label: user.role.toUpperCase(),
          color: user.role == 'provider' ? Colors.purple : (user.role == 'admin' ? Colors.red : Colors.blue),
        ),
      ),
      DataCell(
        AdminStatusBadge(
          label: user.isBanned ? lang.tr('status_banned', category: 'admin').toUpperCase() : (user.isSuspended ? lang.tr('status_suspended', category: 'admin').toUpperCase() : lang.tr('status_active', category: 'admin').toUpperCase()),
          color: user.isBanned ? Colors.black : (user.isSuspended ? AdminColors.danger : AdminColors.success),
        ),
      ),
      DataCell(
        PopupMenuButton<String>(
          onSelected: (val) => _handleUserAction(val, user, vm),
          icon: Icon(Icons.more_horiz_rounded, color: isDark ? Colors.white54 : AdminColors.textSecondary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Theme.of(context).cardColor,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'role',
              child: Row(children: [
                Icon(Icons.admin_panel_settings_outlined, size: 19, color: isDark ? Colors.white70 : AdminColors.textMain),
                const SizedBox(width: 10),
                Text(user.role == 'admin' ? lang.tr('revoke_admin', category: 'admin') : lang.tr('make_admin', category: 'admin'), style: TextStyle(color: isDark ? Colors.white : AdminColors.textMain)),
              ]),
            ),
            PopupMenuItem(
              value: 'suspend',
              child: Row(children: [
                Icon(user.isSuspended ? Icons.play_arrow_outlined : Icons.pause_circle_outline, size: 19, color: isDark ? Colors.white70 : AdminColors.textMain),
                const SizedBox(width: 10),
                Text(user.isSuspended ? lang.tr('activate', category: 'admin') : lang.tr('suspend', category: 'admin'), style: TextStyle(color: isDark ? Colors.white : AdminColors.textMain)),
              ]),
            ),
            PopupMenuItem(
              value: 'ban',
              child: Row(children: [
                Icon(user.isBanned ? Icons.security_outlined : Icons.gavel_rounded, size: 19, color: isDark ? Colors.white70 : AdminColors.textMain),
                const SizedBox(width: 10),
                Text(user.isBanned ? lang.tr('unban', category: 'admin') : lang.tr('ban_user', category: 'admin'), style: TextStyle(color: isDark ? Colors.white : AdminColors.textMain)),
              ]),
            ),
            const PopupMenuDivider(height: 8),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                const Icon(Icons.delete_outline, color: Colors.red, size: 19),
                const SizedBox(width: 10),
                Text(lang.tr('delete_permanent', category: 'admin'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ),
      ),
    ]);
  }

  Future<void> _handleUserAction(String action, UserModel user, AdminViewModel vm) async {
    try {
      switch (action) {
        case 'suspend':
          await vm.updateUserStatus(user.uid, isSuspended: !user.isSuspended);
          break;
        case 'ban':
          await vm.updateUserStatus(user.uid, isBanned: !user.isBanned);
          break;
        case 'role':
          final String nextRole = user.role == 'admin' ? 'client' : 'admin';
          await vm.updateUserStatus(user.uid, role: nextRole);
          break;
        case 'delete':
          _showDeleteConfirm(user, vm);
          return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<LanguageProvider>().tr('save_success', category: 'admin')),
            backgroundColor: AdminColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<LanguageProvider>().tr('operation_failed', category: 'admin')),
            backgroundColor: AdminColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDeleteConfirm(UserModel user, AdminViewModel vm) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AdminColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_rounded, color: AdminColors.danger, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                lang.tr('delete_user', category: 'admin'),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: isDark ? Colors.white : AdminColors.textMain),
              ),
            ),
          ],
        ),
        content: Text(
          '${lang.trParams('delete_confirm_msg_type', category: 'admin', params: {'type': lang.tr('users', category: 'admin').substring(0, lang.tr('users', category: 'admin').length - 1)})} (${user.name})',
          style: TextStyle(color: isDark ? Colors.white60 : AdminColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.tr('cancel', category: 'common'), style: TextStyle(color: isDark ? Colors.white60 : AdminColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          AdminButton(
            label: lang.tr('delete', category: 'common'),
            backgroundColor: AdminColors.danger,
            onPressed: () {
              vm.deleteUser(user.uid);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _exportUsersAsCSV(BuildContext context) async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final users = snapshot.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList();

      String csv = '${lang.tr('csv_name', category: 'admin')},${lang.tr('csv_email', category: 'admin')},${lang.tr('csv_phone', category: 'admin')},${lang.tr('csv_role', category: 'admin')},${lang.tr('csv_status', category: 'admin')},${lang.tr('csv_date', category: 'admin')}\n';
      for (var u in users) {
        final status = u.isBanned ? lang.tr('status_banned', category: 'admin') : (u.isSuspended ? lang.tr('status_suspended', category: 'admin') : lang.tr('status_active', category: 'admin'));
        final date = u.createdAt.toDate().toString();
        csv += '"${u.name}","${u.email}","${u.phone}","${u.role}","$status","$date"\n';
      }

      final encodedCsv = Uri.encodeComponent(csv);
      final url = 'data:text/csv;charset=utf-8,$encodedCsv';

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await Clipboard.setData(ClipboardData(text: csv));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(lang.tr('csv_clipboard', category: 'admin')))
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${lang.tr('export_failed', category: 'admin')}: $e'))
        );
      }
    }
  }
}
