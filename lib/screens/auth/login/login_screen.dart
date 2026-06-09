import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/screens/auth/constants.dart';
import 'package:service_app/screens/auth/forget_password_screen.dart';
import 'package:service_app/screens/auth/register/register_screen.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/screens/navigator_bottom.dart';

// --- Aesthetic Input Decoration Function ---
InputDecoration buildAestheticInputDecoration(
    String hint, LanguageProvider lang) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: kMutedTextColor, fontFamily: kAppFont),
    filled: true,
    fillColor: kInputFillColor.withOpacity(0.5),
    contentPadding: const EdgeInsets.symmetric(
      vertical: 16.0,
      horizontal: 20.0,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kPrimaryBlue, width: 2),
    ),
  );
}

// =================================================================
// 🚀 Login Screen
// =================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _getErrorMessage(String error, LanguageProvider lang) {
    final errorLower = error.toLowerCase();

    if (errorLower.contains('invalid-email') ||
        errorLower.contains('invalid email')) {
      return lang.tr('error_invalid_credentials', category: 'auth');
    } else if (errorLower.contains('user-not-found') ||
        errorLower.contains('no user')) {
      return lang.tr('error_user_not_found', category: 'auth');
    } else if (errorLower.contains('wrong-password') ||
        errorLower.contains('incorrect password')) {
      return lang.tr('error_wrong_password', category: 'auth');
    } else if (errorLower.contains('user-disabled') ||
        errorLower.contains('disabled')) {
      return lang.tr('error_account_disabled', category: 'auth');
    } else if (errorLower.contains('too-many-requests')) {
      return lang.tr('error_too_many_attempts', category: 'auth');
    } else {
      return error;
    }
  }

  Future<void> _submitLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final lang = Provider.of<LanguageProvider>(context, listen: false);

      try {
        final user = await authViewModel.login(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (!mounted) return;

        if (user != null) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                      child:
                          Text(lang.tr('sign_in_success', category: 'auth'))),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );

          // Navigate immediately to home
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const NavigatorBottom()),
            (route) => false,
          );
        } else {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(authViewModel.error ??
                          lang.tr('sign_in_failed', category: 'auth'))),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        final errorMessage = _getErrorMessage(e.toString(), lang);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    try {
      final user = await authViewModel.signInWithGoogle();

      if (!mounted) return;

      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                        lang.tr('google_sign_in_success', category: 'auth'))),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navigate to home
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const NavigatorBottom()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(authViewModel.error ??
                        lang.tr('google_sign_in_failed', category: 'auth'))),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                  child:
                      Text(lang.tr('google_sign_in_failed', category: 'auth'))),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _signInWithApple() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    try {
      final user = await authViewModel.signInWithApple();

      if (!mounted) return;

      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                        lang.tr('apple_sign_in_success', category: 'auth'))),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navigate to home
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const NavigatorBottom()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(authViewModel.error ??
                        lang.tr('apple_sign_in_failed', category: 'auth'))),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                  child:
                      Text(lang.tr('apple_sign_in_failed', category: 'auth'))),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildTopBar(LanguageProvider lang) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(
          CupertinoIcons.arrow_left,
          color: kMutedTextColor,
          size: 24,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildLogo(LanguageProvider lang) {
    return Center(
      child: Column(
        children: [
          Image.asset('assets/images/logo.png', width: 150, height: 150),
          const SizedBox(height: 10),
          Text(
            lang.tr('app_name', category: 'auth'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: kAppFont,
              color: kDarkTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(LanguageProvider lang) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 5,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                lang.tr('welcome_back', category: 'auth'),
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: kDarkTextColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  fontFamily: kAppFont,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lang.tr('login_to_account', category: 'auth'),
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: kMutedTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  fontFamily: kAppFont,
                ),
              ),
              const SizedBox(height: 30),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildEmailField(lang),
                    const SizedBox(height: 16),
                    _buildPasswordField(lang),
                    _buildForgotPasswordLink(lang),
                    const SizedBox(height: 24),
                    _LoginButton(
                      isLoading: authViewModel.isLoading,
                      onPressed: _submitLogin,
                      lang: lang,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _OrDivider(lang: lang),
              const SizedBox(height: 20),
              _SocialSignInRow(
                onGooglePressed: _signInWithGoogle,
                onApplePressed: _signInWithApple,
                isLoading: authViewModel.isLoading,
                lang: lang,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmailField(LanguageProvider lang) {
    return TextFormField(
      controller: _emailController,
      decoration: buildAestheticInputDecoration(
        lang.tr('email_hint_login', category: 'auth'),
        lang,
      ),
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(fontFamily: kAppFont, color: kDarkTextColor),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return lang.tr('validation_email_required', category: 'auth');
        }
        if (!value.contains('@') || !value.contains('.')) {
          return lang.tr('validation_email_invalid', category: 'auth');
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(LanguageProvider lang) {
    return TextFormField(
      controller: _passwordController,
      decoration: buildAestheticInputDecoration(
        lang.tr('password_hint', category: 'auth'),
        lang,
      ),
      obscureText: true,
      style: const TextStyle(fontFamily: kAppFont, color: kDarkTextColor),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return lang.tr('validation_password_required', category: 'auth');
        }
        if (value.length < 6) {
          return lang.tr('validation_password_min_length', category: 'auth');
        }
        return null;
      },
    );
  }

  Widget _buildForgotPasswordLink(LanguageProvider lang) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ForgotPasswordScreen(),
            ),
          );
        },
        child: Text(
          lang.tr("forgot_password", category: 'auth'),
          style: const TextStyle(
            fontFamily: kAppFont,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: kPrimaryBlue,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: kLightBackgroundColor,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopBar(lang),
                    const SizedBox(height: 60),
                    _buildLogo(lang),
                    const SizedBox(height: 40),
                    _buildLoginForm(lang),
                    const SizedBox(height: 40),
                    _SignUpLink(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterPage(),
                          ),
                        );
                      },
                      lang: lang,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- Extracted & Reusable Widgets ---

class _LoginButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final LanguageProvider lang;

  const _LoginButton({
    required this.isLoading,
    required this.onPressed,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryBlue,
          foregroundColor: Colors.white,
          elevation: 5,
          shadowColor: kPrimaryBlue.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(
                    Colors.white.withOpacity(0.9),
                  ),
                ),
              )
            : Text(
                lang.tr('sign_in', category: 'auth'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  fontFamily: kAppFont,
                ),
              ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  final LanguageProvider lang;

  const _OrDivider({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(
          child: Divider(color: kBorderColor, height: 1, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            lang.tr('or', category: 'auth'),
            style: TextStyle(
              color: kMutedTextColor.withOpacity(0.8),
              fontSize: 14,
              fontFamily: kAppFont,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: kBorderColor, height: 1, thickness: 1),
        ),
      ],
    );
  }
}

class _SocialSignInRow extends StatelessWidget {
  final VoidCallback onGooglePressed;
  final VoidCallback onApplePressed;
  final bool isLoading;
  final LanguageProvider lang;

  const _SocialSignInRow({
    required this.onGooglePressed,
    required this.onApplePressed,
    required this.isLoading,
    required this.lang,
  });

  Widget _buildAestheticSocialIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorderColor.withOpacity(0.7)),
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  )
                : Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAestheticSocialIcon(
          icon: FontAwesomeIcons.google,
          color: Colors.red,
          onPressed: onGooglePressed,
        ),
        const SizedBox(width: 12),
        _buildAestheticSocialIcon(
          icon: FontAwesomeIcons.apple,
          color: kDarkTextColor,
          onPressed: onApplePressed,
        ),
      ],
    );
  }
}

class _SignUpLink extends StatelessWidget {
  final VoidCallback onTap;
  final LanguageProvider lang;

  const _SignUpLink({
    required this.onTap,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              color: kMutedTextColor,
              fontFamily: kAppFont,
              fontSize: 15,
            ),
            children: [
              TextSpan(
                text: lang.tr('dont_have_account', category: 'auth'),
              ),
              TextSpan(
                text: lang.tr('sign_up_now', category: 'auth'),
                style: const TextStyle(
                  color: kPrimaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
