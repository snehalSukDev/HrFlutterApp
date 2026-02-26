import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onComplete;

  const OnboardingScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingSlide {
  final String title;
  final String description;
  final String assetPath;

  const _OnboardingSlide({
    required this.title,
    required this.description,
    required this.assetPath,
  });
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  static const List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      title: 'Welcome to Techbird HRMS',
      description:
          'Manage your professional life with ease. Track attendance, apply for leaves, and connect with your team all in one place.',
      assetPath: 'assets/images/login/bg1.png',
    ),
    _OnboardingSlide(
      title: 'Smart Leave Management',
      description:
          'Submit leave requests in seconds and stay updated on approvals and balances.',
      assetPath: 'assets/images/login/bg2.png',
    ),
    _OnboardingSlide(
      title: 'Real-time Attendance',
      description:
          'Clock in and out effortlessly and keep an accurate log of your working hours.',
      assetPath: 'assets/images/login/bg3.png',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleNext() {
    if (_currentIndex < _slides.length - 1) {
      _pageController.animateToPage(
        _currentIndex + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handlePrev() {
    if (_currentIndex > 0) {
      _pageController.animateToPage(
        _currentIndex - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final slide = _slides[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      slide.assetPath,
                      fit: BoxFit.cover,
                    ),
                    Container(
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: _buildTextBlock(theme),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildControls(theme),
                  ],
                ),
              ),
            ),
          ),
          if (_currentIndex > 0)
            Positioned(
              left: 24,
              top: kToolbarHeight,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.35),
                ),
                onPressed: _handlePrev,
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextBlock(ThemeData theme) {
    final slide = _slides[_currentIndex];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          slide.title,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(
                color: Colors.black54,
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          slide.description,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFFE2E8F0),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildControls(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: List.generate(_slides.length, (index) {
            final isActive = index == _currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin:
                  EdgeInsets.only(right: index == _slides.length - 1 ? 0 : 8),
              height: 6,
              width: isActive ? 32 : 8,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFF64748B),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
        if (_currentIndex == _slides.length - 1)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 5,
            ),
            onPressed: () {
              widget.onComplete();
            },
            child: const Text(
              'Get Started',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            onPressed: _handleNext,
            icon: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
            ),
          ),
      ],
    );
  }
}
