import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/Services/subscription_service.dart';
import 'package:service_app/screens/auth/login/login_screen.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';

const Color kPrimaryBlue = Color(0xFF143EAE);
const Color kMutedTextColor = Color(0xFF475467); // Darkened for better contrast from 5A6670
const Color kLightBackgroundColor = Colors.white;
const Color kBorderColor = Color(0xFFE0E0E0);
const Color kDarkTextColor = Color(0xFF222222);
const String kAppFont = 'Roboto';

class AdminCodesPage extends StatefulWidget {
  const AdminCodesPage({super.key});

  @override
  State<AdminCodesPage> createState() => _AdminCodesPageState();
}

enum _CodeFilter { all, available, used }

enum _SortOrder { newest, oldest }

class _AdminCodesPageState extends State<AdminCodesPage>
    with SingleTickerProviderStateMixin {
  final SubscriptionService _service = SubscriptionService();
  late final TabController _tabController;

  bool _loading = false;
  List<Map<String, dynamic>> _codes = [];
  List<Map<String, dynamic>> _users = [];

  _CodeFilter _codeFilter = _CodeFilter.all;
  _SortOrder _sortOrder = _SortOrder.newest;

  final TextEditingController _codeSearchCtrl = TextEditingController();
  String _codeSearch = '';

  final TextEditingController _userSearchCtrl = TextEditingController();
  String _userSearch = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeSearchCtrl.dispose();
    _userSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    setState(() => _loading = true);
    try {
      final codes = await _service.getSubscriptionCodes();
      final users = await _service.getAllUsers();
      setState(() {
        _codes = codes;
        _users = users;
      });
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, '${lang.tr('error_occurred', category: 'common')}: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _emailForUid(String? uid) {
    if (uid == null) return null;
    for (final u in _users) {
      if (u['uid'] == uid) return u['email'] as String?;
    }
    return null;
  }

  Future<void> _openGenerateDialog() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final emailCtrl = TextEditingController();
    int months = 1;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                lang.tr('generate_user_code', category: 'admin'),
                style: const TextStyle(
                    fontFamily: kAppFont, fontWeight: FontWeight.w600),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lang.tr('user_email_required', category: 'admin'),
                      style: const TextStyle(fontSize: 13, color: kMutedTextColor)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: lang.tr('user_email_placeholder', category: 'admin'),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(lang.tr('duration', category: 'admin'),
                      style: const TextStyle(fontSize: 13, color: kMutedTextColor)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: months,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [1, 2, 3, 6, 12]
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m == 12 ? lang.tr('one_year', category: 'admin') : lang.trParams('month_plural', category: 'admin', params: {'count': m.toString()})),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => months = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(lang.tr('cancel', category: 'common')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(dialogContext, {
                    'email': emailCtrl.text.trim(),
                    'months': months,
                  }),
                  child: Text(lang.tr('generate', category: 'admin')),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;
    final email = (result['email'] as String).trim();
    final selectedMonths = result['months'] as int;
    if (email.isEmpty) {
      AppSnackBar.showError(context, lang.tr('email_required_error', category: 'admin'));
      return;
    }
    await _generate(email: email, months: selectedMonths);
  }

  Future<void> _generate({required String email, required int months}) async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    setState(() => _loading = true);
    try {
      final user = await _service.findUserByEmail(email);
      if (user == null) {
        AppSnackBar.showError(context, lang.trParams('no_user_found_email', category: 'admin', params: {'email': email}));
        setState(() => _loading = false);
        return;
      }

      final code = await _service.generateSubscriptionCode(
        months: months,
        assignedUserId: user['uid'],
      );

      await _loadAll();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(lang.tr('code_generated', category: 'admin'),
              style: const TextStyle(
                  fontFamily: kAppFont, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(code,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryBlue)),
              const SizedBox(height: 8),
              Text(
                lang.trParams('linked_to', category: 'admin', params: {'email': email}),
                style: const TextStyle(color: kMutedTextColor, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                AppSnackBar.showSuccess(context, lang.tr('code_copied', category: 'admin'));
              },
              child: Text(lang.tr('copy', category: 'admin')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lang.tr('close', category: 'search')),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, '${lang.tr('operation_failed', category: 'admin')}: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteCode(String code) async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(lang.tr('delete_code_title', category: 'admin')),
        content: Text(lang.trParams('delete_code_msg', category: 'admin', params: {'code': code})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(lang.tr('cancel', category: 'common')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(lang.tr('delete', category: 'common')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.deleteCode(code);
      await _loadAll();
      if (mounted) {
        AppSnackBar.showSuccess(context, lang.tr('code_deleted', category: 'admin'));
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, '${lang.tr('operation_failed', category: 'admin')}: $e');
      }
    }
  }

  void _exportCodes() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final buffer = StringBuffer();
    buffer.writeln('Code,AssignedUID,Duration(Months),Expiry,Status');
    for (final c in _filteredCodes) {
      final code = c['code'] ?? '';
      final uid = c['assignedUserId'] ?? '';
      final duration = c['duration'] ?? '';
      final expiresAt = c['expiresAt'] != null
          ? (c['expiresAt'] as Timestamp).toDate().toString().split(' ')[0]
          : '';
      final used = (c['isUsed'] ?? false) ? lang.tr('status_used', category: 'admin') : lang.tr('available', category: 'admin');
      buffer.writeln('$code,$uid,$duration,$expiresAt,$used');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    AppSnackBar.showSuccess(context, lang.tr('codes_exported', category: 'admin'));
  }

  void _showCodeDetail(Map<String, dynamic> codeData) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final String code = codeData['code'] ?? '';
    final bool used = codeData['isUsed'] ?? false;
    final expiresAtTs = codeData['expiresAt'];
    final int? duration = codeData['duration'] as int?;
    final assignedUserId = codeData['assignedUserId'] as String?;
    final createdAtTs = codeData['createdAt'];
    final linkedEmail = _emailForUid(assignedUserId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(code,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryBlue,
                          letterSpacing: 1)),
                ),
                _statusChip(used, lang),
              ],
            ),
            const Divider(height: 24),
            _detailRow(Icons.person_outline, lang.tr('assigned_to', category: 'admin'),
                linkedEmail ?? assignedUserId ?? lang.tr('unknown', category: 'admin')),
            _detailRow(
                Icons.calendar_today_outlined,
                lang.tr('created', category: 'bookings'), // Reuse 'created' key
                createdAtTs != null
                    ? (createdAtTs as Timestamp).toDate().toString().split(' ')[0]
                    : '-'),
            _detailRow(
                Icons.timer_outlined,
                lang.tr('duration', category: 'admin'),
                duration != null
                    ? lang.trParams('month_plural', category: 'admin', params: {'count': duration.toString()})
                    : '-'),
            _detailRow(
                Icons.event_outlined,
                lang.tr('expires', category: 'search'),
                expiresAtTs != null
                    ? (expiresAtTs as Timestamp).toDate().toString().split(' ')[0]
                    : lang.tr('no_expiration', category: 'admin')),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      AppSnackBar.showSuccess(context, lang.tr('code_copied', category: 'admin'));
                    },
                    icon: const Icon(Icons.copy, color: kPrimaryBlue),
                    label: Text(lang.tr('copy', category: 'admin'),
                        style: const TextStyle(color: kPrimaryBlue)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kPrimaryBlue),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteCode(code);
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                    label: Text(lang.tr('delete', category: 'common'),
                        style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: kMutedTextColor),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(color: kMutedTextColor, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: kDarkTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredCodes {
    List<Map<String, dynamic>> result;

    switch (_codeFilter) {
      case _CodeFilter.available:
        result = _codes.where((c) => (c['isUsed'] ?? false) == false).toList();
        break;
      case _CodeFilter.used:
        result = _codes.where((c) => (c['isUsed'] ?? false) == true).toList();
        break;
      case _CodeFilter.all:
      default:
        result = List.from(_codes);
    }

    if (_codeSearch.isNotEmpty) {
      final q = _codeSearch.toLowerCase();
      result = result.where((c) {
        final code = (c['code'] ?? '').toString().toLowerCase();
        final assignedUserId = (c['assignedUserId'] ?? '').toString().toLowerCase();
        final emailFromUid = (_emailForUid(c['assignedUserId']) ?? '').toLowerCase();
        return code.contains(q) || assignedUserId.contains(q) || emailFromUid.contains(q);
      }).toList();
    }

    result.sort((a, b) {
      final aDate = a['createdAt'];
      final bDate = b['createdAt'];
      if (aDate == null || bDate == null) return 0;
      final cmp = (aDate as Timestamp).toDate().compareTo((bDate as Timestamp).toDate());
      return _sortOrder == _SortOrder.newest ? -cmp : cmp;
    });

    return result;
  }

  List<Map<String, dynamic>> get _historyEntries {
    return _codes.where((c) => (c['isUsed'] ?? false) == true).toList()
      ..sort((a, b) {
        final aDate = a['usedAt'];
        final bDate = b['usedAt'];
        if (aDate == null || bDate == null) return 0;
        return (bDate as Timestamp).toDate().compareTo((aDate as Timestamp).toDate());
      });
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_userSearch.isEmpty) return _users;
    final q = _userSearch.toLowerCase();
    return _users.where((u) {
      final email = (u['email'] ?? '').toString().toLowerCase();
      final name = (u['name'] ?? '').toString().toLowerCase();
      final role = (u['role'] ?? '').toString().toLowerCase();
      return email.contains(q) || name.contains(q) || role.contains(q);
    }).toList();
  }

  int get usedCount => _codes.where((e) => (e['isUsed'] ?? false) == true).length;
  int get availableCount =>
      _codes.where((e) => (e['isUsed'] ?? false) == false).length;

  int get activeSubscriptionsCount => _users.where((u) {
        final active = u['subscriptionActive'] ?? false;
        if (active != true) return false;
        final expiry = u['subscriptionExpiresAt'] ?? u['subscriptionExpiry'];
        if (expiry == null) return true;
        try {
          return (expiry as Timestamp).toDate().isAfter(DateTime.now());
        } catch (_) {
          return true;
        }
      }).length;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final lang = context.watch<LanguageProvider>();
    final user = auth.currentUser;

    if (user == null || !user.isAdmin) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: kDarkTextColor),
          title: Text(lang.tr('unauthorized', category: 'admin'),
              style: const TextStyle(
                  color: kDarkTextColor,
                  fontWeight: FontWeight.w600,
                  fontFamily: kAppFont)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(lang.tr('not_authorized_msg', category: 'admin'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: kMutedTextColor)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: kDarkTextColor),
        title: Text(lang.tr('admin_subscriptions', category: 'admin'),
            style: const TextStyle(
                color: kDarkTextColor,
                fontWeight: FontWeight.w600,
                fontFamily: kAppFont)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: kPrimaryBlue,
          unselectedLabelColor: kMutedTextColor,
          indicatorColor: kPrimaryBlue,
          tabs: [
            Tab(text: lang.tr('codes', category: 'admin')),
            Tab(text: lang.tr('history', category: 'admin')),
            Tab(text: lang.tr('users', category: 'admin')),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kPrimaryBlue),
            tooltip: lang.tr('refresh', category: 'admin'),
            onPressed: _loading ? null : _loadAll,
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: kPrimaryBlue,
              onPressed: _loading ? null : _openGenerateDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(lang.tr('generate', category: 'admin'),
                  style: const TextStyle(color: Colors.white, fontFamily: kAppFont)),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryBlue))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCodesTab(lang),
                _buildHistoryTab(lang),
                _buildUsersTab(lang),
              ],
            ),
    );
  }

  Widget _buildCodesTab(LanguageProvider lang) {
    final codes = _filteredCodes;

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: kPrimaryBlue,
      child: Column(
        children: [
          _buildStatsHeader(lang),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeSearchCtrl,
                    onChanged: (v) => setState(() => _codeSearch = v),
                    decoration: InputDecoration(
                      hintText: lang.tr('search_uid_code', category: 'admin'),
                      prefixIcon:
                          const Icon(Icons.search, color: kMutedTextColor),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kBorderColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<_SortOrder>(
                  tooltip: lang.tr('sort_tooltip', category: 'common'), // Use common sort key if exists
                  icon: const Icon(Icons.sort, color: kPrimaryBlue),
                  onSelected: (v) => setState(() => _sortOrder = v),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: _SortOrder.newest, child: Text(lang.tr('newest_first', category: 'admin'))),
                    PopupMenuItem(value: _SortOrder.oldest, child: Text(lang.tr('oldest_first', category: 'admin'))),
                  ],
                ),
              ],
            ),
          ),
          _buildCodeFilterChips(lang),
          Expanded(
            child: codes.isEmpty
                ? Center(child: Text(lang.tr('no_codes_found', category: 'admin')))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    itemCount: codes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildCodeCard(codes[index], lang),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(LanguageProvider lang) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kPrimaryBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(title: lang.tr('total', category: 'admin'), value: _codes.length.toString()),
          _statItem(title: lang.tr('used', category: 'admin'), value: usedCount.toString()),
          _statItem(title: lang.tr('available', category: 'admin'), value: availableCount.toString()),
          _statItem(
              title: lang.tr('active_subs', category: 'admin'), value: activeSubscriptionsCount.toString()),
        ],
      ),
    );
  }

  Widget _buildCodeFilterChips(LanguageProvider lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _filterChip(lang.tr('all', category: 'admin'), _CodeFilter.all),
          const SizedBox(width: 8),
          _filterChip(lang.tr('available', category: 'admin'), _CodeFilter.available),
          const SizedBox(width: 8),
          _filterChip(lang.tr('used', category: 'admin'), _CodeFilter.used),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _CodeFilter value) {
    final selected = _codeFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _codeFilter = value),
    );
  }

  Widget _statItem({required String title, required String value}) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildCodeCard(Map<String, dynamic> codeData, LanguageProvider lang) {
    final bool used = codeData['isUsed'] ?? false;
    final String code = codeData['code'] ?? '';
    final String assignedTo = codeData['assignedUserId'] ?? '';
    final expiresAtTs = codeData['expiresAt'];

    return GestureDetector(
      onTap: () => _showCodeDetail(codeData),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SelectableText(code,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: kDarkTextColor,
                            letterSpacing: 1)),
                  ),
                  _statusChip(used, lang),
                ],
              ),
              const SizedBox(height: 8),
              Text('${lang.tr('assigned_to', category: 'admin')}: ${_emailForUid(assignedTo) ?? assignedTo}',
                  style: const TextStyle(color: kMutedTextColor, fontSize: 13)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lang.tr('duration', category: 'admin'), style: const TextStyle(color: kMutedTextColor, fontSize: 12)),
                        Text(lang.trParams('month_plural', category: 'admin', params: {'count': codeData['duration'].toString()}), style: const TextStyle(color: kDarkTextColor, fontSize: 14)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lang.tr('expires', category: 'search'), style: const TextStyle(color: kMutedTextColor, fontSize: 12)),
                        Text(expiresAtTs != null ? (expiresAtTs as Timestamp).toDate().toString().split(' ')[0] : lang.tr('no_expiration', category: 'admin'), style: const TextStyle(color: kDarkTextColor, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(bool used, LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: used ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        used ? lang.tr('status_used', category: 'admin') : lang.tr('available', category: 'admin'),
        style: TextStyle(
            color: used ? Colors.red : Colors.green,
            fontWeight: FontWeight.w600,
            fontSize: 12),
      ),
    );
  }

  Widget _buildHistoryTab(LanguageProvider lang) {
    final history = _historyEntries;
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: history.isEmpty
          ? Center(child: Text(lang.tr('no_redemption_history', category: 'admin')))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _buildHistoryCard(history[index], lang),
            ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> c, LanguageProvider lang) {
    final String code = c['code'] ?? '';
    final String assignedTo = c['assignedUserId'] ?? '';
    final usedAtTs = c['usedAt'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: ListTile(
        leading: const Icon(Icons.history, color: kPrimaryBlue),
        title: Text(code, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${lang.tr('used_by', category: 'admin')}: ${_emailForUid(assignedTo) ?? assignedTo}\n${lang.tr('at', category: 'admin')}: ${usedAtTs != null ? (usedAtTs as Timestamp).toDate().toString() : "-"}'),
      ),
    );
  }

  Widget _buildUsersTab(LanguageProvider lang) {
    final users = _filteredUsers;
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _userSearch = v),
              decoration: InputDecoration(hintText: lang.tr('search_users', category: 'admin')),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _buildUserCard(users[index], lang),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> u, LanguageProvider lang) {
    final email = (u['email'] ?? '') as String;
    return Card(
      child: ListTile(
        title: Text(u['name'] ?? email),
        subtitle: Text(email),
        trailing: IconButton(
          icon: const Icon(Icons.qr_code),
          onPressed: () => _quickGenerateForUser(email, lang),
        ),
      ),
    );
  }

  Future<void> _quickGenerateForUser(String email, LanguageProvider lang) async {
    int months = 1;
    final selectedMonths = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: Text(lang.trParams('generate_for', category: 'admin', params: {'email': email})),
        content: DropdownButton<int>(
          value: months,
          items: [1, 2, 3, 6, 12].map((m) => DropdownMenuItem(value: m, child: Text(lang.trParams('month_plural', category: 'admin', params: {'count': m.toString()})) )).toList(),
          onChanged: (v) => setS(() => months = v!),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.tr('cancel', category: 'common'))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, months), child: Text(lang.tr('generate', category: 'admin'))),
        ],
      )),
    );
    if (selectedMonths != null) await _generate(email: email, months: selectedMonths);
  }
}
