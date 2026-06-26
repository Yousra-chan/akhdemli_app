import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:service_app/screens/profile/profile_constants.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:provider/provider.dart';
import 'package:service_app/utils/ui_widgets.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword(LanguageProvider languageProvider) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception(lang.tr('user_not_authenticated', category: 'profile'));

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      // Re-authenticate user before sensitive operation
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(_newPasswordController.text);

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          languageProvider.tr('changePasswordSuccess', category: 'profile'),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage =
          languageProvider.tr('failedChangePassword', category: 'profile');
      if (e.code == 'wrong-password') {
        errorMessage =
            languageProvider.tr('wrongPassword', category: 'profile');
      } else if (e.code == 'weak-password') {
        errorMessage = languageProvider.tr('weakPassword', category: 'profile');
      }

      if (mounted) {
        AppSnackBar.showError(context, errorMessage);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          '${languageProvider.tr('failedChangePassword', category: 'profile')}: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validatePassword(String? value, LanguageProvider lang) {
    if (value == null || value.isEmpty) {
      return lang.tr('validation_password_required', category: 'auth');
    }
    if (value.length < 6) {
      return lang.tr('validation_password_min_length', category: 'auth');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: kLightBackgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // Simple App Bar
                _buildAppBar(context, languageProvider),

                // Form Section
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  decoration: BoxDecoration(
                    color: kCardBackgroundColor,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: kSoftShadowColor.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildPasswordFieldWidget(
                          controller: _currentPasswordController,
                          label: languageProvider.tr('currentPassword',
                              category: 'profile'),
                          obscureText: _obscureCurrentPassword,
                          onToggle: () => setState(() =>
                              _obscureCurrentPassword =
                                  !_obscureCurrentPassword),
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        _buildPasswordFieldWidget(
                          controller: _newPasswordController,
                          label: languageProvider.tr('newPassword',
                              category: 'profile'),
                          obscureText: _obscureNewPassword,
                          onToggle: () => setState(
                              () => _obscureNewPassword = !_obscureNewPassword),
                          validator: (value) => _validatePassword(value, languageProvider),
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        _buildPasswordFieldWidget(
                          controller: _confirmPasswordController,
                          label: languageProvider.tr('confirmNewPassword',
                              category: 'profile'),
                          obscureText: _obscureConfirmPassword,
                          onToggle: () => setState(() =>
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword),
                          validator: (value) {
                            final validation = _validatePassword(value, languageProvider);
                            if (validation != null) return validation;
                            if (value != _newPasswordController.text) {
                              return languageProvider.tr('passwordsDoNotMatch',
                                  category: 'profile');
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Password Requirements
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kPrimaryBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kPrimaryBlue.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageProvider.tr('passwordRequirements',
                              category: 'profile'),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: kDarkTextColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildRequirementItem(
                          languageProvider.tr('passwordLength',
                              category: 'profile'),
                        ),
                        const SizedBox(height: 4),
                        _buildRequirementItem(
                          languageProvider.tr('passwordChars',
                              category: 'profile'),
                        ),
                        const SizedBox(height: 4),
                        _buildRequirementItem(
                          languageProvider.tr('passwordCommon',
                              category: 'profile'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Change Password Button
                _buildChangePasswordButton(languageProvider),

                const SizedBox(height: 40),
              ],
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: kPrimaryBlue),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, LanguageProvider languageProvider) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 15,
      ),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kLightBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: kDarkTextColor,
                size: 24,
              ),
            ),
          ),
          Text(
            languageProvider.tr('changePassword', category: 'profile'),
            style: const TextStyle(
              color: kDarkTextColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Exo2',
            ),
          ),
          Container(
            width: 40,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordFieldWidget({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: kMutedTextColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                color: kPrimaryBlue,
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
                        color: kMutedTextColor,
                        size: 20,
                      ),
                      onPressed: onToggle,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  style: const TextStyle(
                    color: kDarkTextColor,
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

  Widget _buildRequirementItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 6),
          child: Icon(
            Icons.circle,
            size: 6,
            color: kMutedTextColor,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: kMutedTextColor,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChangePasswordButton(LanguageProvider languageProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _changePassword(languageProvider),
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryBlue,
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
                languageProvider.tr('changePassword', category: 'profile'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
