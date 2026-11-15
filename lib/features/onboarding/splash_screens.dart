// lib/features/onboarding/splash_screens.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SplashScreens extends StatefulWidget {
  /// Called when the preloader animation finishes.
  final VoidCallback onComplete;

  /// When true, shows "Setting up your shop..." copy — for first run /
  /// after a reset. When false, shows "Loading your workspace...".
  final bool isFirstRun;

  const SplashScreens({
    super.key,
    required this.onComplete,
    this.isFirstRun = false,
  });

  @override
  State<SplashScreens> createState() => _SplashScreensState();
}

class _SplashScreensState extends State<SplashScreens>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse (breathing effect on the logo tile)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Progress bar (2.2s — just long enough for the pulse to complete ~1.5 cycles)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _progressController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Gradient background matches the dashboard hero card
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.midGreen,
              AppTheme.heroGreen,
              AppTheme.forestDeep,
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
            child: Column(
              children: [
                const Spacer(),

                // ═══ LOGO TILE ═══
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      color: AppTheme.brightGreen,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.brightGreen.withValues(alpha: 0.35),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 56,
                      color: AppTheme.inkBlack,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ═══ BRAND TEXT ═══
                const Text(
                  'Craft Business',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isFirstRun
                      ? 'Let\'s set up your shop'
                      : 'Sell. Track. Grow.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.65),
                    letterSpacing: 0.4,
                  ),
                ),

                const Spacer(),

                // ═══ PROGRESS ═══
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thin progress bar with rounded ends
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: _progressController.value,
                            minHeight: 5,
                            backgroundColor:
                            Colors.white.withValues(alpha: 0.15),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.brightGreen,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Status copy — changes based on first-run flag
                        Text(
                          widget.isFirstRun
                              ? 'Preparing your workspace...'
                              : 'Loading your shop...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}