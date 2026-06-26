import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/screens/auth/constants.dart';
import 'package:service_app/utils/ui_widgets.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isResending = false;
  Timer? _timer;
  Timer? _cooldownTimer;
  int _secondsRemaining = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    
    // Auto-check verification every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkVerification();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _cooldownTimer?.cancel();
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining == 0) {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  Future<void> _checkVerification() async {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    await authVM.checkEmailVerificationStatus();
  }

  Future<void> _resendVerification() async {
    if (!_canResend) return;

    setState(() => _isResending = true);
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    try {
      await authVM.resendVerificationEmail();
      if (mounted) {
        AppSnackBar.showSuccess(context, lang.tr('verification_email_sent', category: 'auth'));
        _startResendTimer();
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final authVM = Provider.of<AuthViewModel>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: kLightBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                size: 100,
                color: kPrimaryBlue,
              ),
              const SizedBox(height: 40),
              Text(
                lang.tr('verify_email_title', category: 'auth'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kDarkTextColor,
                  fontFamily: kAppFont,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                lang.trParams('verify_email_desc', category: 'auth', params: {
                  'email': authVM.currentUser?.email ?? ''
                }),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: kMutedTextColor,
                  fontFamily: kAppFont,
                ),
              ),
              const SizedBox(height: 40),
              if (_isResending)
                const CircularProgressIndicator(color: kPrimaryBlue)
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canResend ? _resendVerification : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _canResend 
                        ? lang.tr('resend_email', category: 'auth')
                        : lang.trParams('resend_cooldown', category: 'auth', params: {'seconds': _secondsRemaining.toString()}),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => authVM.logout(),
                child: Text(
                  lang.tr('logout', category: 'common'),
                  style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _checkVerification,
                child: Text(
                  lang.tr('refresh_status', category: 'auth'),
                  style: const TextStyle(color: kPrimaryBlue, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
