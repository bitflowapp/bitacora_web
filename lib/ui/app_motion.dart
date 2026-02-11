import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

@immutable
class AppMotion {
  const AppMotion._();

  static const Duration micro = Duration(milliseconds: 120);
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 220);
  static const Duration modal = Duration(milliseconds: 280);

  static const Curve standardOut = Curves.easeOutCubic;
  static const Curve standardIn = Curves.easeInCubic;
  static const Curve springOut = Curves.easeOutBack;

  static CurvedAnimation curved(
    Animation<double> animation, {
    Curve curve = standardOut,
    Curve reverseCurve = standardIn,
  }) {
    return CurvedAnimation(
      parent: animation,
      curve: curve,
      reverseCurve: reverseCurve,
    );
  }

  static Widget fadeSlide({
    required Animation<double> animation,
    required Widget child,
    Offset begin = const Offset(0, 0.06),
    Curve curve = standardOut,
  }) {
    final curvedAnim = curved(animation, curve: curve);
    final slide =
        Tween<Offset>(begin: begin, end: Offset.zero).animate(curvedAnim);
    return FadeTransition(
      opacity: curvedAnim,
      child: SlideTransition(position: slide, child: child),
    );
  }

  static Widget fadeScale({
    required Animation<double> animation,
    required Widget child,
    double begin = 0.985,
    Curve curve = standardOut,
  }) {
    final curvedAnim = curved(animation, curve: curve);
    final scale = Tween<double>(begin: begin, end: 1).animate(curvedAnim);
    return FadeTransition(
      opacity: curvedAnim,
      child: ScaleTransition(scale: scale, child: child),
    );
  }

  static Widget modalTransition({
    required BuildContext context,
    required Animation<double> animation,
    required Widget child,
  }) {
    final platform = Theme.of(context).platform;
    final cupertinoLike =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    if (cupertinoLike) {
      return fadeSlide(
        animation: animation,
        child: fadeScale(
          animation: animation,
          child: child,
          begin: 1.02,
          curve: Curves.easeOut,
        ),
        begin: const Offset(0, 0.02),
        curve: Curves.easeOut,
      );
    }

    return fadeScale(
      animation: animation,
      child: child,
      begin: 0.98,
    );
  }

  static Simulation openSpring({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) {
    return SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 360, damping: 30),
      start,
      end,
      velocity,
    );
  }
}
