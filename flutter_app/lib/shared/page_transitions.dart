import 'package:flutter/material.dart';

/// Instant navigation without any transition animation.
PageRoute<T> instantRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

/// Fades and slides the new page from the bottom for a subtle transition.
PageRoute<T> fadeSlideRoute<T>(Widget page,
    {Offset begin = const Offset(0, 0.08),
    Duration duration = const Duration(milliseconds: 260)}) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (_, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final offsetTween = Tween<Offset>(begin: begin, end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOut));
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: animation.drive(offsetTween),
          child: child,
        ),
      );
    },
  );
}
