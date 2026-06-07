// lib/core/animations.dart
// Shared animation utilities for the entire app.
import 'package:flutter/material.dart';

/// Custom page-route with a shared-axis fade + slight slide transition.
/// Feels premium and smooth on all platforms.
class FadeSlidePageRoute<T> extends PageRouteBuilder<T> {
  FadeSlidePageRoute({required WidgetBuilder page})
    : super(
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => page(_),
        transitionsBuilder: (_, anim, __, child) {
          const begin = Offset(0.0, 0.04);
          const end = Offset.zero;
          final curvedAnim = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curvedAnim,
            child: SlideTransition(
              position: Tween<Offset>(begin: begin, end: end).animate(curvedAnim),
              child: child,
            ),
          );
        },
      );
}

/// A breathing container used for skeleton loading.
/// Uses a slow opacity pulse instead of a gradient sweep — softer and more
/// professional than the default shimmer.
class BreathingBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  final EdgeInsets? margin;

  const BreathingBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
    this.margin,
  });

  @override
  State<BreathingBox> createState() => _BreathingBoxState();
}

class _BreathingBoxState extends State<BreathingBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final opacity = 0.12 + 0.08 * _ctrl.value;
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withOpacity(opacity),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// Staggered list/grid item — fades in and slides up with a per-index delay.
class StaggeredItem extends StatelessWidget {
  final int index;
  final Widget child;
  final AnimationController controller;
  final int offset; // stagger delay multiplier (ms)

  const StaggeredItem({
    super.key,
    required this.index,
    required this.child,
    required this.controller,
    this.offset = 60,
  });

  @override
  Widget build(BuildContext context) {
    const maxVisible = 12; // animate only first N items
    if (index >= maxVisible) return child;

    final interval = 1.0 / maxVisible;
    final start = (index * interval).clamp(0.0, 1.0 - interval);
    final end = (start + interval).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = Interval(start, end, curve: Curves.easeOutCubic)
            .transform(controller.value);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}
