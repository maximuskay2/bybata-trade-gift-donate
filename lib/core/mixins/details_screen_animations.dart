import 'package:flutter/material.dart';

mixin DetailsScreenAnimations on TickerProvider {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;

  void initDetailsAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  void disposeDetailsAnimations() {
    _fadeController.dispose();
    _slideController.dispose();
  }

  // Fade-in animation for individual elements
  FadeTransition fadeInBuilder(Widget child) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: child,
    );
  }

  // Slide-up animation for individual elements
  SlideTransition slideUpBuilder(Widget child) {
    return SlideTransition(
      position: slideAnimation,
      child: child,
    );
  }

  // Combined fade + slide animation for full screen
  Widget combinedTransition(Widget child) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: child,
      ),
    );
  }

  // Staggered animation for list items
  Widget staggeredListItem(Widget child, int index, int totalCount) {
    final delay = Duration(milliseconds: 50 * index);
    final itemFadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    itemFadeController.forward(from: 0);

    Future.delayed(delay, () {
      if (itemFadeController.isAnimating) {
        itemFadeController.forward();
      }
    });

    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: itemFadeController, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: itemFadeController, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  }

  // Pulse animation for CTAs
  Widget pulseAnimation(Widget child) {
    final pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 1.02).animate(
        CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
      ),
      child: child,
    );
  }

  // Scale animation for avatar/header image
  Widget scaleAnimation(Widget child) {
    final scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    scaleController.forward();

    return ScaleTransition(
      scale: Tween<double>(begin: 0.95, end: 1).animate(
        CurvedAnimation(parent: scaleController, curve: Curves.easeOutBack),
      ),
      child: child,
    );
  }
}
