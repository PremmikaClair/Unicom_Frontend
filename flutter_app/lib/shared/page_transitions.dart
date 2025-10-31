// lib/shared/page_transitions.dart
import 'package:flutter/material.dart';

/// Instant transition (no animation).
Route<T> instantRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

/// Simple fade + slight slide from bottom transition.
Route<T> fadeSlideRoute<T>(Widget child, {Duration duration = const Duration(milliseconds: 200)}) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

