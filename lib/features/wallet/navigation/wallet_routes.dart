import 'package:flutter/material.dart';
import 'package:bybata/core/widgets/auth_gate.dart';
import '../screens/wallet_screen.dart';
import '../screens/enhanced_fund_wallet_screen.dart';
import '../screens/transfer_byc_screen.dart';
import '../screens/receive_byc_screen.dart';
import '../screens/transaction_history_screen.dart';
import '../screens/promotion_center_screen.dart';
import '../screens/create_ad_screen.dart';
import '../screens/edit_ad_screen.dart';
import '../screens/conversion_screen.dart';
import '../screens/earn_byc_screen.dart';

class WalletRoutes {
  static const String wallet = '/wallet';
  static const String fundWallet = '/wallet/fund';
  static const String sendBYC = '/wallet/send';
  static const String receiveBYC = '/wallet/receive';
  static const String transactionHistory = '/wallet/transactions';
  static const String promotionCenter = '/wallet/promotions';
  static const String createAd = '/wallet/create-ad';
  static const String editAd = '/wallet/edit-ad';
  static const String conversion = '/wallet/conversion';
  static const String earnBYC = '/wallet/earn';

  // Route generator for wallet module
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case wallet:
        return _createRoute(const WalletScreen());
      
      case fundWallet:
        return _createRoute(const EnhancedFundWalletScreen());
      
      case sendBYC:
        return _createRoute(const TransferBYCScreen());
      
      case receiveBYC:
        return _createRoute(const ReceiveBYCScreen());
      
      case transactionHistory:
        return _createRoute(const TransactionHistoryScreen());
      
      case promotionCenter:
        return _createRoute(const PromotionCenterScreen());

      case createAd:
        return _createRoute(const CreateAdScreen());

      case editAd:
        final ad = settings.arguments as Map<String, dynamic>?;
        if (ad == null) return null;
        return _createRoute(EditAdScreen(ad: ad));
      
      case conversion:
        return _createRoute(const ConversionScreen());
      
      case earnBYC:
        return _createRoute(const EarnBYCScreen());
      
      default:
        return null;
    }
  }

  // Create route with custom transition
  static PageRouteBuilder _createRoute(Widget screen, {bool requireAuth = true}) {
    final child = requireAuth ? AuthGate(child: screen) : screen;
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  // Get all wallet routes
  static Map<String, WidgetBuilder> getRoutes() {
    Widget gated(Widget screen) => AuthGate(child: screen);
    return {
      wallet: (context) => gated(const WalletScreen()),
      fundWallet: (context) => gated(const EnhancedFundWalletScreen()),
      sendBYC: (context) => gated(const TransferBYCScreen()),
      receiveBYC: (context) => gated(const ReceiveBYCScreen()),
      transactionHistory: (context) => gated(const TransactionHistoryScreen()),
      promotionCenter: (context) => gated(const PromotionCenterScreen()),
      createAd: (context) => gated(const CreateAdScreen()),
      conversion: (context) => gated(const ConversionScreen()),
      earnBYC: (context) => gated(const EarnBYCScreen()),
    };
  }

  // Route names for easier access
  static const Map<String, String> routeNames = {
    'wallet': wallet,
    'fundWallet': fundWallet,
    'sendBYC': sendBYC,
    'receiveBYC': receiveBYC,
    'transactionHistory': transactionHistory,
    'promotionCenter': promotionCenter,
    'createAd': createAd,
    'editAd': editAd,
    'conversion': conversion,
    'earnBYC': earnBYC,
  };
}