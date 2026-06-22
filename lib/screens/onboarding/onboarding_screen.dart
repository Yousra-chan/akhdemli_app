import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:service_app/screens/auth/login/login_screen.dart';
import 'package:service_app/screens/auth/constants.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:provider/provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<OnboardingItem> _getOnboardingData(LanguageProvider lang) {
    return [
      OnboardingItem(
        title: lang.tr('ob_welcome_title', category: 'onboarding'),
        description: lang.tr('ob_welcome_desc', category: 'onboarding'),
        image: 'assets/images/logo.png',
        isLogoPage: true,
      ),
      OnboardingItem(
        title: lang.tr('ob_find_title', category: 'onboarding'),
        description: lang.tr('ob_find_desc', category: 'onboarding'),
        image: 'assets/images/1.png',
      ),
      OnboardingItem(
        title: lang.tr('ob_offer_title', category: 'onboarding'),
        description: lang.tr('ob_offer_desc', category: 'onboarding'),
        image: 'assets/images/2.png',
      ),
      OnboardingItem(
        title: lang.tr('ob_start_title', category: 'onboarding'),
        description: lang.tr('ob_start_desc', category: 'onboarding'),
        image: 'assets/images/3.png',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final onboardingData = _getOnboardingData(lang);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  style: TextButton.styleFrom(
                    foregroundColor: kPrimaryBlue,
                    textStyle: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(lang.tr('skip', category: 'onboarding')),
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: onboardingData.length,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildOnboardingPage(onboardingData[index], isDark, index);
                },
              ),
            ),

            // Page indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                onboardingData.length,
                    (index) => _buildPageIndicator(index == _currentPage),
              ),
            ),

            const SizedBox(height: 32),

            // Next/Get Started button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _currentPage == onboardingData.length - 1
                      ? _completeOnboarding
                      : _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: kPrimaryBlue.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _currentPage == onboardingData.length - 1
                          ? lang.tr('get_started', category: 'onboarding')
                          : lang.tr('next', category: 'onboarding'),
                      key: ValueKey<int>(_currentPage),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(OnboardingItem item, bool isDark, int index) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo page gets a smaller, contained logo + app name treatment.
              // Illustration pages keep the larger image.
              SizedBox(
                width: item.isLogoPage ? 160 : 280,
                height: item.isLogoPage ? 160 : 280,
                child: Image.asset(
                  item.image,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 80,
                        color: kPrimaryBlue.withOpacity(0.5),
                      ),
                    );
                  },
                ),
              ),

              SizedBox(height: item.isLogoPage ? 28 : 44),

              // App name / page title
              TweenAnimationBuilder<double>(
                key: ValueKey('title_$index'),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 16),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  item.title,
                  style: GoogleFonts.poppins(
                    fontSize: item.isLogoPage ? 34 : 30,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : kDarkTextColor,
                    letterSpacing: item.isLogoPage ? -1.0 : -0.8,
                    height: 1.15,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 4),

              // Accent underline for energy
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 18),
                decoration: BoxDecoration(
                  color: kPrimaryBlue,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // Description / tagline
              TweenAnimationBuilder<double>(
                key: ValueKey('desc_$index'),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 12),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: item.isLogoPage ? 12.0 : 0.0,
                  ),
                  child: Text(
                    item.description,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: isDark ? Colors.white70 : kMutedTextColor,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? kPrimaryBlue : kPrimaryBlue.withOpacity(0.25),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    // Save that user has seen onboarding
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    print('✅ Onboarding completed - navigating to login');

    // Navigate to login screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final String image;
  final bool isLogoPage;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.image,
    this.isLogoPage = false,
  });
}
