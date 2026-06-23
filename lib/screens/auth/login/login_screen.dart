import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/screens/auth/constants.dart';
import 'package:service_app/screens/auth/forget_password_screen.dart';
import 'package:service_app/screens/auth/register/register_screen.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/auth_wrapper.dart';
import 'package:service_app/screens/navigator_bottom.dart';
import 'package:service_app/utils/ui_widgets.dart';

// --- Aesthetic Input Decoration Function ---
InputDecoration buildAestheticInputDecoration(
    String hint, LanguageProvider lang, BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: isDark ? Colors.white38 : kMutedTextColor, fontFamily: kAppFont),
    filled: true,
    fillColor: isDark ? Colors.white.withOpacity(0.05) : kInputFillColor.withOpacity(0.5),
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
      borderSide: BorderSide(color: theme.primaryColor, width: 2),
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
          AppSnackBar.showSuccess(
              context, lang.tr('sign_in_success', category: 'auth'));

          // Reset to AuthWrapper with a smooth transition
          Navigator.pushAndRemoveUntil(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 600),
            ),
            (route) => false,
          );
        } else {
          final errorMessage = authViewModel.error ??
              lang.tr('sign_in_failed', category: 'auth');
          AppSnackBar.showError(context, _getErrorMessage(errorMessage, lang));
        }
      } catch (e) {
        if (!mounted) return;
        AppSnackBar.showError(context, _getErrorMessage(e.toString(), lang));
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
        AppSnackBar.showSuccess(
            context, lang.tr('google_sign_in_success', category: 'auth'));

        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
          (route) => false,
        );
      } else {
        final errorMessage = authViewModel.error ??
            lang.tr('google_sign_in_failed', category: 'auth');
        AppSnackBar.showError(context, errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(
          context, lang.tr('google_sign_in_failed', category: 'auth'));
    }
  }

  Future<void> _signInWithApple() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    try {
      final user = await authViewModel.signInWithApple();

      if (!mounted) return;

      if (user != null) {
        AppSnackBar.showSuccess(
            context, lang.tr('apple_sign_in_success', category: 'auth'));

        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
          (route) => false,
        );
      } else {
        final errorMessage = authViewModel.error ??
            lang.tr('apple_sign_in_failed', category: 'auth');
        AppSnackBar.showError(context, errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(
          context, lang.tr('apple_sign_in_failed', category: 'auth'));
    }
  }

  Widget _buildTopBar(LanguageProvider lang) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
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
    final theme = Theme.of(context);
    return Center(
      child: Column(
        children: [
          Image.asset('assets/images/logo.png', width: 150, height: 150),
          const SizedBox(height: 10),
          Text(
            lang.tr('app_name', category: 'auth'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: kAppFont,
              color: theme.textTheme.titleLarge?.color ?? kDarkTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(LanguageProvider lang) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
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
                textAlign: TextAlign.start,
                style: TextStyle(
                  color: theme.textTheme.titleLarge?.color ?? kDarkTextColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  fontFamily: kAppFont,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lang.tr('login_to_account', category: 'auth'),
                textAlign: TextAlign.start,
                style: TextStyle(
                  color: isDark ? Colors.white54 : kMutedTextColor,
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
    final theme = Theme.of(context);
    return TextFormField(
      controller: _emailController,
      decoration: buildAestheticInputDecoration(
        lang.tr('email_hint_login', category: 'auth'),
        lang,
        context,
      ),
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(fontFamily: kAppFont, color: theme.textTheme.bodyLarge?.color),
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
    final theme = Theme.of(context);
    return TextFormField(
      controller: _passwordController,
      decoration: buildAestheticInputDecoration(
        lang.tr('password_hint', category: 'auth'),
        lang,
        context,
      ),
      obscureText: true,
      style: TextStyle(fontFamily: kAppFont, color: theme.textTheme.bodyLarge?.color),
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
    final theme = Theme.of(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
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
          style: TextStyle(
            fontFamily: kAppFont,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.primaryColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<LanguageProvider>(
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
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
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => const RegisterPage(),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(1, 0),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeInOutCubic,
                                )),
                                child: child,
                              );
                            },
                            transitionDuration: const Duration(milliseconds: 500),
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
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 5,
          shadowColor: theme.primaryColor.withOpacity(0.5),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: <Widget>[
        Expanded(
          child: Divider(color: isDark ? Colors.white10 : kBorderColor, height: 1, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            lang.tr('or', category: 'auth'),
            style: TextStyle(
              color: isDark ? Colors.white38 : kMutedTextColor.withOpacity(0.8),
              fontSize: 14,
              fontFamily: kAppFont,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: isDark ? Colors.white10 : kBorderColor, height: 1, thickness: 1),
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

  Widget _buildAestheticSocialIcon(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
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
                : Icon(icon, color: isDark && icon == FontAwesomeIcons.apple ? Colors.white : color, size: 24),
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
          context,
          icon: FontAwesomeIcons.google,
          color: Colors.red,
          onPressed: onGooglePressed,
        ),
        const SizedBox(width: 12),
        _buildAestheticSocialIcon(
          context,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              color: isDark ? Colors.white54 : kMutedTextColor,
              fontFamily: kAppFont,
              fontSize: 15,
            ),
            children: [
              TextSpan(
                text: lang.tr('dont_have_account', category: 'auth'),
              ),
              TextSpan(
                text: lang.tr('sign_up_now', category: 'auth'),
                style: TextStyle(
                  color: theme.primaryColor,
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
