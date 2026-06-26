import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/Services/subscription_service.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';
import 'package:service_app/Services/firebase_service.dart';
import 'package:service_app/screens/home/home_screen/home_constants.dart';

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

      if (!mounted) return;

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
        lang.trParams('whatsapp_sub_message', category: 'profile', params: {
          'uid': user?.uid ?? '',
          'name': user?.name ?? '',
        }),
      );

      final url = Uri.parse('https://wa.me/$adminPhone?text=$message');

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
            context, '${lang.tr('error_occurred', category: 'common')}: $e');
      }
    }
  }

  Future<void> _applyCode() async {
    final auth = context.read<AuthViewModel>();
    final lang = context.read<LanguageProvider>();
    final user = auth.currentUser;

    final code = _codeCtrl.text.trim();

    if (code.isEmpty) {
      AppSnackBar.showError(
          context, lang.tr('enter_code_error', category: 'profile'));
      return;
    }

    if (user == null) {
      AppSnackBar.showError(
          context, lang.tr('pleaseSignIn', category: 'profile'));
      return;
    }

    setState(() => _loading = true);

    try {
      await _service.activateSubscription(
        email: user.email,
        code: code,
      );

      if (mounted) {
        AppSnackBar.showSuccess(context,
            lang.tr('subscription_activated_success', category: 'profile'));
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
        AppSnackBar.showError(
            context, lang.tr('subscription_failed', category: 'profile'));
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

    if (user != null && user.isGuest) {
      return Scaffold(
        appBar:
            AppBar(title: Text(lang.tr('mySubscription', category: 'common'))),
        body: Center(
            child: Text(lang.tr('permission_error', category: 'common'))),
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
              fontFamily: 'Exo2'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatusCard(isActive, expiry, lang, theme),
            const SizedBox(height: 16),
            _buildHowItWorksCard(lang, theme),
            const SizedBox(height: 16),
            _buildSubscriptionOptions(lang, theme),
            const SizedBox(height: 16),
            _buildActionCard(lang, theme),
            const SizedBox(height: 16),
            _buildCodeCard(lang, theme),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
      bool isActive, dynamic expiry, LanguageProvider lang, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                    fontFamily: 'Exo2'),
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
                  isActive
                      ? lang.tr('active', category: 'profile')
                      : lang.tr('inactive', category: 'profile'),
                  style: TextStyle(
                      color: isActive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      fontFamily: 'Exo2'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            expiry != null
                ? lang.trParams('expires',
                    category: 'profile',
                    params: {'date': expiry.toDate().toString().split(" ")[0]})
                : lang.tr('no_active_subscription', category: 'profile'),
            style: TextStyle(
                color: isDark ? Colors.white38 : kMutedTextColor,
                fontFamily: 'Exo2'),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksCard(LanguageProvider lang, ThemeData theme) {
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
            lang.tr('how_it_works', category: 'profile'),
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                fontFamily: 'Exo2',
                color: Color.fromARGB(255, 12, 94, 153)),
          ),
          const SizedBox(height: 12),
          _buildStepItem(lang.tr('step_1', category: 'profile'), theme),
          _buildStepItem(lang.tr('step_2', category: 'profile'), theme),
          _buildStepItem(lang.tr('step_3', category: 'profile'), theme),
          _buildStepItem(lang.tr('step_4', category: 'profile'), theme),
          _buildStepItem(lang.tr('step_5', category: 'profile'), theme),
        ],
      ),
    );
  }

  Widget _buildStepItem(String text, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline,
              size: 18, color: theme.primaryColor.withOpacity(0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
                fontFamily: 'Exo2',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionOptions(LanguageProvider lang, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            lang.tr('subscription_options', category: 'profile'),
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16, fontFamily: 'Exo2'),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          itemCount: 12,
          itemBuilder: (context, index) {
            int months = index + 1;
            return Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    lang.tr('month_$months', category: 'profile'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        fontFamily: 'Exo2'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lang.tr('price_on_contact', category: 'profile'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.grey,
                        fontFamily: 'Exo2'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(LanguageProvider lang, ThemeData theme) {
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
                fontWeight: FontWeight.w600, fontSize: 15, fontFamily: 'Exo2'),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openWhatsApp,
              icon: const Icon(Icons.chat),
              label: Text(lang.tr('contact_admin', category: 'profile')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366), // WhatsApp Green
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
                fontWeight: FontWeight.w600, fontSize: 15, fontFamily: 'Exo2'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeCtrl,
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
            decoration: InputDecoration(
              hintText: lang.tr('enter_code_hint', category: 'profile'),
              hintStyle: TextStyle(
                  fontFamily: 'Exo2',
                  color: isDark ? Colors.white24 : Colors.grey),
              filled: true,
              fillColor:
                  isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
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
                backgroundColor: theme.primaryColor,
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
                  : Text(lang.tr('activate_subscription', category: 'profile'),
                      style: const TextStyle(fontFamily: 'Exo2')),
            ),
          ),
        ],
      ),
    );
  }
}
