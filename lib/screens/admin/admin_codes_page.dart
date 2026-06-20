import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/Services/subscription_service.dart';
import 'package:service_app/screens/auth/login/login_screen.dart';
import 'package:service_app/utils/ui_widgets.dart';

const Color kPrimaryBlue = Color(0xFF143EAE);
const Color kMutedTextColor = Color(0xFF5A6670);
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
        AppSnackBar.showError(context, 'Error loading data: $e');
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

  // ============================================================================
  // CODE GENERATION
  // ============================================================================

  Future<void> _openGenerateDialog() async {
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
              title: const Text(
                'Generate Subscription Code',
                style: TextStyle(
                    fontFamily: kAppFont, fontWeight: FontWeight.w600),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('User email (optional)',
                      style: TextStyle(fontSize: 13, color: kMutedTextColor)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'user@example.com',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Duration',
                      style: TextStyle(fontSize: 13, color: kMutedTextColor)),
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
                    items: List.generate(12, (i) => i + 1)
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m == 1 ? '1 month' : '$m months'),
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
                  child: const Text('Cancel'),
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
                  child: const Text('Generate'),
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
    await _generate(
        email: email.isEmpty ? null : email, months: selectedMonths);
  }

  Future<void> _generate({String? email, required int months}) async {
    setState(() => _loading = true);
    try {
      String? userId;
      String? note;

      if (email != null) {
        final user = await _service.findUserByEmail(email);
        if (user == null) {
          if (mounted) {
            final proceed = await _confirmNoUserFound(email);
            if (!proceed) {
              setState(() => _loading = false);
              return;
            }
          }
          note = email; // User doesn't exist yet, save email as note
        } else {
          // Just get the user ID, no role check
          userId = user['uid'] as String;
          note = email;
        }
      }

      final code = await _service.generateSubscriptionCode(
        validDays: months * 30,
        providerId: userId, // This field name is misleading, but we'll keep it
        note: note,
      );

      await _loadAll();
      if (!mounted) return;

      // Show success dialog (same as before)
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Code Generated',
              style: TextStyle(
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
                months == 1 ? 'Valid for 1 month' : 'Valid for $months months',
                style: const TextStyle(color: kMutedTextColor, fontSize: 13),
              ),
              if (email != null) ...[
                const SizedBox(height: 4),
                Text(
                  userId != null
                      ? 'Linked to: $email'
                      : 'Note: $email (will work when they sign up)',
                  style: const TextStyle(color: kMutedTextColor, fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                AppSnackBar.showSuccess(context, 'Code copied');
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Generate failed: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirmNoUserFound(String email) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('No account found'),
        content: Text(
          'No user is registered with "$email" yet.\n'
          'You can still generate the code — it will not be linked '
          'to an account and the user can redeem it manually once they sign up.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryBlue, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Generate anyway'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ============================================================================
  // CODE ACTIONS
  // ============================================================================

  Future<void> _deleteCode(String code) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete code?'),
        content: Text('This will permanently delete the code "$code".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.deleteCode(code);
      await _loadAll();
      if (mounted) {
        AppSnackBar.showSuccess(context, 'Code deleted');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Failed to delete: $e');
      }
    }
  }

  Future<void> _bulkDeleteUsedCodes() async {
    final usedCodes =
        _codes.where((c) => (c['used'] ?? false) == true).toList();
    if (usedCodes.isEmpty) {
      AppSnackBar.showWarning(context, 'No used codes to delete');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete all used codes?'),
        content: Text(
            'This will permanently delete ${usedCodes.length} used code(s). This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      for (final c in usedCodes) {
        final code = c['id'] ?? c['code'] ?? '';
        if (code.isNotEmpty) await _service.deleteCode(code as String);
      }
      await _loadAll();
      if (mounted) {
        AppSnackBar.showSuccess(context, '${usedCodes.length} used code(s) deleted');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Bulk delete failed: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _exportCodes() {
    final buffer = StringBuffer();
    buffer.writeln('Code,Email,Duration,Expiry,Status,UsedBy');
    for (final c in _filteredCodes) {
      final code = c['id'] ?? c['code'] ?? '';
      final note = c['note'] ?? '';
      final validDays = c['validDays'] ?? '';
      final validUntil = c['validUntil'] != null
          ? c['validUntil'].toDate().toString().split(' ')[0]
          : '';
      final used = (c['used'] ?? false) ? 'Used' : 'Available';
      final usedBy = _emailForUid(c['usedBy'] as String?) ?? '';
      buffer.writeln('$code,$note,$validDays days,$validUntil,$used,$usedBy');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    AppSnackBar.showSuccess(context, 'Codes exported to clipboard (CSV)');
  }

  void _showCodeDetail(Map<String, dynamic> codeData) {
    final String code = codeData['id'] ?? codeData['code'] ?? '';
    final bool used = codeData['used'] ?? false;
    final validUntil = codeData['validUntil'];
    final validDays = codeData['validDays'] as int?;
    final note = codeData['note'] as String?;
    final providerId = codeData['providerId'] as String?;
    final usedBy = codeData['usedBy'] as String?;
    final usedAt = codeData['usedAt'];
    final createdAt = codeData['createdAt'];
    final linkedEmail =
        note ?? _emailForUid(providerId) ?? _emailForUid(usedBy);

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
                _statusChip(used),
              ],
            ),
            const Divider(height: 24),
            _detailRow(Icons.person_outline, 'Linked to',
                linkedEmail ?? 'No user linked'),
            _detailRow(
                Icons.calendar_today_outlined,
                'Created',
                createdAt != null
                    ? createdAt.toDate().toString().split(' ')[0]
                    : '-'),
            _detailRow(
                Icons.timer_outlined,
                'Duration',
                validDays != null
                    ? '${(validDays / 30).round()} month(s)'
                    : '-'),
            _detailRow(
                Icons.event_outlined,
                'Expires',
                validUntil != null
                    ? validUntil.toDate().toString().split(' ')[0]
                    : 'No expiration'),
            if (used) ...[
              _detailRow(Icons.check_circle_outline, 'Redeemed by',
                  _emailForUid(usedBy) ?? usedBy ?? '-'),
              _detailRow(
                  Icons.access_time,
                  'Redeemed on',
                  usedAt != null
                      ? usedAt.toDate().toString().split(' ')[0]
                      : '-'),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      AppSnackBar.showSuccess(context, 'Code copied');
                    },
                    icon: const Icon(Icons.copy, color: kPrimaryBlue),
                    label: const Text('Copy',
                        style: TextStyle(color: kPrimaryBlue)),
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
                    label: const Text('Delete',
                        style: TextStyle(color: Colors.white)),
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

  // ============================================================================
  // DERIVED LISTS
  // ============================================================================

  List<Map<String, dynamic>> get _filteredCodes {
    List<Map<String, dynamic>> result;

    switch (_codeFilter) {
      case _CodeFilter.available:
        result = _codes.where((c) => (c['used'] ?? false) == false).toList();
        break;
      case _CodeFilter.used:
        result = _codes.where((c) => (c['used'] ?? false) == true).toList();
        break;
      case _CodeFilter.all:
      default:
        result = List.from(_codes);
    }

    if (_codeSearch.isNotEmpty) {
      final q = _codeSearch.toLowerCase();
      result = result.where((c) {
        final note = (c['note'] ?? '').toString().toLowerCase();
        final code = (c['id'] ?? c['code'] ?? '').toString().toLowerCase();
        final providerId = c['providerId'] as String?;
        final usedBy = c['usedBy'] as String?;
        final emailFromUid =
            (_emailForUid(providerId) ?? _emailForUid(usedBy) ?? '')
                .toLowerCase();
        return note.contains(q) || code.contains(q) || emailFromUid.contains(q);
      }).toList();
    }

    // Sort
    result.sort((a, b) {
      final aDate = a['createdAt'];
      final bDate = b['createdAt'];
      if (aDate == null || bDate == null) return 0;
      final cmp = aDate.toDate().compareTo(bDate.toDate());
      return _sortOrder == _SortOrder.newest ? -cmp : cmp;
    });

    return result;
  }

  List<Map<String, dynamic>> get _historyEntries {
    return _codes.where((c) => (c['used'] ?? false) == true).toList()
      ..sort((a, b) {
        final aDate = a['usedAt'];
        final bDate = b['usedAt'];
        if (aDate == null || bDate == null) return 0;
        return bDate.toDate().compareTo(aDate.toDate());
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

  int get usedCount => _codes.where((e) => (e['used'] ?? false) == true).length;
  int get availableCount =>
      _codes.where((e) => (e['used'] ?? false) == false).length;

  int get activeSubscriptionsCount => _users.where((u) {
        final active = u['subscriptionActive'] ?? false;
        if (active != true) return false;
        final expiry = u['subscriptionExpiresAt'] ?? u['subscriptionExpiry'];
        if (expiry == null) return true;
        try {
          return (expiry as dynamic).toDate().isAfter(DateTime.now());
        } catch (_) {
          return true;
        }
      }).length;

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final user = auth.currentUser;

    if (user == null || !user.isAdmin) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: kDarkTextColor),
          title: const Text('Unauthorized',
              style: TextStyle(
                  color: kDarkTextColor,
                  fontWeight: FontWeight.w600,
                  fontFamily: kAppFont)),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('You are not authorized to view this page.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: kMutedTextColor)),
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
        title: const Text('Admin Panel',
            style: TextStyle(
                color: kDarkTextColor,
                fontWeight: FontWeight.w600,
                fontFamily: kAppFont)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: kPrimaryBlue,
          unselectedLabelColor: kMutedTextColor,
          indicatorColor: kPrimaryBlue,
          tabs: const [
            Tab(text: 'Codes'),
            Tab(text: 'History'),
            Tab(text: 'Users'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kPrimaryBlue),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadAll,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: () async {
              final auth = Provider.of<AuthViewModel>(context, listen: false);
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: kPrimaryBlue,
              onPressed: _loading ? null : _openGenerateDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Generate',
                  style: TextStyle(color: Colors.white, fontFamily: kAppFont)),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryBlue))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCodesTab(),
                _buildHistoryTab(),
                _buildUsersTab(),
              ],
            ),
    );
  }

  // ============================================================================
  // CODES TAB
  // ============================================================================

  Widget _buildCodesTab() {
    final codes = _filteredCodes;

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: kPrimaryBlue,
      child: Column(
        children: [
          _buildStatsHeader(),
          // Search + actions row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeSearchCtrl,
                    onChanged: (v) => setState(() => _codeSearch = v),
                    decoration: InputDecoration(
                      hintText: 'Search by email or code',
                      prefixIcon:
                          const Icon(Icons.search, color: kMutedTextColor),
                      suffixIcon: _codeSearch.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: kMutedTextColor),
                              onPressed: () {
                                _codeSearchCtrl.clear();
                                setState(() => _codeSearch = '');
                              },
                            )
                          : null,
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
                // Sort button
                PopupMenuButton<_SortOrder>(
                  tooltip: 'Sort',
                  icon: const Icon(Icons.sort, color: kPrimaryBlue),
                  onSelected: (v) => setState(() => _sortOrder = v),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _SortOrder.newest,
                      child: Row(children: [
                        Icon(Icons.arrow_downward,
                            size: 16,
                            color: _sortOrder == _SortOrder.newest
                                ? kPrimaryBlue
                                : kMutedTextColor),
                        const SizedBox(width: 8),
                        const Text('Newest first'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: _SortOrder.oldest,
                      child: Row(children: [
                        Icon(Icons.arrow_upward,
                            size: 16,
                            color: _sortOrder == _SortOrder.oldest
                                ? kPrimaryBlue
                                : kMutedTextColor),
                        const SizedBox(width: 8),
                        const Text('Oldest first'),
                      ]),
                    ),
                  ],
                ),
                // More actions
                PopupMenuButton<String>(
                  tooltip: 'More actions',
                  icon: const Icon(Icons.more_vert, color: kPrimaryBlue),
                  onSelected: (v) {
                    if (v == 'export') _exportCodes();
                    if (v == 'bulk_delete') _bulkDeleteUsedCodes();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'export',
                      child: Row(children: [
                        Icon(Icons.download_outlined,
                            size: 18, color: kMutedTextColor),
                        SizedBox(width: 8),
                        Text('Export to clipboard (CSV)'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'bulk_delete',
                      child: Row(children: [
                        Icon(Icons.delete_sweep_outlined,
                            size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete all used codes',
                            style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildCodeFilterChips(),
          Expanded(
            child: codes.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 80),
                    Center(
                        child: Text('No subscription codes found',
                            style: TextStyle(
                                color: kMutedTextColor, fontSize: 15))),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    itemCount: codes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildCodeCard(codes[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
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
          _statItem(title: 'Total', value: _codes.length.toString()),
          _statItem(title: 'Used', value: usedCount.toString()),
          _statItem(title: 'Available', value: availableCount.toString()),
          _statItem(
              title: 'Active subs', value: activeSubscriptionsCount.toString()),
        ],
      ),
    );
  }

  Widget _buildCodeFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _filterChip('All', _CodeFilter.all),
          const SizedBox(width: 8),
          _filterChip('Available', _CodeFilter.available),
          const SizedBox(width: 8),
          _filterChip('Used', _CodeFilter.used),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _CodeFilter value) {
    final selected = _codeFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: kPrimaryBlue.withOpacity(0.15),
      labelStyle: TextStyle(
        color: selected ? kPrimaryBlue : kMutedTextColor,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
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
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildCodeCard(Map<String, dynamic> codeData) {
    final bool used = codeData['used'] ?? false;
    final String code = codeData['id'] ?? codeData['code'] ?? '';
    final validUntil = codeData['validUntil'];
    final validDays = codeData['validDays'] as int?;
    final providerId = codeData['providerId'] as String?;
    final note = codeData['note'] as String?;
    final usedBy = codeData['usedBy'] as String?;
    final linkedEmail =
        note ?? _emailForUid(providerId) ?? _emailForUid(usedBy);

    return GestureDetector(
      onTap: () => _showCodeDetail(codeData),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
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
                  _statusChip(used),
                ],
              ),
              if (linkedEmail != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.person_outline,
                      size: 16, color: kMutedTextColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(linkedEmail,
                        style: const TextStyle(
                            color: kMutedTextColor, fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Duration',
                            style: TextStyle(
                                color: kMutedTextColor, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          validDays != null
                              ? '${(validDays / 30).round()} month(s)'
                              : '-',
                          style: const TextStyle(
                              color: kDarkTextColor, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Expiration Date',
                            style: TextStyle(
                                color: kMutedTextColor, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          validUntil != null
                              ? validUntil.toDate().toString().split(' ')[0]
                              : 'No expiration',
                          style: const TextStyle(
                              color: kDarkTextColor, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _deleteCode(code),
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                    label: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      AppSnackBar.showSuccess(context, 'Code copied');
                    },
                    icon: const Icon(Icons.copy, size: 18, color: kPrimaryBlue),
                    label: const Text('Copy',
                        style: TextStyle(color: kPrimaryBlue)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kPrimaryBlue),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
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

  Widget _statusChip(bool used) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:
            used ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        used ? 'Used' : 'Available',
        style: TextStyle(
            color: used ? Colors.red : Colors.green,
            fontWeight: FontWeight.w600,
            fontSize: 12),
      ),
    );
  }

  // ============================================================================
  // HISTORY TAB
  // ============================================================================

  Widget _buildHistoryTab() {
    final history = _historyEntries;

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: kPrimaryBlue,
      child: history.isEmpty
          ? ListView(children: const [
              SizedBox(height: 120),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: kMutedTextColor),
                    SizedBox(height: 12),
                    Text('No redemption history yet',
                        style: TextStyle(color: kMutedTextColor, fontSize: 15)),
                  ],
                ),
              ),
            ])
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _buildHistoryCard(history[index]),
            ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> c) {
    final String code = c['id'] ?? c['code'] ?? '';
    final usedBy = c['usedBy'] as String?;
    final note = c['note'] as String?;
    final providerId = c['providerId'] as String?;
    final usedAt = c['usedAt'];
    final validDays = c['validDays'] as int?;
    final linkedEmail =
        _emailForUid(usedBy) ?? note ?? _emailForUid(providerId) ?? '-';
    final usedAtStr =
        usedAt != null ? usedAt.toDate().toString().split(' ')[0] : '-';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kPrimaryBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.vpn_key_outlined,
                color: kPrimaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(code,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: kDarkTextColor,
                        letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.person_outline,
                      size: 13, color: kMutedTextColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(linkedEmail,
                        style: const TextStyle(
                            color: kMutedTextColor, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 13, color: kMutedTextColor),
                  const SizedBox(width: 4),
                  Text('Redeemed: $usedAtStr',
                      style: const TextStyle(
                          color: kMutedTextColor, fontSize: 12)),
                  const SizedBox(width: 10),
                  if (validDays != null) ...[
                    const Icon(Icons.timer_outlined,
                        size: 13, color: kMutedTextColor),
                    const SizedBox(width: 4),
                    Text('${(validDays / 30).round()} month(s)',
                        style: const TextStyle(
                            color: kMutedTextColor, fontSize: 12)),
                  ]
                ]),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete record',
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: () => _deleteCode(code),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // USERS TAB
  // ============================================================================

  Widget _buildUsersTab() {
    final users = _filteredUsers;

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: kPrimaryBlue,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _userSearchCtrl,
              onChanged: (v) => setState(() => _userSearch = v),
              decoration: InputDecoration(
                hintText: 'Search by email, name or role',
                prefixIcon: const Icon(Icons.search, color: kMutedTextColor),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kBorderColor),
                ),
              ),
            ),
          ),
          Expanded(
            child: users.isEmpty
                ? const Center(
                    child: Text('No users found',
                        style: TextStyle(color: kMutedTextColor, fontSize: 15)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _buildUserCard(users[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> u) {
    final email = (u['email'] ?? '') as String;
    final name = (u['name'] ?? '') as String;
    final role = (u['role'] ?? 'client') as String;
    final subscriptionActive = u['subscriptionActive'] ?? false;
    final expiry = u['subscriptionExpiresAt'] ?? u['subscriptionExpiry'];

    String expiryLabel = 'No subscription';
    if (expiry != null) {
      try {
        expiryLabel =
            'Expires: ${(expiry as dynamic).toDate().toString().split(' ')[0]}';
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: kPrimaryBlue.withOpacity(0.1),
            child: Text(
              email.isNotEmpty ? email[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: kPrimaryBlue, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isNotEmpty ? name : email,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(email,
                    style:
                        const TextStyle(color: kMutedTextColor, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  _smallTag(role, kPrimaryBlue),
                  const SizedBox(width: 6),
                  _smallTag(
                    subscriptionActive == true ? 'active' : 'inactive',
                    subscriptionActive == true ? Colors.green : Colors.grey,
                  ),
                ]),
                const SizedBox(height: 4),
                Text(expiryLabel,
                    style:
                        const TextStyle(color: kMutedTextColor, fontSize: 11)),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                tooltip: 'Copy email',
                icon: const Icon(Icons.copy, size: 18, color: kMutedTextColor),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: email));
                  AppSnackBar.showSuccess(context, 'Email copied');
                },
              ),
              IconButton(
                tooltip: 'Generate code for this user',
                icon:
                    const Icon(Icons.qr_code_2, size: 18, color: kPrimaryBlue),
                onPressed: () => _quickGenerateForUser(email),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _quickGenerateForUser(String email) async {
    int months = 1;

    final selectedMonths = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text('Generate code for\n$email',
                  style: const TextStyle(
                      fontFamily: kAppFont,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
              content: DropdownButtonFormField<int>(
                initialValue: months,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: List.generate(12, (i) => i + 1)
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m == 1 ? '1 month' : '$m months'),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => months = val);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryBlue,
                      foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(dialogContext, months),
                  child: const Text('Generate'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedMonths == null) return;
    await _generate(email: email, months: selectedMonths);
  }
}
