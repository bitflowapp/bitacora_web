import 'package:flutter/material.dart';

/// Apple-inspired motion tokens and primitives.
///
/// The goal is to make movement feel intentional: quick, soft, and physical
/// without becoming distracting on field devices.
abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 1);
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 520);

  static const Curve swiftOut = Cubic(0.22, 1.0, 0.36, 1.0);
  static const Curve softSpring = Cubic(0.16, 1.0, 0.3, 1.0);
  static const Curve press = Cubic(0.2, 0.0, 0.0, 1.0);

  static bool reduceMotion(BuildContext context) {
    final data = MediaQuery.maybeOf(context);
    return data?.disableAnimations == true ||
        data?.accessibleNavigation == true;
  }

  static Duration resolve(BuildContext context, Duration duration) {
    return reduceMotion(context) ? instant : duration;
  }
}

class AppMotionPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppMotionPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst || AppMotion.reduceMotion(context)) {
      return FadeTransition(opacity: animation, child: child);
    }

    final primary = CurvedAnimation(
      parent: animation,
      curve: AppMotion.softSpring,
      reverseCurve: Curves.easeInCubic,
    );
    final secondary = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: AppMotion.swiftOut,
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(0, 0.86, curve: Curves.easeOut),
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.045, 0),
          end: Offset.zero,
        ).animate(primary),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(-0.018, 0),
          ).animate(secondary),
          child: child,
        ),
      ),
    );
  }
}

class AppMotionReveal extends StatelessWidget {
  const AppMotionReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.standard,
    this.offset = const Offset(0, 18),
    this.scaleBegin = 0.985,
    this.curve = AppMotion.softSpring,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final double scaleBegin;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final reduce = AppMotion.reduceMotion(context);
    if (reduce) return child;

    final total = delay + duration;
    final delayFraction = total.inMicroseconds == 0
        ? 0.0
        : delay.inMicroseconds / total.inMicroseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total,
      curve: Curves.linear,
      child: child,
      builder: (context, raw, child) {
        final t = delayFraction >= 1
            ? 1.0
            : ((raw - delayFraction) / (1 - delayFraction)).clamp(0.0, 1.0);
        final eased = curve.transform(t);
        final translate = Offset.lerp(offset, Offset.zero, eased)!;
        final scale = scaleBegin + ((1 - scaleBegin) * eased);

        return Opacity(
          opacity: eased.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: translate,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class AppMotionStaggered extends StatelessWidget {
  const AppMotionStaggered({
    super.key,
    required this.children,
    this.initialDelay = Duration.zero,
    this.step = const Duration(milliseconds: 44),
    this.duration = AppMotion.standard,
    this.offset = const Offset(0, 18),
  });

  final List<Widget> children;
  final Duration initialDelay;
  final Duration step;
  final Duration duration;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < children.length; i++)
          AppMotionReveal(
            delay: initialDelay + (step * i),
            duration: duration,
            offset: offset,
            child: children[i],
          ),
      ],
    );
  }
}

class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.972,
    this.hoverScale = 1.012,
    this.duration = AppMotion.fast,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;
  final double hoverScale;
  final Duration duration;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _hovering = false;
  bool _pressing = false;

  void _setPressing(bool value) {
    if (_pressing == value || !mounted) return;
    setState(() => _pressing = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final scale = !enabled
        ? 1.0
        : _pressing
            ? widget.pressedScale
            : (_hovering ? widget.hoverScale : 1.0);

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (enabled) setState(() => _hovering = true);
      },
      onExit: (_) {
        if (!mounted) return;
        setState(() {
          _hovering = false;
          _pressing = false;
        });
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: enabled ? (_) => _setPressing(true) : null,
        onPointerUp: enabled ? (_) => _setPressing(false) : null,
        onPointerCancel: enabled ? (_) => _setPressing(false) : null,
        child: AnimatedScale(
          scale: scale,
          duration: AppMotion.resolve(context, widget.duration),
          curve: AppMotion.press,
          child: widget.child,
        ),
      ),
    );
  }
}
