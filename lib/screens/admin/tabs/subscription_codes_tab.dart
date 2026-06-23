import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../ViewModel/admin_view_model.dart';
import '../../../utils/ui_widgets.dart';
import '../../../providers/language_provider.dart';
import '../admin_components.dart';

class SubscriptionCodesTab extends StatelessWidget {
  const SubscriptionCodesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<AdminViewModel>(
      builder: (context, vm, child) {
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
                    child: const Icon(Icons.vpn_key_rounded, color: AdminColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang.tr('codes', category: 'admin'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: isDark ? Colors.white : AdminColors.textMain,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          lang.tr('generate_codes_desc', category: 'admin'),
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? Colors.white70 : AdminColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AdminButton(
                    onPressed: () => _showGenerateDialog(context, vm, lang),
                    icon: Icons.add_rounded,
                    label: lang.tr('generate_code', category: 'admin'),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ---------- Codes List ----------
              Expanded(
                child: vm.subscriptionCodes.isEmpty
                    ? AdminEmptyState(
                    title: lang.tr('no_data_found', category: 'admin'),
                    subtitle: lang.tr('generate_codes_subtitle', category: 'admin'),
                    icon: Icons.vpn_key_outlined
                )
                    : ListView.builder(
                  itemCount: vm.subscriptionCodes.length,
                  itemBuilder: (context, index) {
                    final code = vm.subscriptionCodes[index];
                    return _buildCodeCard(context, code, vm, lang, isDark);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCodeCard(BuildContext context, Map<String, dynamic> data, AdminViewModel vm, LanguageProvider lang, bool isDark) {
    final bool isUsed = data['isUsed'] ?? false;
    final String code = data['code'] ?? '';
    final String assignedTo = data['assignedEmail'] ?? lang.tr('unknown', category: 'admin');
    final int duration = data['duration'] ?? 1;
    final DateTime? expiresAt = data['expiresAt'] is Timestamp ? (data['expiresAt'] as Timestamp).toDate() : null;
    final statusColor = isUsed ? Colors.grey : AdminColors.success;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AdminCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [statusColor.withOpacity(0.18), statusColor.withOpacity(0.06)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.vpn_key_rounded, color: statusColor, size: 22),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(
                    code,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: 1.5,
                      color: isDark ? Colors.white : AdminColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lang.trParams('code_assigned_to', category: 'admin', params: {'uid': assignedTo}),
                    style: TextStyle(color: isDark ? Colors.white70 : AdminColors.textSecondary, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isUsed ? AdminColors.danger : AdminColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isUsed
                              ? '${lang.tr('status', category: 'admin').toUpperCase()}: ${lang.tr('status_used', category: 'admin')}'
                              : '${lang.tr('available', category: 'admin')} • ${lang.trParams('code_duration', category: 'admin', params: {'months': duration.toString()})} • ${lang.tr('expires', category: 'admin')}: ${expiresAt != null ? DateFormat('MMM dd, yyyy').format(expiresAt) : 'N/A'}',
                          style: TextStyle(
                            color: isUsed ? AdminColors.danger : (isDark ? Colors.white60 : AdminColors.textSecondary),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isUsed) ...[
              const SizedBox(width: 12),
              AdminButton(
                label: lang.tr('copy', category: 'admin'),
                icon: Icons.copy_rounded,
                isSecondary: true,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) AppSnackBar.showSuccess(context, lang.tr('copied', category: 'admin'));
                },
              ),
            ],
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AdminColors.danger),
              onPressed: () => vm.deleteCode(code),
              tooltip: lang.tr('revoke_code', category: 'admin'),
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showGenerateDialog(BuildContext context, AdminViewModel vm, LanguageProvider lang) {
    final uidCtrl = TextEditingController();
    int selectedMonths = 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            lang.tr('generate_code', category: 'admin'),
            style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : AdminColors.textMain),
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.tr('user_email_required', category: 'admin'),
                  style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white54 : AdminColors.textSecondary),
                ),
                const SizedBox(height: 12),
                AdminTextField(
                  controller: uidCtrl,
                  hintText: lang.tr('user_email_placeholder', category: 'admin'),
                  prefixIcon: Icons.email_outlined,
                ),
                const SizedBox(height: 24),
                Text(
                  lang.tr('subscription_duration', category: 'admin'),
                  style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white54 : AdminColors.textSecondary),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: selectedMonths,
                  dropdownColor: Theme.of(context).cardColor,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AdminColors.textMain),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.04) : Theme.of(context).scaffoldBackgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AdminColors.primary, width: 1.4),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  items: [1, 2, 3, 6, 12].map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(lang.trParams('code_duration', category: 'admin', params: {'months': m.toString()}))
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedMonths = val);
                  },
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                lang.tr('cancel', category: 'common'),
                style: TextStyle(color: isDark ? Colors.white60 : AdminColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ),
            AdminButton(
              label: lang.tr('save', category: 'common'),
              onPressed: () async {
                if (uidCtrl.text.trim().isEmpty) {
                  AppSnackBar.showError(context, lang.tr('email_required_error', category: 'admin'));
                  return;
                }
                final code = await vm.generateNewCode(
                    email: uidCtrl.text.trim(),
                    months: selectedMonths
                );
                Navigator.pop(ctx);
                if (context.mounted) _showSuccessDialog(context, code, lang);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String code, LanguageProvider lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AdminColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle_rounded, color: AdminColors.success, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                lang.tr('code_generated', category: 'admin'),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: isDark ? Colors.white : AdminColors.textMain),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lang.tr('share_code_desc', category: 'admin'),
              style: TextStyle(color: isDark ? Colors.white60 : AdminColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AdminColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AdminColors.primary.withOpacity(0.15)),
              ),
              child: SelectableText(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AdminColors.primary, letterSpacing: 3),
              ),
            ),
          ],
        ),
        actions: [
          AdminButton(
            label: lang.tr('done', category: 'common'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
              AppSnackBar.showSuccess(context, lang.tr('copied', category: 'admin'));
            },
          ),
        ],
      ),
    );
  }
}
