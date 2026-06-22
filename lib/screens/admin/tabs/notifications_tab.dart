import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../ViewModel/admin_view_model.dart';
import '../../../providers/language_provider.dart';
import '../admin_components.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key});

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _targetRole = 'all';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<LanguageProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- Header ----------
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AdminColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.campaign_rounded, color: AdminColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.tr('broadcast_title', category: 'admin'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: isDark ? Colors.white : AdminColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lang.tr('broadcast_desc', category: 'admin'),
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? Colors.white70 : AdminColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ---------- Compose Card ----------
          AdminCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel(lang.tr('target_audience', category: 'admin'), isDark),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _roleChoice(lang.tr('all_roles', category: 'admin'), 'all', isDark),
                    _roleChoice(lang.tr('providers', category: 'admin'), 'provider', isDark),
                    _roleChoice(lang.tr('clients', category: 'admin'), 'client', isDark),
                  ],
                ),
                const SizedBox(height: 28),
                Divider(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
                const SizedBox(height: 24),
                _sectionLabel(lang.tr('notification_content', category: 'admin'), isDark),
                const SizedBox(height: 16),
                AdminTextField(
                  hintText: lang.tr('title_hint', category: 'admin'),
                  controller: _titleCtrl,
                  prefixIcon: Icons.title_rounded,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _bodyCtrl,
                  maxLines: 4,
                  style: TextStyle(color: isDark ? Colors.white : AdminColors.textMain),
                  decoration: InputDecoration(
                    hintText: lang.tr('body_hint', category: 'admin'),
                    hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.04) : AdminColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AdminColors.primary, width: 1.4),
                    ),
                    contentPadding: const EdgeInsets.all(20),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: Consumer<AdminViewModel>(
                    builder: (context, vm, child) {
                      return AdminButton(
                        label: vm.isLoading ? lang.tr('sending', category: 'admin') : lang.tr('broadcast_notification', category: 'admin'),
                        icon: Icons.send_rounded,
                        onPressed: vm.isLoading ? null : () => _handleBroadcast(vm, lang),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ---------- History Card ----------
          AdminCard(
            title: lang.tr('broadcast_history', category: 'admin'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 36,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    lang.tr('no_broadcasts', category: 'admin'),
                    style: TextStyle(
                      color: isDark ? Colors.white70 : AdminColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: isDark ? Colors.white60 : AdminColors.textSecondary,
      ),
    );
  }

  Widget _roleChoice(String label, String value, bool isDark) {
    final isSelected = _targetRole == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() => _targetRole = value),
      selectedColor: AdminColors.primary,
      backgroundColor: isDark ? Colors.white.withOpacity(0.05) : AdminColors.background,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      avatar: isSelected
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.white70 : AdminColors.textSecondary),
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  Future<void> _handleBroadcast(AdminViewModel vm, LanguageProvider lang) async {
    if (_titleCtrl.text.isEmpty || _bodyCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.tr('fill_fields', category: 'admin'))));
      return;
    }

    await vm.broadcastNotification(
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      targetRole: _targetRole,
    );

    _titleCtrl.clear();
    _bodyCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.tr('broadcast_success', category: 'admin'))));
    }
  }
}
