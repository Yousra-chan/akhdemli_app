import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/Services/subscription_service.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';


const kPrimaryColor = Color(0xFF143EAE);
const kMutedTextColor = Color(0xFF5A6670);
const kBorderColor = Color(0xFFE0E0E0);

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final TextEditingController _codeCtrl = TextEditingController();
  final SubscriptionService _service = SubscriptionService();
  bool _loading = false;

  Future<void> _openWhatsApp() async {
    final auth = context.read<AuthViewModel>();
    final lang = context.read<LanguageProvider>();

    try {
      String? adminPhone;

      final adminQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();

      if (adminQuery.docs.isNotEmpty) {
        adminPhone = adminQuery.docs.first.data()['phone'] as String?;
      }

      if (adminPhone == null || adminPhone.isEmpty) {
        AppSnackBar.showError(
            context, lang.tr('admin_phone_not_configured', category: 'profile'));
        return;
      }

      final user = auth.currentUser;

      final message = Uri.encodeComponent(
        'Hello admin, I want to buy a subscription.\n'
        'UID: ${user?.uid}\n'
        'Name: ${user?.name}',
      );

      final url = Uri.parse('https://wa.me/$adminPhone?text=$message');

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      AppSnackBar.showError(context, '${lang.tr('error_occurred', category: 'common')}: $e');
    }
  }

  Future<void> _applyCode() async {
    final auth = context.read<AuthViewModel>();
    final lang = context.read<LanguageProvider>();
    final user = auth.currentUser;

    final code = _codeCtrl.text.trim();

    if (code.isEmpty) {
      AppSnackBar.showError(context, lang.tr('enter_code_error', category: 'profile'));
      return;
    }

    if (user == null) {
      AppSnackBar.showError(context, lang.tr('pleaseSignIn', category: 'profile'));
      return;
    }

    setState(() => _loading = true);

    try {
      await _service.activateSubscription(
        providerId: user.uid,
        code: code,
      );

      if (mounted) {
        AppSnackBar.showSuccess(context, lang.tr('subscription_activated_success', category: 'profile'));
      }

      try {
        await auth.refreshCurrentUser();
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (_) {}

      _codeCtrl.clear();
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, lang.tr('subscription_failed', category: 'profile'));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final lang = context.watch<LanguageProvider>();
    final user = auth.currentUser;

    // Subscription only for providers
    if (user != null && !user.isProvider && !user.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text(lang.tr('mySubscription', category: 'common'))),
        body: Center(child: Text(lang.tr('permission_error', category: 'common'))),
      );
    }

    final expiry = user?.subscriptionExpiresAt ?? user?.subscriptionExpiry;

    final isActive = (user?.subscriptionActive ?? false) &&
        expiry != null &&
        expiry.toDate().isAfter(DateTime.now());

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.textTheme.titleLarge?.color),
        title: Text(
          lang.tr('mySubscription', category: 'common'),
          style: TextStyle(
            color: theme.textTheme.titleLarge?.color,
            fontWeight: FontWeight.w600,
            fontFamily: 'Exo2'
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatusCard(isActive, expiry, lang, theme),
            const SizedBox(height: 16),
            _buildActionCard(lang, theme),
            const SizedBox(height: 16),
            _buildCodeCard(lang, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isActive, dynamic expiry, LanguageProvider lang, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                lang.tr('subscription_status', category: 'profile'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  fontFamily: 'Exo2'
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? lang.tr('active', category: 'profile') : lang.tr('inactive', category: 'profile'),
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    fontFamily: 'Exo2'
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            expiry != null
                ? lang.trParams('expires', category: 'profile', params: {'date': expiry.toDate().toString().split(" ")[0]})
                : lang.tr('no_active_subscription', category: 'profile'),
            style: TextStyle(
              color: isDark ? Colors.white38 : kMutedTextColor,
              fontFamily: 'Exo2'
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(LanguageProvider lang, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.tr('need_subscription', category: 'profile'),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              fontFamily: 'Exo2'
            ),
          ),
          const SizedBox(height: 10),
          Text(
            lang.tr('contact_admin_instructions', category: 'profile'),
            style: TextStyle(color: isDark ? Colors.white38 : kMutedTextColor, fontFamily: 'Exo2'),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openWhatsApp,
              icon: const Icon(Icons.chat),
              label: Text(lang.tr('contact_admin', category: 'profile')),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard(LanguageProvider lang, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.tr('activate_with_code', category: 'profile'),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              fontFamily: 'Exo2'
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeCtrl,
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
            decoration: InputDecoration(
              hintText: lang.tr('enter_code_hint', category: 'profile'),
              hintStyle: TextStyle(fontFamily: 'Exo2', color: isDark ? Colors.white24 : Colors.grey),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _applyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, // Changed from kSuccessColor for clarity
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(lang.tr('activate_subscription', category: 'profile'), style: const TextStyle(fontFamily: 'Exo2')),
            ),
          ),
        ],
      ),
    );
  }
}
