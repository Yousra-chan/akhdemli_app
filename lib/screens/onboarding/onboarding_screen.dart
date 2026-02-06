import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_app/screens/auth/login/login_screen.dart';

// --- Configuration ---
class OnboardingPageModel {
  final String imagePath;
  final String title;
  final String description;

  OnboardingPageModel({
    required this.imagePath,
    required this.title,
    required this.description,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;

  static const Color _brandPrimaryBlue = Color(0xFF143EAE);

  // Onboarding page data (using your image names)
  final List<OnboardingPageModel> _pages = [
    OnboardingPageModel(
      imagePath: "assets/images/1.png",
      title: "Fast & Reliable Service",
      description:
          "Connect with skilled professionals for all your needs, quickly and efficiently.",
    ),
    OnboardingPageModel(
      imagePath: "assets/images/2.png",
      title: "Quality Guaranteed",
      description:
          "Our platform ensures top-notch service from verified and highly-rated experts.",
    ),
    OnboardingPageModel(
      imagePath: "assets/images/3.png",
      title: "Easy to Use",
      description:
          "Find, book, and manage services seamlessly with our intuitive app interface.",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (_pageController.page != null) {
        setState(() {
          _currentPageIndex = _pageController.page!.round();
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // RELIABLE FIX: Static method to save the flag without relying on widget context
  static Future<void> _setSeenFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
  }

  // RELIABLE FIX: Synchronous navigation after calling the async save (fire-and-forget)
  void _navigateToDestination(Widget destinationScreen) {
    _setSeenFlag(); // Start the async save operation

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => destinationScreen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button (Goes to main app/dashboard)
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => _navigateToDestination(const LoginScreen()),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  textStyle: GoogleFonts.varelaRound(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('Skip'),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _OnboardingPageView(
                    imagePath: page.imagePath,
                    title: page.title,
                    description: page.description,
                    brandPrimaryBlue: _brandPrimaryBlue,
                  );
                },
              ),
            ),

            // Page Indicator and Next/Start Button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 30.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _pages.length,
                    effect: ExpandingDotsEffect(
                      dotColor: Colors.grey.shade300,
                      activeDotColor: _brandPrimaryBlue,
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 3,
                      spacing: 5.0,
                    ),
                  ),
                  _currentPageIndex == _pages.length - 1
                      ? ElevatedButton(
                          // FINAL ACTION: Get Started button navigates to LoginScreen
                          onPressed: () =>
                              _navigateToDestination(const LoginScreen()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandPrimaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            textStyle: GoogleFonts.varelaRound(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Get Started'),
                        )
                      : FloatingActionButton(
                          onPressed: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                            );
                          },
                          backgroundColor: _brandPrimaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const CircleBorder(),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 20,
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A helper widget for each individual onboarding page content
class _OnboardingPageView extends StatelessWidget {
  final String imagePath;
  final String title;
  final String description;
  final Color brandPrimaryBlue;

  const _OnboardingPageView({
    required this.imagePath,
    required this.title,
    required this.description,
    required this.brandPrimaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image constrained for better centering and size control
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.35,
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            child: Center(child: Image.asset(imagePath, fit: BoxFit.contain)),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.varelaRound(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: brandPrimaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.varelaRound(
              fontSize: 16,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
