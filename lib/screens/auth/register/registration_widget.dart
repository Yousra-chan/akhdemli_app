import 'package:flutter/material.dart';

const Color kPrimaryBlue = Color(0xFF143EAE);
const Color kLightBackgroundColor = Color(0xFFF0F4F8);
const Color kDarkTextColor = Color(0xFF1E293B);
const Color kMutedTextColor = Color(0xFF64748B);
const String kAppFont = 'Roboto';
const double kHorizontalPadding = 24.0;
const Color kBorderColor = Color(0xFFE0E0E0);
const Color kInputFillColor = Color(0xFFE9ECEF); // Add this line

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
  final VoidCallback onPressed;
  const RegisterButton({
    required this.isLoading,
    required this.onPressed,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimaryBlue,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          : const Text(
              'Register',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontFamily: kAppFont,
              ),
            ),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text("OR", style: TextStyle(color: kMutedTextColor)),
    );
  }
}

class SocialSignInRow extends StatelessWidget {
  final VoidCallback onGooglePressed;
  final VoidCallback onApplePressed;
  final bool isLoading;

  const SocialSignInRow({
    required this.onGooglePressed,
    required this.onApplePressed,
    required this.isLoading,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildSocialButton(
            icon: Icons.g_translate, // Google icon
            onPressed: onGooglePressed,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSocialButton(
            icon: Icons.apple,
            onPressed: onApplePressed,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: isLoading ? null : onPressed,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          border: Border.all(color: kBorderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon),
      ),
    );
  }
}

class SignInLink extends StatelessWidget {
  final VoidCallback onTap;
  const SignInLink({required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Text(
        'Already have an account? Sign in',
        style: TextStyle(color: kPrimaryBlue),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? kPrimaryBlue.withOpacity(0.1)
              : kLightBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kPrimaryBlue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isSelected ? kPrimaryBlue : kDarkTextColor,
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: kAppFont,
                fontWeight: FontWeight.bold,
                color: kDarkTextColor,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: kAppFont,
                fontSize: 12,
                color: kMutedTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
