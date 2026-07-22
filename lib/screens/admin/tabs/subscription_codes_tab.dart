import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/UserModel.dart';
import '../../../ViewModel/admin_view_model.dart';
import '../../../utils/ui_widgets.dart';
import '../../../providers/language_provider.dart';
import '../admin_components.dart';

class SubscriptionCodesTab extends StatefulWidget {
  const SubscriptionCodesTab({super.key});

  @override
  State<SubscriptionCodesTab> createState() => _SubscriptionCodesTabState();
}

class _SubscriptionCodesTabState extends State<SubscriptionCodesTab> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<AdminViewModel>().loadMoreCodes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final vm = context.watch<AdminViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _isSelectionMode = vm.selectedCodeIds.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- Header ----------
          _buildHeader(context, vm, lang, isDark),
          const SizedBox(height: 24),

          // ---------- Statistics ----------
          _buildStats(vm, lang),
          const SizedBox(height: 24),

          // ---------- Alerts ----------
          if (vm.expiringSoonCodes.isNotEmpty) ...[
            _buildExpiringSoon(vm, lang, isDark),
            const SizedBox(height: 24),
          ],

          // ---------- Filter & Search ----------
          _buildFilters(vm, lang, isDark),
          const SizedBox(height: 16),

          // ---------- Batch Actions ----------
          if (_isSelectionMode) _buildBatchActions(vm, lang, isDark),

          // ---------- Codes List ----------
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => vm.fetchCodes(isRefresh: true),
              child: vm.paginatedCodes.isEmpty && !vm.isLoading
                  ? AdminEmptyState(
                      title: lang.tr('no_codes_found', category: 'admin'),
                      subtitle: lang.tr('no_codes_desc', category: 'admin'),
                      icon: Icons.vpn_key_outlined,
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: vm.paginatedCodes.length + (vm.isLoadingMoreCodes ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == vm.paginatedCodes.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final code = vm.paginatedCodes[index];
                        return _buildCodeCard(context, code, vm, lang, isDark);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AdminViewModel vm, LanguageProvider lang, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AdminColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.vpn_key_rounded, color: AdminColors.primary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.tr('codes_management', category: 'admin'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AdminColors.textMain,
                ),
              ),
              Text(
                lang.tr('manage_subscription_codes_desc', category: 'admin'),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : AdminColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        AdminButton(
          onPressed: () => _showGenerateDialog(context, vm, lang),
          icon: Icons.add_rounded,
          label: lang.tr('generate_new', category: 'admin'),
        ),
      ],
    );
  }

  Widget _buildStats(AdminViewModel vm, LanguageProvider lang) {
    final stats = vm.codeStats;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          SizedBox(
            width: 240,
            child: AdminStatCard(
              title: lang.tr('total_codes', category: 'admin'),
              value: stats['total'].toString(),
              icon: Icons.all_inclusive_rounded,
              color: AdminColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 240,
            child: AdminStatCard(
              title: lang.tr('active_codes', category: 'admin'),
              value: stats['active'].toString(),
              icon: Icons.check_circle_outline_rounded,
              color: AdminColors.success,
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 240,
            child: AdminStatCard(
              title: lang.tr('used_codes', category: 'admin'),
              value: stats['used'].toString(),
              icon: Icons.history_rounded,
              color: AdminColors.secondary,
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 240,
            child: AdminStatCard(
              title: lang.tr('expired_codes', category: 'admin'),
              value: stats['expired'].toString(),
              icon: Icons.timer_off_rounded,
              color: AdminColors.danger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiringSoon(AdminViewModel vm, LanguageProvider lang, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AdminColors.warning, size: 18),
            const SizedBox(width: 8),
            Text(
              lang.tr('soon_to_expire', category: 'admin'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: vm.expiringSoonCodes.length,
            itemBuilder: (context, index) {
              final code = vm.expiringSoonCodes[index];
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AdminColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminColors.warning.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Text(
                      code['code'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminColors.secondary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${_formatTimestamp(code['expiresAt'], lang)})',
                      style: const TextStyle(fontSize: 11, color: AdminColors.textSecondary),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilters(AdminViewModel vm, LanguageProvider lang, bool isDark) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: AdminTextField(
            controller: _searchController,
            hintText: lang.tr('search_codes_hint', category: 'admin'),
            prefixIcon: Icons.search_rounded,
            onChanged: (val) => vm.setCodeFilters(search: val),
          ),
        ),
        const SizedBox(width: 16),
        _buildDropdown(
          hint: lang.tr('status_filter', category: 'admin'),
          items: ['all', 'active', 'used', 'expired'],
          onChanged: (val) => vm.setCodeFilters(status: val),
          lang: lang,
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _buildDropdown(
          hint: lang.tr('sort_by', category: 'admin'),
          items: ['createdAt', 'expiresAt', 'duration'],
          onChanged: (val) => vm.setCodeFilters(sortField: val),
          lang: lang,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String hint,
    required List<String> items,
    required Function(String?) onChanged,
    required LanguageProvider lang,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: Text(hint, style: const TextStyle(fontSize: 13)),
          items: items.map((i) => DropdownMenuItem(
            value: i,
            child: Text(lang.tr(i, category: 'admin'), style: const TextStyle(fontSize: 13)),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildBatchActions(AdminViewModel vm, LanguageProvider lang, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AdminColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(
            lang.trParams('selected_count', category: 'admin', params: {'count': vm.selectedCodeIds.length.toString()}),
            style: const TextStyle(fontWeight: FontWeight.bold, color: AdminColors.primary),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: AdminColors.primary, size: 20),
            tooltip: lang.tr('copy_selected', category: 'admin'),
            onPressed: () => vm.exportSelectedToCsv().then((_) => AppSnackBar.showSuccess(context, lang.tr('copied_to_clipboard', category: 'admin'))),
          ),
          IconButton(
            icon: const Icon(Icons.block_rounded, color: AdminColors.warning, size: 20),
            tooltip: lang.tr('disable_selected', category: 'admin'),
            onPressed: () => vm.batchUpdateSelectedCodesStatus(false),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AdminColors.danger, size: 20),
            tooltip: lang.tr('delete_selected', category: 'admin'),
            onPressed: () => _confirmDelete(context, vm, lang),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => vm.clearSelection(),
            child: Text(lang.tr('clear', category: 'common')),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard(BuildContext context, Map<String, dynamic> data, AdminViewModel vm, LanguageProvider lang, bool isDark) {
    final String id = data['id'] ?? '';
    final String code = data['code'] ?? '';
    final bool isUsed = data['isUsed'] ?? false;
    final bool isEnabled = data['isEnabled'] ?? true;
    final String assignedTo = data['assignedEmail'] ?? lang.tr('no_data', category: 'common');
    final int duration = data['duration'] ?? 1;
    final Timestamp? expiresTs = data['expiresAt'] as Timestamp?;
    final DateTime? expiresAt = expiresTs?.toDate();
    final bool isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());
    
    final isSelected = vm.selectedCodeIds.contains(id);

    Color statusColor = AdminColors.success;
    String statusLabel = lang.tr('active', category: 'admin');

    if (isUsed) {
      statusColor = AdminColors.secondary;
      statusLabel = lang.tr('used', category: 'admin');
    } else if (isExpired) {
      statusColor = AdminColors.danger;
      statusLabel = lang.tr('expired', category: 'admin');
    } else if (!isEnabled) {
      statusColor = AdminColors.warning;
      statusLabel = lang.tr('disabled', category: 'admin');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AdminCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: () => _isSelectionMode ? vm.toggleCodeSelection(id) : _showCodeDetails(context, data, lang, isDark),
          onLongPress: () => vm.toggleCodeSelection(id),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: isSelected ? Border.all(color: AdminColors.primary, width: 2) : null,
              borderRadius: BorderRadius.circular(20),
              color: isSelected ? AdminColors.primary.withOpacity(0.05) : null,
            ),
            child: Row(
              children: [
                if (_isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => vm.toggleCodeSelection(id),
                    activeColor: AdminColors.primary,
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(isUsed ? Icons.history_rounded : Icons.vpn_key_rounded, color: statusColor, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SelectableText(
                            code,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 1,
                              color: isDark ? Colors.white : AdminColors.textMain,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AdminStatusBadge(label: statusLabel, color: statusColor),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.mail_outline_rounded, size: 14, color: isDark ? Colors.white54 : AdminColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              assignedTo,
                              style: TextStyle(color: isDark ? Colors.white70 : AdminColors.textSecondary, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      if (isUsed) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.person_pin_rounded, size: 14, color: AdminColors.secondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${lang.tr('used_by', category: 'admin')}: ${data['usedBy'] ?? assignedTo}',
                                style: const TextStyle(color: AdminColors.secondary, fontSize: 12, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${lang.tr('at', category: 'admin')}: ${data['usedAt'] != null ? _formatTimestamp(data['usedAt'], lang) : lang.tr('no_data', category: 'common')}',
                          style: TextStyle(color: isDark ? Colors.white38 : AdminColors.textSecondary.withOpacity(0.7), fontSize: 10),
                        ),
                      ] else ...[
                        const SizedBox(height: 2),
                        Text(
                          '${lang.trParams('code_duration', category: 'admin', params: {'months': duration.toString()})} • ${lang.tr('expires', category: 'admin')}: ${expiresAt != null ? DateFormat('MMM dd, yyyy').format(expiresAt) : 'N/A'}',
                          style: TextStyle(color: isDark ? Colors.white54 : AdminColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    AppSnackBar.showSuccess(context, lang.tr('copied', category: 'admin'));
                  },
                ),
                _buildCodeActionMenu(context, id, isEnabled, isUsed, vm, lang),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeActionMenu(BuildContext context, String id, bool isEnabled, bool isUsed, AdminViewModel vm, LanguageProvider lang) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (val) {
        if (val == 'delete') {
          vm.deleteCode(id);
        } else if (val == 'toggle') {
          vm.toggleCodeStatus(id, !isEnabled);
        }
      },
      itemBuilder: (ctx) => [
        if (!isUsed)
          PopupMenuItem(
            value: 'toggle',
            child: Row(
              children: [
                Icon(isEnabled ? Icons.block_rounded : Icons.check_circle_rounded, size: 18),
                const SizedBox(width: 8),
                Text(isEnabled ? lang.tr('disable', category: 'admin') : lang.tr('enable', category: 'admin')),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline_rounded, color: AdminColors.danger, size: 18),
              const SizedBox(width: 8),
              Text(lang.tr('delete', category: 'admin'), style: const TextStyle(color: AdminColors.danger)),
            ],
          ),
        ),
      ],
    );
  }

  void _showGenerateDialog(BuildContext context, AdminViewModel vm, LanguageProvider lang) {
    final searchCtrl = TextEditingController();
    int selectedMonths = 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    UserModel? selectedUser;
    bool isSearching = false;
    String? searchError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> performSearch() async {
            final query = searchCtrl.text.trim();
            if (query.isEmpty) return;

            setState(() {
              isSearching = true;
              searchError = null;
              selectedUser = null;
            });

            try {
              final user = await vm.findUser(query);
              if (user != null) {
                setState(() => selectedUser = user);
              } else {
                setState(() => searchError = lang.tr('no_user_found_search', category: 'admin'));
              }
            } catch (e) {
              setState(() => searchError = e.toString());
            } finally {
              setState(() => isSearching = false);
            }
          }

          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              lang.tr('generate_new_code', category: 'admin'),
              style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : AdminColors.textMain),
            ),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.tr('search_user_by_id_email', category: 'admin'),
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : AdminColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AdminTextField(
                            controller: searchCtrl,
                            hintText: lang.tr('enter_uid_or_email', category: 'admin'),
                            prefixIcon: Icons.search_rounded,
                            onSubmitted: (_) => performSearch(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isSearching ? null : performSearch,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSearching
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    if (searchError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(searchError!, style: const TextStyle(color: AdminColors.danger, fontSize: 12)),
                      ),
                    const SizedBox(height: 20),
                    if (selectedUser != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AdminColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AdminColors.primary.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lang.tr('target_user', category: 'admin'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AdminColors.primary)),
                            const SizedBox(height: 8),
                            _buildUserDetailItem(Icons.person_outline, lang.tr('name', category: 'common'), selectedUser!.name),
                            _buildUserDetailItem(Icons.email_outlined, lang.tr('email', category: 'common'), selectedUser!.email),
                            _buildUserDetailItem(Icons.fingerprint, 'UID', selectedUser!.uid),
                            _buildUserDetailItem(
                              Icons.verified_user_outlined,
                              lang.tr('status', category: 'common'),
                              selectedUser!.hasValidSubscription ? lang.tr('active', category: 'admin') : lang.tr('inactive', category: 'admin'),
                              color: selectedUser!.hasValidSubscription ? AdminColors.success : AdminColors.danger,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        lang.tr('duration', category: 'admin'),
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : AdminColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: selectedMonths,
                        dropdownColor: Theme.of(context).cardColor,
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : AdminColors.textMain),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.04) : AdminColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        items: [1, 3, 6, 12].map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(lang.trParams('months_count', category: 'admin', params: {'count': m.toString()})),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => selectedMonths = val);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(lang.tr('cancel', category: 'common')),
              ),
              AdminButton(
                label: lang.tr('generate', category: 'admin'),
                onPressed: selectedUser == null
                    ? null
                    : () async {
                        final code = await vm.generateNewCode(email: selectedUser!.email, months: selectedMonths);
                        Navigator.pop(ctx);
                        if (context.mounted) _showSuccessDialog(context, code, lang, selectedUser!.email);
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserDetailItem(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AdminColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $value',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String code, LanguageProvider lang, String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(lang.tr('code_ready', category: 'admin')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AdminColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AdminColors.primary.withOpacity(0.2)),
              ),
              child: SelectableText(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AdminColors.primary, letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              lang.trParams('linked_to', category: 'admin', params: {'email': email}),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(lang.tr('copy_and_share_desc', category: 'admin'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          AdminButton(
            label: lang.tr('copy_and_close', category: 'admin'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showCodeDetails(BuildContext context, Map<String, dynamic> data, LanguageProvider lang, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(lang.tr('code_details', category: 'admin'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                AdminStatusBadge(
                  label: (data['isUsed'] ?? false) ? lang.tr('used', category: 'admin') : lang.tr('available', category: 'admin'),
                  color: (data['isUsed'] ?? false) ? AdminColors.secondary : AdminColors.success,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow(Icons.vpn_key_outlined, lang.tr('code_value', category: 'admin'), data['code'] ?? lang.tr('no_data', category: 'common')),
            _buildDetailRow(Icons.email_outlined, lang.tr('assigned_to', category: 'admin'), data['assignedEmail'] ?? lang.tr('no_data', category: 'common')),
            _buildDetailRow(Icons.calendar_today_outlined, lang.tr('created_at', category: 'admin'), _formatTimestamp(data['createdAt'], lang)),
            _buildDetailRow(Icons.timer_outlined, lang.tr('expires_at', category: 'admin'), _formatTimestamp(data['expiresAt'], lang)),
            if (data['isUsed'] == true) ...[
              const Divider(height: 32),
              _buildDetailRow(Icons.person_outline, lang.tr('redeemed_by', category: 'admin'), (data['usedBy'] ?? data['assignedEmail'] ?? lang.tr('no_data', category: 'common')).toString()),
              _buildDetailRow(Icons.history_rounded, lang.tr('redeemed_at', category: 'admin'), _formatTimestamp(data['usedAt'], lang)),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: AdminButton(
                label: lang.tr('close', category: 'common'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AdminColors.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AdminColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic ts, LanguageProvider lang) {
    if (ts is Timestamp) {
      return DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate());
    }
    return lang.tr('no_data', category: 'common');
  }

  void _confirmDelete(BuildContext context, AdminViewModel vm, LanguageProvider lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.tr('confirm_delete', category: 'admin')),
        content: Text(lang.tr('delete_selected_warning', category: 'admin')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.tr('cancel', category: 'common'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.danger, foregroundColor: Colors.white),
            onPressed: () {
              vm.batchDeleteSelectedCodes();
              Navigator.pop(ctx);
            },
            child: Text(lang.tr('delete', category: 'admin')),
          ),
        ],
      ),
    );
  }
}
