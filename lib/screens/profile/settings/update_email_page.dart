import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:service_app/screens/profile/profile_constants.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:provider/provider.dart';
import 'package:service_app/utils/ui_widgets.dart';

class UpdateEmailPage extends StatefulWidget {
  const UpdateEmailPage({super.key});

  @override
  State<UpdateEmailPage> createState() => _UpdateEmailPageState();
}

class _UpdateEmailPageState extends State<UpdateEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _confirmEmailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _newEmailController.dispose();
    _confirmEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _updateEmail(LanguageProvider languageProvider) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _passwordController.text,
      );
      await user.reauthenticateWithCredential(credential);

      // Update email
      await user.verifyBeforeUpdateEmail(_newEmailController.text);

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          languageProvider.tr('updateEmailSuccess', category: 'profile'),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage =
      languageProvider.tr('failedUpdateEmail', category: 'profile');
      if (e.code == 'wrong-password') {
        errorMessage =
            languageProvider.tr('wrongPassword', category: 'profile');
      }

      if (mounted) {
        AppSnackBar.showError(context, errorMessage);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          '${languageProvider.tr('failedUpdateEmail', category: 'profile')}: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateEmail(String? value, LanguageProvider lang) {
    if (value == null || value.isEmpty) {
      return lang.tr('validation_email_required', category: 'auth');
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return lang.tr('validation_email_invalid', category: 'auth');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // App Bar
                _buildAppBar(context, languageProvider),

                // Form
                Container(
                  margin:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // New Email Field
                        _buildEmailField(
                          controller: _newEmailController,
                          label: languageProvider.tr('newEmail',
                              category: 'profile'),
                          validator: (val) => _validateEmail(val, languageProvider),
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),

                        // Confirm Email Field
                        _buildEmailField(
                          controller: _confirmEmailController,
                          label: languageProvider.tr('confirmEmail',
                              category: 'profile'),
                          validator: (value) {
                            final validation = _validateEmail(value, languageProvider);
                            if (validation != null) return validation;
                            if (value != _newEmailController.text) {
                              return languageProvider.tr('emailMismatch',
                                  category: 'profile');
                            }
                            return null;
                          },
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),

                        // Password Field
                        _buildPasswordField(
                          controller: _passwordController,
                          label: languageProvider.tr('currentPassword',
                              category: 'profile'),
                          obscureText: _obscurePassword,
                          onToggle: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                          languageProvider: languageProvider,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Update Email Button
                _buildUpdateButton(languageProvider),

                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(color: theme.primaryColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, LanguageProvider languageProvider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 15,
      ),
      color: theme.cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_back,
                color: theme.textTheme.titleLarge?.color ?? Colors.black87,
                size: 24,
              ),
            ),
          ),
          Text(
            languageProvider.tr('updateEmail', category: 'profile'),
            style: TextStyle(
              color: theme.textTheme.titleLarge?.color ?? Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Exo2',
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildEmailField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white54 : kMutedTextColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.email_outlined,
                color: theme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  validator: validator,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    required LanguageProvider languageProvider,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white54 : kMutedTextColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                color: theme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  obscureText: obscureText,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility : Icons.visibility_off,
                        color: isDark ? Colors.white54 : kMutedTextColor,
                        size: 20,
                      ),
                      onPressed: onToggle,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return languageProvider.tr('validation_password_required', category: 'auth');
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateButton(LanguageProvider languageProvider) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _updateEmail(languageProvider),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Text(
          languageProvider.tr('updateEmail', category: 'profile'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}