import 'package:flutter/material.dart';
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
        title: lang.tr('page_1_title', category: 'onboarding'),
        description: lang.tr('page_1_description', category: 'onboarding'),
        image: 'assets/images/logo.png',
      ),
      OnboardingItem(
        title: lang.tr('page_2_title', category: 'onboarding'),
        description: lang.tr('page_2_description', category: 'onboarding'),
        image: 'assets/images/1.png',
      ),
      OnboardingItem(
        title: lang.tr('page_3_title', category: 'onboarding'),
        description: lang.tr('page_3_description', category: 'onboarding'),
        image: 'assets/images/2.png',
      ),
      OnboardingItem(
        title: lang.tr('page_4_title', category: 'onboarding'),
        description: lang.tr('page_4_description', category: 'onboarding'),
        image: 'assets/images/3.png',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final onboardingData = _getOnboardingData(lang);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: Text(
                  lang.tr('skip', category: 'onboarding'),
                  style: const TextStyle(
                    color: kPrimaryBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: kAppFont,
                  ),
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
                  return _buildOnboardingPage(onboardingData[index]);
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _currentPage == onboardingData.length - 1
                      ? _completeOnboarding
                      : _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage == onboardingData.length - 1
                        ? lang.tr('get_started', category: 'onboarding')
                        : lang.tr('next', category: 'onboarding'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: kAppFont,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(OnboardingItem item) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image only
          SizedBox(
            width: 250,
            height: 250,
            child: Image.asset(
              item.image,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: kPrimaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '📸',
                      style: TextStyle(fontSize: 60),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 48),

          // Title
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: kDarkTextColor,
              fontFamily: kAppFont,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            item.description,
            style: TextStyle(
              fontSize: 16,
              color: kMutedTextColor,
              fontFamily: kAppFont,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
        color: isActive ? kPrimaryBlue : kPrimaryBlue.withOpacity(0.3),
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

  OnboardingItem({
    required this.title,
    required this.description,
    required this.image,
  });
}
