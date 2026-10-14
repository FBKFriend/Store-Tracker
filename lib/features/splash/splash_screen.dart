import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/app_logo.dart';

class SplashScreen extends StatefulWidget {
  final Widget next;
  const SplashScreen({super.key, required this.next});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const double _logoSize = 140;

  late final AnimationController _controller;
  late final Animation<double> _fly;
  late final Animation<double> _ripple;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );

    // 1. Logo flies in from the bottom to the center
    _fly = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
    );
    // 2. Ripple grows from the center
    _ripple = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.75, curve: Curves.easeInOut),
    );
    // 3. Logo fades away
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.8, 1.0, curve: Curves.easeIn),
    );
    _controller.forward().whenComplete(_goNext);
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => widget.next,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = MediaQuery.of(context).size;
    // distance from the center to a corner, so the ripple covers everything
    final maxRadius =
        math.sqrt(screen.width * screen.width + screen.height * screen.height) /
        2;
    final startOffset = screen.height / 2 + _logoSize;

    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _RipplePainter(
                  progress: _ripple.value,
                  color: theme.scaffoldBackgroundColor,
                  maxRadius: maxRadius,
                ),
              ),
              Center(
                child: Opacity(
                  opacity: 1 - _fade.value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - _fly.value) * startOffset),
                    child: const AppLogo(size: _logoSize),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double maxRadius;

  _RipplePainter({
    required this.progress,
    required this.color,
    required this.maxRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    canvas.drawCircle(
      size.center(Offset.zero),
      maxRadius * progress,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.progress != progress || old.color != color;
}
