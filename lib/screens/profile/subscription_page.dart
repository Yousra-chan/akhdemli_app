import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/Services/subscription_service.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';

// Modern Color Palette
const Color kPrimaryColor = Color(0xFF143EAE);
const Color kSecondaryColor = Color(0xFF2B3674);
const Color kBackgroundColor = Color(0xFFF4F7FE);
const Color kTextSecondary = Color(0xFF707EAE);
const Color kSuccessColor = Color(0xFF05CD99);
const Color kDangerColor = Color(0xFFEE5D50);

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> with SingleTickerProviderStateMixin {
  final TextEditingController _codeCtrl = TextEditingController();
  final SubscriptionService _service = SubscriptionService();
  bool _loading = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _openWhatsApp({String? planName}) async {
    final auth = context.read<AuthViewModel>();
    final lang = context.read<LanguageProvider>();
    final user = auth.currentUser;

    if (user == null) {
      AppSnackBar.showError(context, lang.tr('pleaseSignIn', category: 'profile'));
      return;
    }

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
        AppSnackBar.showError(context, lang.tr('admin_phone_not_configured', category: 'profile'));
        return;
      }

      final expiry = user.subscriptionExpiresAt ?? user.subscriptionExpiry;
      final isActive = user.subscriptionActive &&
          expiry != null &&
          expiry.toDate().isAfter(DateTime.now());

      final status = isActive ? "Active" : (user.subscriptionActive ? "Expired" : "Inactive");
      final location = user.getLocalizedLocation(lang);

      String formatVal(String? val) => (val == null || val.isEmpty) ? "Not provided" : val;

      final messageBuffer = StringBuffer();
      messageBuffer.writeln("New Subscription Support Request");
      if (planName != null) {
        messageBuffer.writeln("Selected Plan: $planName");
      }
      messageBuffer.writeln("");
      messageBuffer.writeln("User Information");
      messageBuffer.writeln("----------------");
      messageBuffer.writeln("UID: ${user.uid}");
      messageBuffer.writeln("Name: ${formatVal(user.name)}");
      messageBuffer.writeln("Email: ${formatVal(user.email)}");
      messageBuffer.writeln("Phone: ${formatVal(user.phone)}");
      messageBuffer.writeln("Subscription Status: $status");
      if (expiry != null) {
        messageBuffer.writeln("Expires: ${expiry.toDate().toString().split(' ')[0]}");
      }
      messageBuffer.writeln("Location: ${formatVal(location)}");
      messageBuffer.writeln("Role: ${user.role}");
      messageBuffer.writeln("");
      messageBuffer.writeln("User Message:");
      messageBuffer.writeln("\"I am interested in the ${planName ?? 'subscription'} plan. Please provide details.\"");

      final message = Uri.encodeComponent(messageBuffer.toString());
      
      // Format admin phone
      String cleanPhone = adminPhone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.length == 10 && cleanPhone.startsWith('0')) {
        cleanPhone = '213${cleanPhone.substring(1)}';
      } else if (cleanPhone.length == 9 && !cleanPhone.startsWith('213')) {
        cleanPhone = '213$cleanPhone';
      }

      final url = Uri.parse('https://wa.me/$cleanPhone?text=$message');

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        final fallbackUrl = Uri.parse("whatsapp://send?phone=$cleanPhone&text=$message");
        if (await canLaunchUrl(fallbackUrl)) {
          await launchUrl(fallbackUrl);
        } else {
          if (mounted) {
            AppSnackBar.showError(context, lang.tr('cannot_launch_whatsapp', category: 'profile'));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, '${lang.tr('error_occurred', category: 'common')}: $e');
      }
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
        userId: user.uid,
        email: user.email,
        code: code,
      );

      if (mounted) {
        AppSnackBar.showSuccess(context, lang.tr('subscription_activated_success', category: 'profile'));
      }

      try {
        await auth.refreshCurrentUser();
        if (mounted) Navigator.pop(context);
      } catch (_) {}

      _codeCtrl.clear();
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, lang.tr('subscription_failed', category: 'profile'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPlanDetails(int months, LanguageProvider lang, bool isDark) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111C44) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stars_rounded, color: kPrimaryColor, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              lang.tr('price_$months', category: 'profile'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: kPrimaryColor,
                fontFamily: 'Exo2',
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _openWhatsApp(planName: '${lang.tr('month_$months', category: 'profile')} - ${lang.tr('price_$months', category: 'profile')}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: kPrimaryColor.withOpacity(0.4),
                ),
                child: Text(
                  lang.tr('contact_admin', category: 'profile'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'Exo2'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final lang = context.watch<LanguageProvider>();
    final user = auth.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (user != null && user.isGuest) {
      return Scaffold(
        appBar: AppBar(title: Text(lang.tr('mySubscription', category: 'common'))),
        body: Center(child: Text(lang.tr('permission_error', category: 'common'))),
      );
    }

    final expiry = user?.subscriptionExpiresAt ?? user?.subscriptionExpiry;
    final isAdmin = user?.isAdmin ?? false;
    final isActive = isAdmin || ((user?.subscriptionActive ?? false) &&
        expiry != null &&
        expiry.toDate().isAfter(DateTime.now()));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1437) : kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : kSecondaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.tr('mySubscription', category: 'common'),
          style: TextStyle(
            color: isDark ? Colors.white : kSecondaryColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            fontFamily: 'Exo2',
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _animationController,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: Column(
            children: [
              _buildStatusCard(isActive, expiry, lang, isDark, isAdmin),
              const SizedBox(height: 32),
              if (!isAdmin) ...[
                if (!isActive) ...[
                  _buildSectionTitle(lang.tr('subscription_options', category: 'profile'), isDark),
                  _buildCompactPlans(lang, isDark),
                  const SizedBox(height: 32),
                  _buildSectionTitle(lang.tr('how_it_works', category: 'profile'), isDark),
                  _buildHowItWorksCard(lang, isDark),
                  const SizedBox(height: 32),
                  _buildActionCard(lang, isDark),
                  const SizedBox(height: 32),
                  _buildCodeCard(lang, isDark),
                ] else ...[
                  _buildSectionTitle(lang.tr('subscription_active_title', category: 'profile'), isDark),
                  _buildActiveSubscriptionInfo(lang, isDark),
                ],
              ] else 
                _buildAdminInfoCard(lang, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 4, bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          fontFamily: 'Exo2',
          color: isDark ? Colors.white.withOpacity(0.9) : kSecondaryColor,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isActive, dynamic expiry, LanguageProvider lang, bool isDark, bool isAdmin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111C44) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.tr('subscription_status', category: 'profile'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : kTextSecondary,
                      fontFamily: 'Exo2',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isActive ? lang.tr('active', category: 'profile') : lang.tr('inactive', category: 'profile'),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: isActive ? kSuccessColor : kDangerColor,
                      fontFamily: 'Exo2',
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (isActive ? kSuccessColor : kDangerColor).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isActive ? Icons.verified_rounded : Icons.lock_clock_rounded,
                  color: isActive ? kSuccessColor : kDangerColor,
                  size: 36,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : kBackgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.event_available_rounded, size: 18, color: isDark ? Colors.white38 : kTextSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isAdmin 
                        ? lang.tr('admin_lifetime_access', category: 'profile')
                        : (expiry != null
                            ? lang.trParams('expires', category: 'profile', params: {'date': expiry.toDate().toString().split(" ")[0]})
                            : lang.tr('no_active_subscription', category: 'profile')),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : kSecondaryColor,
                      fontFamily: 'Exo2',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPlans(LanguageProvider lang, bool isDark) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: 6,
        itemBuilder: (context, index) {
          int months = index + 1;
          bool isPopular = months == 3;
          return GestureDetector(
            onTap: () => _showPlanDetails(months, lang, isDark),
            child: Container(
              width: 150,
              margin: EdgeInsets.only(right: 16, left: index == 0 ? 4 : 0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111C44) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: isPopular ? Border.all(color: kPrimaryColor, width: 2) : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  if (isPopular)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: const BoxDecoration(
                          color: kPrimaryColor,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(22),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'BEST',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang.tr('month_$months', category: 'profile'),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            fontFamily: 'Exo2',
                            color: isDark ? Colors.white : kSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lang.tr('price_$months', category: 'profile'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: kPrimaryColor,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Exo2',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHowItWorksCard(LanguageProvider lang, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111C44) : Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          _buildStepItem(lang.tr('step_1', category: 'profile'), Icons.touch_app_rounded, isDark),
          _buildStepItem(lang.tr('step_2', category: 'profile'), Icons.wechat_rounded, isDark),
          _buildStepItem(lang.tr('step_3', category: 'profile'), Icons.account_balance_wallet_rounded, isDark),
          _buildStepItem(lang.tr('step_4', category: 'profile'), Icons.vpn_key_rounded, isDark),
          _buildStepItem(lang.tr('step_5', category: 'profile'), Icons.check_circle_rounded, isDark, isLast: true),
        ],
      ),
    );
  }

  Widget _buildStepItem(String text, IconData icon, bool isDark, {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: kPrimaryColor),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: kPrimaryColor.withOpacity(0.1),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : kSecondaryColor.withOpacity(0.85),
                  height: 1.5,
                  fontFamily: 'Exo2',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(LanguageProvider lang, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kPrimaryColor, Color(0xFF2B52C3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            lang.tr('need_subscription', category: 'profile'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, fontFamily: 'Exo2', color: Colors.white, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            lang.tr('contact_admin_instructions', category: 'profile'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.85), fontFamily: 'Exo2', height: 1.6),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _openWhatsApp();
              },
              icon: const Icon(FontAwesomeIcons.whatsapp, size: 20),
              label: Text(lang.tr('contact_admin', category: 'profile')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: kPrimaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'Exo2'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard(LanguageProvider lang, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111C44) : Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.tr('activate_with_code', category: 'profile'),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, fontFamily: 'Exo2', color: isDark ? Colors.white : kSecondaryColor, letterSpacing: -0.5),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeCtrl,
            style: TextStyle(color: isDark ? Colors.white : kSecondaryColor, fontFamily: 'Exo2', fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: lang.tr('enter_code_hint', category: 'profile'),
              hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.grey.shade400, fontFamily: 'Exo2'),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.04) : kBackgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(20),
              prefixIcon: Icon(Icons.lock_rounded, size: 20, color: kPrimaryColor.withOpacity(0.5)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : () {
                HapticFeedback.heavyImpact();
                _applyCode();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 4,
                shadowColor: kPrimaryColor.withOpacity(0.4),
              ),
              child: _loading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                  : Text(
                      lang.tr('activate_subscription', category: 'profile'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'Exo2'),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSubscriptionInfo(LanguageProvider lang, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111C44) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kSuccessColor.withOpacity(0.2), width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: kSuccessColor.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: kSuccessColor, size: 48),
          ),
          const SizedBox(height: 24),
          Text(
            lang.tr('subscription_active_desc', category: 'profile'),
            style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : kSecondaryColor, height: 1.6, fontFamily: 'Exo2'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminInfoCard(LanguageProvider lang, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111C44) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kPrimaryColor.withOpacity(0.2), width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.admin_panel_settings_rounded, color: kPrimaryColor, size: 48),
          ),
          const SizedBox(height: 24),
          Text(
            lang.tr('admin_unlimited_access', category: 'profile'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Exo2', color: isDark ? Colors.white : kSecondaryColor, letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            lang.tr('admin_subscription_desc', category: 'profile'),
            style: TextStyle(fontSize: 15, color: isDark ? Colors.white60 : kTextSecondary, height: 1.6, fontFamily: 'Exo2'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
