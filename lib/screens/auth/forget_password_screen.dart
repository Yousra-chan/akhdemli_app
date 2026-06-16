import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/screens/auth/constants.dart';
import 'package:service_app/services/auth_service.dart';
import 'package:service_app/utils/ui_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  String _email = '';
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  InputDecoration _inputDecoration(String label, LanguageProvider lang) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: kMutedTextColor,
        fontFamily: kAppFont,
        fontSize: 14,
      ),
      hintText: lang.tr('email_hint', category: 'auth'),
      hintStyle: TextStyle(
        color: kMutedTextColor.withOpacity(0.5),
        fontFamily: kAppFont,
        fontSize: 14,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      filled: true,
      fillColor: Colors.transparent,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: kBorderColor, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: kPrimaryBlue, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: kBorderColor, width: 1.0),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      errorText: _errorMessage,
    );
  }

  void _submitReset() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _successMessage = null;
      });

      final lang = Provider.of<LanguageProvider>(context, listen: false);

      try {
        await _authService.sendPasswordResetEmail(_email);

        final successMessage = lang.trParams(
          'reset_link_sent_message',
          category: 'auth',
          params: {'email': _email},
        );

        setState(() {
          _isLoading = false;
          _successMessage = successMessage;
        });

        AppSnackBar.showSuccess(context, successMessage);

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } catch (e) {
        String errorMessage = _getErrorMessage(e.toString(), lang);

        setState(() {
          _isLoading = false;
          _errorMessage = errorMessage;
        });

        AppSnackBar.showError(context, errorMessage);
      }
    }
  }

  String _getErrorMessage(String error, LanguageProvider lang) {
    if (error.contains('user-not-found') || error.contains('no user')) {
      return lang.tr('error_email_not_found', category: 'auth');
    } else if (error.contains('too-many-requests')) {
      return lang.tr('error_too_many_requests', category: 'auth');
    } else if (error.contains('network') || error.contains('connection')) {
      return lang.tr('error_network', category: 'auth');
    } else {
      return lang.tr('error_generic', category: 'auth');
    }
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: kLightBackgroundColor,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Back Button (Top Left)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      icon: const Icon(
                        CupertinoIcons.arrow_left,
                        color: kMutedTextColor,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Title Section
                  Text(
                    lang.tr('forgot_password_title', category: 'auth'),
                    style: const TextStyle(
                      color: kPrimaryBlue,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      fontFamily: kAppFont,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      lang.tr('forgot_password_subtitle', category: 'auth'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: kMutedTextColor.withOpacity(0.9),
                        fontSize: 15,
                        fontFamily: kAppFont,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // --- Forgot Password Form ---
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          decoration: _inputDecoration(
                            lang.tr('email_label', category: 'auth'),
                            lang,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            fontFamily: kAppFont,
                            color: kDarkTextColor,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return lang.tr('validation_email_required',
                                  category: 'auth');
                            }
                            if (!value.contains('@') || !value.contains('.')) {
                              return lang.tr('validation_email_invalid',
                                  category: 'auth');
                            }
                            return null;
                          },
                          onChanged: (_) => _clearError(),
                          onSaved: (value) => _email = value!.trim(),
                        ),
                        const SizedBox(height: 32),

                        // Success Message
                        if (_successMessage != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _successMessage!,
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontFamily: kAppFont,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (_successMessage != null) const SizedBox(height: 16),

                        // Reset Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitReset,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  )
                                : Text(
                                    lang.tr('send_reset_link',
                                        category: 'auth'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      fontFamily: kAppFont,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Back to Login Link
                        TextButton(
                          onPressed:
                              _isLoading ? null : () => Navigator.pop(context),
                          child: Text(
                            lang.tr('back_to_login', category: 'auth'),
                            style: const TextStyle(
                              color: kPrimaryBlue,
                              fontFamily: kAppFont,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
