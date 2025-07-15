import 'package:flutter/material.dart';
import 'package:kesh_kart/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  bool isLastPage = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            onPageChanged: (index) {
              setState(() {
                isLastPage = index == 2;
              });
            },
            children: [
              buildPage(
                title: 'Your Grooming Partner',
                subtitle: 'Book haircuts, beard trims & more with just a tap',
                imageAsset: 'assets/images/onboarding1.png',
              ),
              buildPage(
                title: 'Top Barbers Near You',
                subtitle:
                    'Verified pros with ratings & reviews at your fingertips',
                imageAsset: 'assets/images/onboarding2.png',
              ),
              buildPage(
                title: 'Grooming Products You’ll Love',
                subtitle:
                    'Buy recommended items directly from your favorite barber',
                imageAsset: 'assets/images/onboarding3.png',
              ),
            ],
          ),

          // Skip Button
          Positioned(
            top: 40,
            right: 20,
            child: TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                prefs.setBool('seenOnboarding', true);

                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LogInScreen()),
                );
              },
              child: Text('Skip', style: TextStyle(color: Colors.white)),
            ),
          ),

          // Page Indicator
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: _controller,
                count: 3,
                effect: WormEffect(
                  dotHeight: 10,
                  dotWidth: 10,
                  activeDotColor: Colors.white,
                  dotColor: Colors.grey,
                ),
              ),
            ),
          ),

          // Get Started Button
          if (isLastPage)
            Positioned(
              bottom: 40,
              left: 40,
              right: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  prefs.setBool('seenOnboarding', true);

                  if (!mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LogInScreen()),
                  );
                },
                child: Text('Get Started', style: TextStyle(fontSize: 16)),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildPage({
    required String title,
    required String subtitle,
    required String imageAsset,
  }) {
    return Container(
      padding: EdgeInsets.all(30),
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imageAsset,
            height: MediaQuery.of(context).size.height * 0.45,
          ),

          SizedBox(height: 40),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 15),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[300], fontSize: 14),
          ),
        ],
      ),
    );
  }
}
