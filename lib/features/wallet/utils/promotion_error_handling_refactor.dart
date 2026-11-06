/**
 * REFACTORED PROMOTION FLOW ERROR HANDLING
 * 
 * This file shows the recommended error handling improvements
 * to be applied to promotion_center_screen.dart
 * 
 * Changes:
 * 1. Import PromotionErrorHandler
 * 2. Replace generic error messages with parsed messages
 * 3. Add retry mechanisms for network errors
 * 4. Show action buttons in snackbars
 * 5. Track error events for analytics
 */

// --- IMPORT ADDITIONS ---
import 'package:flutter/material.dart';
import '../utils/promotion_error_handler.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/theme/app_theme.dart';

// --- ENHANCED ERROR HANDLING METHODS ---

/// Refactored promotion purchase with comprehensive error handling
Future<void> _openPromotionPickerRefactored({
  required String referenceType,
  required String referenceId,
  required String title,
}) async {
  final plans = _walletService.promotionPlans;
  
  // Handle no promotions available
  if (plans.isEmpty) {
    await _showNoPromotionsModal(referenceType, referenceId, title);
    return;
  }
  
  // Show promotion selection modal
  final selected = await showModalBottomSheet<PromotionPlan>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Promote "$title"', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          ...plans.map((plan) => ListTile(
            title: Text(plan.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${plan.amountByc.toStringAsFixed(0)} BYC'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.pop(context, plan),
          )),
        ],
      ),
    ),
  );
  
  if (selected == null) return;
  
  // Show loading state
  _showLoadingDialog('Activating promotion...');
  
  try {
    // Attempt purchase
    final ok = await _walletService.purchasePromotion(
      plan: selected,
      referenceType: referenceType,
      referenceId: referenceId,
    );
    
    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog
    
    if (ok) {
      // SUCCESS - Show comprehensive success message
      final successMsg = PromotionSuccessHandler.getSuccessMessage(
        itemTitle: title,
        promotionType: 'promotion',
      );
      _showSnackBarWithAction(
        successMsg,
        type: ToastType.success,
        actionLabel: 'View',
        onAction: () => _navigateToPromotedItem(referenceType, referenceId),
      );
      
      // Track success event
      _trackPromotionEvent('promotion_purchased', {
        'title': title,
        'plan': selected.slug,
        'amount': selected.amountByc,
      });
      
      // Refresh promotions data
      await _walletService.refreshPromotionData();
    } else {
      // ERROR - Parse and display user-friendly message
      final errorMsg = PromotionErrorHandler.parseErrorMessage(_walletService.error);
      final isRetryable = PromotionErrorHandler.isRetryable(_walletService.error);
      
      _showSnackBarWithAction(
        errorMsg,
        type: ToastType.error,
        actionLabel: isRetryable ? 'Retry' : null,
        onAction: isRetryable 
          ? () => _openPromotionPickerRefactored(
              referenceType: referenceType,
              referenceId: referenceId,
              title: title,
            )
          : null,
      );
      
      // Track error event
      _trackPromotionEvent('promotion_failed', {
        'title': title,
        'error': _walletService.error,
        'errorType': _categorizeError(_walletService.error),
      });
    }
  } catch (e) {
    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog
    
    _showSnackBarWithAction(
      'An unexpected error occurred. Please try again.',
      type: ToastType.error,
      actionLabel: 'Retry',
      onAction: () => _openPromotionPickerRefactored(
        referenceType: referenceType,
        referenceId: referenceId,
        title: title,
      ),
    );
    
    _trackPromotionEvent('promotion_exception', {
      'title': title,
      'exception': e.toString(),
    });
  }
}

/// Refactored boost purchase with comprehensive error handling
Future<void> _purchaseBoostWithErrorHandling({
  required String referenceType,
  required String referenceId,
  required String boostTypeId,
  required int days,
  required String placementKey,
  required String title,
}) async {
  _showLoadingDialog('Activating boost...');
  
  try {
    final ok = await _walletService.purchaseBoost(
      referenceType: referenceType,
      referenceId: referenceId,
      boostTypeId: boostTypeId,
      days: days,
      placementKey: placementKey,
    );
    
    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog
    
    if (ok) {
      // SUCCESS
      final successMsg = PromotionSuccessHandler.getSuccessMessage(
        itemTitle: title,
        promotionType: 'boost',
        days: days,
      );
      _showSnackBarWithAction(
        successMsg,
        type: ToastType.success,
        actionLabel: 'View Analytics',
        onAction: () => _navigateToAnalytics(referenceType, referenceId),
      );
      
      _trackPromotionEvent('boost_purchased', {
        'title': title,
        'boostTypeId': boostTypeId,
        'days': days,
        'placement': placementKey,
      });
    } else {
      // ERROR
      final errorMsg = PromotionErrorHandler.parseErrorMessage(_walletService.error);
      final isRetryable = PromotionErrorHandler.isRetryable(_walletService.error);
      
      _showSnackBarWithAction(
        errorMsg,
        type: ToastType.error,
        actionLabel: isRetryable ? 'Retry' : null,
        onAction: isRetryable 
          ? () => _purchaseBoostWithErrorHandling(
              referenceType: referenceType,
              referenceId: referenceId,
              boostTypeId: boostTypeId,
              days: days,
              placementKey: placementKey,
              title: title,
            )
          : null,
      );
      
      _trackPromotionEvent('boost_failed', {
        'title': title,
        'error': _walletService.error,
      });
    }
  } catch (e) {
    if (!mounted) return;
    Navigator.pop(context);
    
    _showSnackBarWithAction(
      'An unexpected error occurred. Please try again.',
      type: ToastType.error,
      actionLabel: 'Retry',
      onAction: () => _purchaseBoostWithErrorHandling(
        referenceType: referenceType,
        referenceId: referenceId,
        boostTypeId: boostTypeId,
        days: days,
        placementKey: placementKey,
        title: title,
      ),
    );
    
    _trackPromotionEvent('boost_exception', {
      'title': title,
      'exception': e.toString(),
    });
  }
}

/// Enhanced snackbar with action support
void _showSnackBarWithAction(
  String message, {
  ToastType type = ToastType.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            _getIconFor(type),
            color: _getColorFor(type).foreground,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: _getColorFor(type).foreground,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _getColorFor(type).background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      duration: duration,
      action: (actionLabel != null && onAction != null)
          ? SnackBarAction(
              label: actionLabel,
              onPressed: onAction,
              textColor: _getColorFor(type).foreground,
            )
          : null,
    ),
  );
}

/// Show loading dialog
void _showLoadingDialog(String message) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BybataLoadingIndicator(size: BybataLoadingSize.compact),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Categorize error for analytics
String _categorizeError(String? error) {
  if (error == null) return 'unknown';
  final e = error.toLowerCase();
  
  if (e.contains('balance')) return 'insufficient_balance';
  if (e.contains('verification')) return 'verification_failed';
  if (e.contains('limit')) return 'limit_exceeded';
  if (e.contains('not found')) return 'not_found';
  if (e.contains('timeout') || e.contains('connection')) return 'network_error';
  if (e.contains('500')) return 'server_error';
  
  return 'other';
}

/// Track promotion events for analytics
void _trackPromotionEvent(String eventName, Map<String, dynamic> parameters) {
  // TODO: Implement Firebase Analytics or custom analytics
  // analytics.logEvent(name: eventName, parameters: parameters);
  print('📊 Event: $eventName | $parameters');
}

/// Navigate to promoted item
void _navigateToPromotedItem(String referenceType, String referenceId) {
  // TODO: Navigate based on referenceType (trade, gift, campaign, etc)
}

/// Navigate to analytics
void _navigateToAnalytics(String referenceType, String referenceId) {
  // TODO: Navigate to item analytics
}

// --- HELPER METHODS ---

IconData _getIconFor(ToastType type) {
  switch (type) {
    case ToastType.success:
      return Icons.check_circle;
    case ToastType.error:
      return Icons.error_outline;
    case ToastType.warning:
      return Icons.warning_amber;
    case ToastType.info:
      return Icons.info_outline;
  }
}

({Color background, Color foreground}) _getColorFor(ToastType type) {
  switch (type) {
    case ToastType.success:
      return (background: Colors.green.withValues(alpha: 0.1), foreground: Colors.green);
    case ToastType.error:
      return (background: Colors.red.withValues(alpha: 0.1), foreground: Colors.red);
    case ToastType.warning:
      return (background: Colors.orange.withValues(alpha: 0.1), foreground: Colors.orange);
    case ToastType.info:
      return (background: AppColors.primary.withValues(alpha: 0.1), foreground: AppColors.primary);
  }
}
