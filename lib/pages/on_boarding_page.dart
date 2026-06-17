import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:wallet/widgets/app_button.dart';

class OnBoardingPage extends StatefulWidget {
  const OnBoardingPage({super.key});

  @override
  State<OnBoardingPage> createState() => _OnBoardingPageState();
}

class OnBoardingSlide {
  final String lottiePath;
  final String title;
  final String description;

  const OnBoardingSlide({
    required this.lottiePath,
    required this.title,
    required this.description,
  });
}

class OnBoardingSlideWidget extends StatelessWidget {
  final OnBoardingSlide slide;

  const OnBoardingSlideWidget({super.key, required this.slide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Lottie.asset(slide.lottiePath)),
        Text(
          slide.title,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontFamily: GoogleFonts.poorStory().fontFamily,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16.0),
        Text(
          slide.description,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            height: 1.5,
          ),
        ),
        const SizedBox(
          height: 64.0,
        ),
      ],
    );
  }
}

class _OnBoardingPageState extends State<OnBoardingPage>
    with TickerProviderStateMixin {
  static const List<OnBoardingSlide> _slides = [
    OnBoardingSlide(
      lottiePath: "assets/illustrations/send_receive.json",
      title: "Send & Receive",
      description:
          "Send money to anyone, anywhere — instantly and effortlessly. No delays, no hassle, just seamless transfers at your fingertips.",
    ),
    OnBoardingSlide(
      lottiePath: "assets/illustrations/kyc.json",
      title: "Verify Identity",
      description:
          "Your security is our priority. Complete your verification in minutes and unlock the full power of a trusted, protected account.",
    ),
    OnBoardingSlide(
      lottiePath: "assets/illustrations/start_now.json",
      title: "Start Now",
      description:
          "Everything you need to manage your money is right here. Join thousands who already trust us — your financial freedom starts today.",
    ),
  ];

  late final PageController _pageController;

  late final AnimationController _progressController;
  int _renderIndex = 0;

  double _renderProgress = 0.0;
  bool _inTransition = false;
  bool _isPaused = false;

  int get _slideCount => _slides.length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 15.0),
          child: Stack(
            children: [
              PageView(
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _renderIndex = index;
                    _renderProgress = 0;
                  });
                  _progressController
                    ..reset()
                    ..forward();
                },
                controller: _pageController,
                children: _slides
                    .map((slide) => OnBoardingSlideWidget(slide: slide))
                    .toList(),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12.0,
                  children: [
                    Row(
                      children: List.generate(_slideCount, (index) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: AnimatedBuilder(
                              animation: _progressController,
                              builder: (context, child) {
                                final double value = index < _renderIndex
                                    ? 1.0
                                    : index == _renderIndex
                                        ? _renderProgress
                                        : 0.0;

                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(100),
                                  child: Stack(
                                    children: [
                                      Container(
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            100,
                                          ),
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: value,
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            borderRadius: BorderRadius.circular(
                                              100,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                    IconButton.filledTonal(
                      onPressed: () {
                        setState(() {
                          if (_isPaused) {
                            _isPaused = false;
                            _progressController.forward();
                          } else {
                            _isPaused = true;
                            _progressController.stop();
                          }
                        });
                      },
                      icon: Icon(
                        _isPaused ? Icons.play_arrow : Icons.pause,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Row(
                  spacing: 12.0,
                  children: [
                    Expanded(
                      child: AppButton(
                        onPressed: () => context.go('/register'),
                        label: "Create Account",
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
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _pageController = PageController();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..forward();

    _progressController.addListener(() {
      if (!_inTransition && !_isPaused) {
        setState(() {
          _renderProgress = _progressController.value;
        });
      }
    });

    _progressController.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        if (_isPaused) return;

        _inTransition = true;

        final next = _renderIndex < _slideCount - 1 ? _renderIndex + 1 : 0;

        await _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );

        _progressController
          ..reset()
          ..forward();

        _inTransition = false;
      }
    });
  }
}
