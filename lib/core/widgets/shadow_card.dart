import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/shadow_styles.dart';
import '../theme/theme_provider.dart';

/// A custom card widget with consistent 3D shadow effects across the app
class ShadowCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final ShadowIntensity shadowIntensity;
  final bool animated;
  final Duration animationDuration;
  final bool enablePressEffect;
  final Border? border;
  final double? width;
  final double? height;

  const ShadowCard({
    super.key,
    required this.child,
    this.margin,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 12,
    this.color,
    this.gradient,
    this.onTap,
    this.shadowIntensity = ShadowIntensity.medium,
    this.animated = true,
    this.animationDuration = const Duration(milliseconds: 200),
    this.enablePressEffect = true,
    this.border,
    this.width,
    this.height,
  });

  @override
  State<ShadowCard> createState() => _ShadowCardState();
}

class _ShadowCardState extends State<ShadowCard> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _shadowAnimation = Tween<double>(
      begin: 1.0,
      end: 0.5,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.enablePressEffect && widget.animated) {
      setState(() {
        _isPressed = true;
      });
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _handleTapEnd();
  }

  void _handleTapCancel() {
    _handleTapEnd();
  }

  void _handleTapEnd() {
    if (widget.enablePressEffect && widget.animated) {
      setState(() {
        _isPressed = false;
      });
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isGlass = themeProvider.isGlassTheme;
    
    // Get theme-aware shadows
    final normalShadows = ShadowStyles.getThemeAwareShadow(
      context,
      isGlass: isGlass,
      intensity: widget.shadowIntensity,
    );
    
    final pressedShadows = ShadowStyles.getThemeAwareShadow(
      context,
      isGlass: isGlass,
      intensity: ShadowIntensity.light,
    );

    return Container(
      margin: widget.margin,
      width: widget.width,
      height: widget.height,
      child: widget.animated && widget.enablePressEffect
          ? AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: _buildCard(context, themeProvider, normalShadows, pressedShadows),
                );
              },
            )
          : _buildCard(context, themeProvider, normalShadows, pressedShadows),
    );
  }

  Widget _buildCard(
    BuildContext context,
    ThemeProvider themeProvider,
    List<BoxShadow> normalShadows,
    List<BoxShadow> pressedShadows,
  ) {
    final cardColor = widget.color ?? 
        (themeProvider.isGlassTheme
            ? Colors.white.withValues(alpha: 0.1)
            : Theme.of(context).cardColor);

    final shadows = widget.animated && _isPressed ? pressedShadows : normalShadows;
    
    // Apply shadow animation if enabled
    final animatedShadows = widget.animated && widget.enablePressEffect
        ? shadows.map((shadow) => BoxShadow(
            color: Color.lerp(shadow.color, shadow.color.withValues(alpha: 0.3), 
                1 - _shadowAnimation.value)!,
            offset: shadow.offset,
            blurRadius: shadow.blurRadius * _shadowAnimation.value,
            spreadRadius: shadow.spreadRadius,
          )).toList()
        : shadows;

    final decoration = BoxDecoration(
      color: widget.gradient == null ? cardColor : null,
      gradient: widget.gradient,
      borderRadius: BorderRadius.circular(widget.borderRadius),
      boxShadow: animatedShadows,
      border: widget.border,
      // Add glass effect for glass theme
      backgroundBlendMode: themeProvider.isGlassTheme ? BlendMode.overlay : null,
    );

    final cardContent = Container(
      decoration: decoration,
      padding: widget.padding,
      child: widget.child,
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        child: cardContent,
      );
    }

    return cardContent;
  }
}

/// Specialized cards for different use cases

/// A card specifically designed for feature/action buttons
class ActionShadowCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  const ActionShadowCard({
    super.key,
    required this.child,
    this.onTap,
    this.margin,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ShadowCard(
      onTap: onTap,
      margin: margin,
      padding: padding,
      color: color,
      shadowIntensity: ShadowIntensity.medium,
      enablePressEffect: onTap != null,
      child: child,
    );
  }
}

/// A card for displaying user stats and important information
class StatsShadowCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Gradient? gradient;

  const StatsShadowCard({
    super.key,
    required this.child,
    this.margin,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return ShadowCard(
      margin: margin,
      padding: padding,
      color: color,
      gradient: gradient,
      shadowIntensity: ShadowIntensity.heavy,
      enablePressEffect: false,
      child: child,
    );
  }
}

/// A card for list items and feed content
class ListShadowCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const ListShadowCard({
    super.key,
    required this.child,
    this.onTap,
    this.margin = const EdgeInsets.only(bottom: 8),
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return ShadowCard(
      onTap: onTap,
      margin: margin,
      padding: padding,
      shadowIntensity: ShadowIntensity.light,
      enablePressEffect: onTap != null,
      child: child,
    );
  }
}

/// A floating card with prominent shadow for dialogs and overlays
class FloatingShadowCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Color? color;

  const FloatingShadowCard({
    super.key,
    required this.child,
    this.margin,
    this.padding = const EdgeInsets.all(24),
    this.width,
    this.height,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ShadowCard(
      margin: margin,
      padding: padding,
      width: width,
      height: height,
      color: color,
      shadowIntensity: ShadowIntensity.floating,
      enablePressEffect: false,
      borderRadius: 16,
      child: child,
    );
  }
}