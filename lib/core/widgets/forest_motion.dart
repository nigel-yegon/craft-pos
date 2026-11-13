import 'dart:math' as math;
import 'package:flutter/material.dart';

class ForestMotionBackground extends StatefulWidget {
  final Widget child;
  const ForestMotionBackground({super.key, required this.child});

  @override
  State<ForestMotionBackground> createState() => _ForestMotionBackgroundState();
}

class _ForestMotionBackgroundState extends State<ForestMotionBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final angle = t * 2 * math.pi;

        final dx1 = math.cos(angle) * 0.35;
        final dy1 = math.sin(angle * 0.7) * 0.30;
        final dx2 = math.cos(angle + math.pi) * 0.40;
        final dy2 = math.sin(angle + math.pi) * 0.35;

        return Container(
          color: const Color(0xFF04151F),
          child: Stack(
            children: [
              // Layer 1 — base gradient
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(
                          const Color(0xFF04151F),
                          const Color(0xFF183A37),
                          (math.sin(angle) + 1) / 2,
                        )!,
                        const Color(0xFF02090E),
                      ],
                    ),
                  ),
                ),
              ),

              // Layer 2 — warm wheat glow
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(dx1, dy1),
                      radius: 0.95,
                      colors: [
                        const Color(0xFFEFD6AC).withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Layer 3 — burnt orange glow
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(dx2, dy2),
                      radius: 0.85,
                      colors: [
                        const Color(0xFFC44900).withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Layer 4 — midnight violet tint
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-dx1, dy2),
                      radius: 0.9,
                      colors: [
                        const Color(0xFF432534).withValues(alpha: 0.20),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Positioned.fill(child: child!),
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}

class RevealOnMount extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  const RevealOnMount({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 650),
    this.offset = const Offset(0, 20),
  });

  @override
  State<RevealOnMount> createState() => _RevealOnMountState();
}

class _RevealOnMountState extends State<RevealOnMount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: widget.offset, end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}