import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/register_modern_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';

/// Centralized controller for managing bottom navigation bar visibility
/// 
/// This class provides a clean, maintainable way to determine when the
/// bottom navigation bar should be hidden based on route names and widget types.
/// 
/// Usage:
/// ```dart
/// final controller = NavigationVisibilityController();
/// if (controller.shouldShowNavigation(routeName, child)) {
///   // Show navigation bar
/// }
/// ```
class NavigationVisibilityController {
  /// Routes that should hide the bottom navigation bar
  /// 
  /// Add any route that should not display the navigation bar.
  /// This is the primary source of truth for route-based exclusion.
  static final Set<String> _excludedRoutes = {
    AppConstants.loginRoute,        // '/login'
    AppConstants.registerRoute,      // '/register'
    AppConstants.forgotPasswordRoute, // '/forgot-password'
  };

  /// Widget types that should hide the bottom navigation bar
  /// 
  /// These are widget types that should never show the navigation bar,
  /// regardless of route name. This handles cases where route names
  /// might be null or dynamic.
  static final Set<Type> _excludedWidgetTypes = {
    LoginScreen,
    RegisterScreen,
    RegisterModernScreen,
    ForgotPasswordScreen,
  };

  /// Route patterns that should hide the navigation bar
  /// 
  /// These are substring patterns that, if found in a route name,
  /// will cause the navigation bar to be hidden.
  static final List<String> _excludedRoutePatterns = [
    'login',
    'register',
    'forgot',
    'password',
    'auth',
  ];

  /// Check if navigation should be shown for the given route and widget
  /// 
  /// Returns `true` if navigation should be shown, `false` if it should be hidden.
  /// 
  /// Priority order:
  /// 1. Check exact route name against excluded routes
  /// 2. Check widget type against excluded widget types
  /// 3. Check route name against excluded patterns
  /// 
  /// [routeName] - The current route name (can be null)
  /// [widget] - The current widget being displayed
  /// [authState] - Optional authentication state to check
  /// 
  /// Returns `true` if navigation should be shown, `false` if hidden
  bool shouldShowNavigation({
    String? routeName,
    Widget? widget,
    bool? authState,
  }) {
    // If we have a route name, check exact matches first
    if (routeName != null) {
      final normalizedRoute = routeName.toLowerCase().trim();
      
      // Check exact route match
      if (_excludedRoutes.contains(routeName) ||
          _excludedRoutes.contains(normalizedRoute)) {
        return false;
      }
      
      // Check route patterns
      for (final pattern in _excludedRoutePatterns) {
        if (normalizedRoute.contains(pattern)) {
          return false;
        }
      }
    }
    
    // Check widget type (works even when route name is null)
    if (widget != null) {
      final widgetType = widget.runtimeType;
      if (_excludedWidgetTypes.contains(widgetType)) {
        return false;
      }
    }
    
    // Default: show navigation
    return true;
  }

  /// Check if navigation should be hidden (inverse of shouldShowNavigation)
  bool shouldHideNavigation({
    String? routeName,
    Widget? widget,
    bool? authState,
  }) {
    return !shouldShowNavigation(
      routeName: routeName,
      widget: widget,
      authState: authState,
    );
  }

  /// Add a route to the exclusion list
  /// 
  /// Useful for dynamically adding routes that should hide navigation.
  /// Note: This modifies a static set, so changes persist for the app lifetime.
  static void addExcludedRoute(String route) {
    _excludedRoutes.add(route);
  }

  /// Remove a route from the exclusion list
  static void removeExcludedRoute(String route) {
    _excludedRoutes.remove(route);
  }

  /// Add a widget type to the exclusion list
  static void addExcludedWidgetType(Type widgetType) {
    _excludedWidgetTypes.add(widgetType);
  }

  /// Remove a widget type from the exclusion list
  static void removeExcludedWidgetType(Type widgetType) {
    _excludedWidgetTypes.remove(widgetType);
  }

  /// Get all currently excluded routes (for debugging/inspection)
  static Set<String> get excludedRoutes => Set.unmodifiable(_excludedRoutes);

  /// Get all currently excluded widget types (for debugging/inspection)
  static Set<Type> get excludedWidgetTypes =>
      Set.unmodifiable(_excludedWidgetTypes);
}

