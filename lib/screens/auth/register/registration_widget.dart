import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:provider/provider.dart';

const Color kPrimaryBlue = Color(0xFF143EAE);
const Color kLightBackgroundColor = Color(0xFFF0F4F8);
const Color kDarkTextColor = Color(0xFF1E293B);
const Color kMutedTextColor = Color(0xFF64748B);
const String kAppFont = 'Roboto';
const double kHorizontalPadding = 24.0;
const Color kBorderColor = Color(0xFFE0E0E0);
const Color kInputFillColor = Color(0xFFE9ECEF);

InputDecoration buildInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: kMutedTextColor),
    filled: true,
    fillColor: kLightBackgroundColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kPrimaryBlue, width: 2),
    ),
  );
}

class RegisterButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  
  const RegisterButton({
    required this.isLoading,
    this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 5,
          shadowColor: primaryColor.withOpacity(0.5),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Text(
                lang.tr('register', category: 'auth'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontFamily: kAppFont,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final theme = Theme.of(context);
    
    return Row(
      children: <Widget>[
        Expanded(
          child: Divider(color: theme.dividerColor, height: 1, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            lang.tr('or', category: 'auth'),
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color ?? kMutedTextColor,
              fontSize: 14,
              fontFamily: kAppFont,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: theme.dividerColor, height: 1, thickness: 1),
        ),
      ],
    );
  }
}

class SocialSignInRow extends StatelessWidget {
  final VoidCallback? onGooglePressed;
  final VoidCallback? onApplePressed;
  final bool isLoading;

  const SocialSignInRow({
    this.onGooglePressed,
    this.onApplePressed,
    required this.isLoading,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _buildSocialButton(
            context,
            icon: FontAwesomeIcons.google,
            onPressed: onGooglePressed,
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSocialButton(
            context,
            icon: FontAwesomeIcons.apple,
            onPressed: onApplePressed,
            color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1.0,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: theme.cardColor,
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(12),
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
}

class SignInLink extends StatelessWidget {
  final VoidCallback onTap;
  const SignInLink({required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color ?? kMutedTextColor,
              fontFamily: kAppFont,
              fontSize: 15,
            ),
            children: [
              TextSpan(
                text: lang.tr('already_have_account', category: 'auth'),
              ),
              TextSpan(
                text: " " + lang.tr('sign_in_now', category: 'auth'),
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

class RoleOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const RoleOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
            ? primaryColor.withOpacity(0.1) 
            : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : (theme.textTheme.bodySmall?.color ?? kMutedTextColor),
              size: 24,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontFamily: kAppFont,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? primaryColor : (theme.textTheme.titleMedium?.color ?? kDarkTextColor),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: kAppFont,
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color ?? kMutedTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

