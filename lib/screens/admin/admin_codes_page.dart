import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    Map<String, dynamic>? selectedUser;
    List<Map<String, dynamic>> searchResults = [];

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            void updateSearch(String query) {
              if (query.isEmpty) {
                setDialogState(() => searchResults = []);
                return;
              }
              final q = query.toLowerCase();
              setDialogState(() {
                searchResults = _users.where((u) {
                  final email = (u['email'] ?? '').toString().toLowerCase();
                  final name = (u['name'] ?? '').toString().toLowerCase();
                  return email.contains(q) || name.contains(q);
                }).take(5).toList();
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.vpn_key_outlined, color: kPrimaryBlue),
                  const SizedBox(width: 10),
                  Text(lang.tr('generate_user_code', category: 'admin')),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lang.tr('search_users', category: 'admin'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kMutedTextColor)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: emailCtrl,
                        onChanged: updateSearch,
                        decoration: InputDecoration(
                          hintText: lang.tr('user_email_placeholder', category: 'admin'),
                          prefixIcon: const Icon(Icons.person_search_outlined),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      if (searchResults.isNotEmpty && selectedUser == null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                          ),
                          child: Column(
                            children: searchResults.map((u) => ListTile(
                              dense: true,
                              title: Text(u['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(u['email'] ?? ''),
                              onTap: () {
                                setDialogState(() {
                                  selectedUser = u;
                                  emailCtrl.text = u['email'];
                                  searchResults = [];
                                });
                              },
                            )).toList(),
                          ),
                        ),
                      if (selectedUser != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Chip(
                            avatar: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                            label: Text(selectedUser!['name'] ?? selectedUser!['email']),
                            onDeleted: () => setDialogState(() {
                              selectedUser = null;
                              emailCtrl.clear();
                            }),
                          ),
                        ),
                      const SizedBox(height: 20),
                      Text(lang.tr('duration', category: 'admin'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kMutedTextColor)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [1, 3, 6, 12].map((m) {
                          final isSel = months == m;
                          return ChoiceChip(
                            label: Text(m == 12 ? '1 ${lang.tr('year', category: 'admin')}' : '$m ${lang.tr('months', category: 'admin')}'),
                            selected: isSel,
                            selectedColor: kPrimaryBlue.withOpacity(0.2),
                            onSelected: (s) => setDialogState(() => months = m),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: selectedUser == null && emailCtrl.text.isEmpty
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          _generate(email: emailCtrl.text.trim(), months: months);
                        },
                  child: Text(lang.tr('generate', category: 'admin')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generate({required String email, required int months}) async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    setState(() => _loading = true);
    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final code = await _service.generateSubscriptionCode(
        months: months,
        assignedEmail: email.toLowerCase().trim(),
        createdByAdminId: adminId,
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
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      await _service.deleteCode(code, adminId);
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

  Future<void> _deleteAllCodes(bool onlyUsed) async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(onlyUsed ? lang.tr('delete_used_codes', category: 'admin') : lang.tr('delete_all_codes', category: 'admin')),
        content: Text(onlyUsed ? lang.tr('confirm_delete_used', category: 'admin') : lang.tr('confirm_delete_all', category: 'admin')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(lang.tr('cancel', category: 'common'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(lang.tr('delete', category: 'common')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await _service.deleteAllCodes(onlyUsed: onlyUsed);
      await _loadAll();
      if (mounted) AppSnackBar.showSuccess(context, lang.tr('codes_deleted_success', category: 'admin'));
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, '${lang.tr('operation_failed', category: 'admin')}: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _exportCodes() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final buffer = StringBuffer();
    buffer.writeln('Code,AssignedEmail,Duration(Months),Expiry,Status');
    for (final c in _filteredCodes) {
      final code = c['code'] ?? '';
      final email = c['assignedEmail'] ?? '';
      final duration = c['duration'] ?? '';
      final expiresAt = c['expiresAt'] != null
          ? (c['expiresAt'] as Timestamp).toDate().toString().split(' ')[0]
          : '';
      final used = (c['isUsed'] ?? false) ? lang.tr('status_used', category: 'admin') : lang.tr('available', category: 'admin');
      buffer.writeln('$code,$email,$duration,$expiresAt,$used');
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
    final assignedEmail = codeData['assignedEmail'] as String?;
    final createdAtTs = codeData['createdAt'];

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
                assignedEmail ?? lang.tr('unknown', category: 'admin')),
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
        final assignedEmail = (c['assignedEmail'] ?? '').toString().toLowerCase();
        return code.contains(q) || assignedEmail.contains(q);
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: kPrimaryBlue),
            onSelected: (val) {
              if (val == 'delete_all') _deleteAllCodes(false);
              if (val == 'delete_used') _deleteAllCodes(true);
              if (val == 'export') _exportCodes();
              if (val == 'refresh') _loadAll();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    const Icon(Icons.refresh, size: 20, color: kPrimaryBlue),
                    const SizedBox(width: 10),
                    Text(lang.tr('refresh', category: 'admin')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    const Icon(Icons.content_copy, size: 20, color: kPrimaryBlue),
                    const SizedBox(width: 10),
                    Text(lang.tr('export', category: 'admin')),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete_used',
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep_outlined, size: 20, color: Colors.orange),
                    const SizedBox(width: 10),
                    Text(lang.tr('delete_used_codes', category: 'admin')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    const Icon(Icons.delete_forever, size: 20, color: Colors.red),
                    const SizedBox(width: 10),
                    Text(lang.tr('delete_all_codes', category: 'admin')),
                  ],
                ),
              ),
            ],
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
    final String assignedTo = codeData['assignedEmail'] ?? '';
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
              Text('${lang.tr('assigned_to', category: 'admin')}: $assignedTo',
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
    final String assignedTo = c['assignedEmail'] ?? '';
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
        subtitle: Text('${lang.tr('used_by', category: 'admin')}: $assignedTo\n${lang.tr('at', category: 'admin')}: ${usedAtTs != null ? (usedAtTs as Timestamp).toDate().toString() : "-"}'),
      ),
    );
  }

  Widget _buildUsersTab(LanguageProvider lang) {
    final users = _filteredUsers;
    return RefreshIndicator(
      onRefresh: _loadAll,
      color: kPrimaryBlue,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _userSearch = v),
              decoration: InputDecoration(
                hintText: lang.tr('search_users', category: 'admin'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorderColor),
                ),
              ),
            ),
          ),
          Expanded(
            child: users.isEmpty
                ? Center(child: Text(lang.tr('no_users_found', category: 'admin')))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
    final name = (u['name'] ?? 'User') as String;
    final isActive = u['subscriptionActive'] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: kPrimaryBlue.withOpacity(0.1),
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(color: kPrimaryBlue, fontWeight: FontWeight.bold)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(email, style: const TextStyle(fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isActive ? lang.tr('status_active', category: 'admin') : lang.tr('inactive', category: 'admin'),
            style: TextStyle(color: isActive ? Colors.green : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Text(lang.tr('quick_generate', category: 'admin'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kMutedTextColor)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [1, 3, 6, 12].map((m) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryBlue.withOpacity(0.05),
                          foregroundColor: kPrimaryBlue,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _generate(email: email, months: m),
                        child: Text(m == 12 ? '1Y' : '${m}M', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // End of AdminCodesPage
}
