import 'package:flutter/material.dart';
import 'package:bybata/core/navigation/app_routes.dart';
import '../screens/enhanced_fund_wallet_screen.dart';
import 'wallet_routes.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class WalletNavigator {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Get the current context
  static BuildContext? get currentContext => navigatorKey.currentContext;

  // Navigation methods for each wallet screen
  static Future<void> toWalletHome(BuildContext context) async {
    if (AppRoutes.requireSignIn(context)) return;
    await GuardedNavigator.pushNamed(context, WalletRoutes.wallet);
  }

  static Future<void> toFundWallet(BuildContext context) async {
    if (AppRoutes.requireSignIn(context)) return;
    await GuardedNavigator.push(context,
      MaterialPageRoute(builder: (_) => const EnhancedFundWalletScreen()),
    );
  }

  static Future<void> toSendBYC(BuildContext context) async {
    if (AppRoutes.requireSignIn(context)) return;
    await GuardedNavigator.pushNamed(context, WalletRoutes.sendBYC);
  }

  static Future<void> toReceiveBYC(BuildContext context) async {
    if (AppRoutes.requireSignIn(context)) return;
    await GuardedNavigator.pushNamed(context, WalletRoutes.receiveBYC);
  }

  static Future<void> toTransactionHistory(BuildContext context) async {
    if (AppRoutes.requireSignIn(context)) return;
    await GuardedNavigator.pushNamed(context, WalletRoutes.transactionHistory);
  }

  static Future<void> toPromotionCenter(BuildContext context) async {
    AppRoutes.navigateToPromotions(context);
  }

  static Future<void> toConversion(BuildContext context) async {
    if (AppRoutes.requireSignIn(context)) return;
    await GuardedNavigator.pushNamed(context, WalletRoutes.conversion);
  }

  static Future<void> toEarnBYC(BuildContext context) async {
    if (AppRoutes.requireSignIn(context)) return;
    await GuardedNavigator.pushNamed(context, WalletRoutes.earnBYC);
  }

  // Navigation with replacement (no back button)
  static Future<void> toWalletHomeReplacement(BuildContext context) async {
    await GuardedNavigator.pushReplacementNamed(context, WalletRoutes.wallet);
  }

  static Future<void> toFundWalletReplacement(BuildContext context) async {
    await GuardedNavigator.pushReplacement(context,
      MaterialPageRoute(builder: (_) => const EnhancedFundWalletScreen()),
    );
  }

  // Navigation and clear stack
  static Future<void> toWalletHomeAndClearStack(BuildContext context) async {
    await GuardedNavigator.pushNamedAndRemoveUntil(context,
      WalletRoutes.wallet,
      (route) => false,
    );
  }

  // Pop current screen
  static void pop(BuildContext context, [dynamic result]) {
    Navigator.pop(context, result);
  }

  // Pop until specific route
  static void popUntil(BuildContext context, String routeName) {
    Navigator.popUntil(context, ModalRoute.withName(routeName));
  }

  // Pop until wallet home
  static void popToWalletHome(BuildContext context) {
    Navigator.popUntil(context, ModalRoute.withName(WalletRoutes.wallet));
  }

  // Check if can pop
  static bool canPop(BuildContext context) {
    return Navigator.canPop(context);
  }

  // Show modal bottom sheet with custom wallet content
  static Future<T?> showWalletBottomSheet<T>(
    BuildContext context,
    Widget child, {
    bool isScrollControlled = true,
    bool enableDrag = true,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      enableDrag: enableDrag,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: child,
      ),
    );
  }

  // Show wallet dialog
  static Future<T?> showWalletDialog<T>(
    BuildContext context,
    Widget child, {
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => child,
    );
  }

  // Navigation with animation control
  static Future<void> navigateWithCustomTransition(
    BuildContext context,
    Widget destination, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
    SlideDirection direction = SlideDirection.rightToLeft,
  }) async {
    Offset beginOffset;
    switch (direction) {
      case SlideDirection.rightToLeft:
        beginOffset = const Offset(1.0, 0.0);
        break;
      case SlideDirection.leftToRight:
        beginOffset = const Offset(-1.0, 0.0);
        break;
      case SlideDirection.topToBottom:
        beginOffset = const Offset(0.0, -1.0);
        break;
      case SlideDirection.bottomToTop:
        beginOffset = const Offset(0.0, 1.0);
        break;
    }

    await GuardedNavigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionDuration: duration,
        reverseTransitionDuration: duration,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var tween = Tween(begin: beginOffset, end: Offset.zero)
              .chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  // Get route arguments safely
  static T? getRouteArguments<T>(BuildContext context) {
    final Object? args = ModalRoute.of(context)?.settings.arguments;
    return args is T ? args : null;
  }

  // Check if current route matches
  static bool isCurrentRoute(BuildContext context, String routeName) {
    final ModalRoute? route = ModalRoute.of(context);
    return route?.settings.name == routeName;
  }

  // Get current route name
  static String? getCurrentRouteName(BuildContext context) {
    return ModalRoute.of(context)?.settings.name;
  }

  // Navigate back with delay (useful for showing success messages)
  static Future<void> popWithDelay(
    BuildContext context, {
    Duration delay = const Duration(seconds: 2),
    dynamic result,
  }) async {
    await Future.delayed(delay);
    if (Navigator.canPop(context)) {
      Navigator.pop(context, result);
    }
  }

  // Quick actions navigation (commonly used paths)
  static Map<String, VoidCallback> getQuickActions(BuildContext context) {
    return {
      'Fund Wallet': () => toFundWallet(context),
      'Send BYC': () => toSendBYC(context),
      'Receive BYC': () => toReceiveBYC(context),
      'View Transactions': () => toTransactionHistory(context),
      'Currency Rates': () => toConversion(context),
      'Promotions': () => toPromotionCenter(context),
    };
  }

  // Error handling for navigation
  static void handleNavigationError(
    BuildContext context,
    String routeName,
    Object error,
  ) {
    debugPrint('Navigation error to $routeName: $error');
    
    // Show error snackbar
    AppToast.error(context, 'Failed to navigate to ${routeName.replaceAll('/', ' ')}');
  }
}

enum SlideDirection {
  rightToLeft,
  leftToRight,
  topToBottom,
  bottomToTop,
}