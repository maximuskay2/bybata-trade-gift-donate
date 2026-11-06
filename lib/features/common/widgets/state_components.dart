import 'package:flutter/material.dart';
import 'package:bybata/core/theme/app_theme.dart';

import '../../../core/utils/network_error_message.dart';
import '../../../core/widgets/bybata_loading_indicator.dart';

/// Empty state component for when lists or content are empty
class EmptyState extends StatelessWidget {
  final String title;
  final String? message;
  final IconData? icon;
  final String? illustration; // Asset path for illustration
  final String? actionText;
  final VoidCallback? onAction;
  final EmptyStateType type;
  final Widget? customContent;

  const EmptyState({
    Key? key,
    required this.title,
    this.message,
    this.icon,
    this.illustration,
    this.actionText,
    this.onAction,
    this.type = EmptyStateType.generic,
    this.customContent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration or Icon
            if (illustration != null)
              Image.asset(
                illustration!,
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              )
            else if (icon != null)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _getIconColor(theme).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: _getIconColor(theme),
                ),
              )
            else
              _getDefaultIcon(theme),
            
            const SizedBox(height: 24),
            
            // Title
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Message
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            
            // Custom content
            if (customContent != null) ...[
              const SizedBox(height: 16),
              customContent!,
            ],
            
            // Action button
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(_getActionIcon()),
                label: Text(actionText!),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _getDefaultIcon(ThemeData theme) {
    IconData defaultIcon;
    switch (type) {
      case EmptyStateType.search:
        defaultIcon = Icons.search_off;
        break;
      case EmptyStateType.favorites:
        defaultIcon = Icons.favorite_outline;
        break;
      case EmptyStateType.notifications:
        defaultIcon = Icons.notifications_none;
        break;
      case EmptyStateType.messages:
        defaultIcon = Icons.message_outlined;
        break;
      case EmptyStateType.activities:
        defaultIcon = Icons.local_activity_outlined;
        break;
      case EmptyStateType.transactions:
        defaultIcon = Icons.receipt_long_outlined;
        break;
      case EmptyStateType.generic:
      default:
        defaultIcon = Icons.inbox_outlined;
        break;
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: _getIconColor(theme).withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        defaultIcon,
        size: 40,
        color: _getIconColor(theme),
      ),
    );
  }

  Color _getIconColor(ThemeData theme) {
    switch (type) {
      case EmptyStateType.search:
        return Colors.orange;
      case EmptyStateType.favorites:
        return Colors.pink;
      case EmptyStateType.notifications:
        return AppColors.primary;
      case EmptyStateType.messages:
        return Colors.green;
      case EmptyStateType.activities:
        return Colors.purple;
      case EmptyStateType.transactions:
        return Colors.teal;
      case EmptyStateType.generic:
      default:
        return Colors.grey.shade500;
    }
  }

  IconData _getActionIcon() {
    switch (type) {
      case EmptyStateType.search:
        return Icons.search;
      case EmptyStateType.favorites:
        return Icons.explore;
      case EmptyStateType.notifications:
        return Icons.refresh;
      case EmptyStateType.messages:
        return Icons.add_comment;
      case EmptyStateType.activities:
        return Icons.add;
      case EmptyStateType.transactions:
        return Icons.add;
      case EmptyStateType.generic:
      default:
        return Icons.refresh;
    }
  }
}

/// Error state component for handling errors
class ErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final String? actionText;
  final VoidCallback? onRetry;
  final ErrorStateType type;
  final bool showDetails;
  final String? errorDetails;

  const ErrorState({
    Key? key,
    required this.title,
    this.message,
    this.actionText,
    this.onRetry,
    this.type = ErrorStateType.generic,
    this.showDetails = false,
    this.errorDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeMessage = message == null
        ? null
        : NetworkErrorMessage.sanitize(message!);
    final effectiveType = type != ErrorStateType.generic
        ? type
        : _typeFromMessage(safeMessage);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _getErrorColor(effectiveType).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getErrorIcon(effectiveType),
                size: 40,
                color: _getErrorColor(effectiveType),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Title
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Message
            if (safeMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                safeMessage,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            
            // Error Details (Expandable) — debug only callers should set showDetails
            if (showDetails && errorDetails != null) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text(
                  'Error Details',
                  style: TextStyle(fontSize: 14),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      errorDetails!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            
            // Retry button
            if (actionText != null && onRetry != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(actionText!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getErrorColor(effectiveType),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  ErrorStateType _typeFromMessage(String? message) {
    if (NetworkErrorMessage.messageIndicatesOffline(message) ||
        NetworkErrorMessage.messageIndicatesTimeout(message)) {
      return ErrorStateType.network;
    }
    return type;
  }

  Color _getErrorColor([ErrorStateType? t]) {
    switch (t ?? type) {
      case ErrorStateType.network:
        return Colors.orange;
      case ErrorStateType.server:
        return Colors.red;
      case ErrorStateType.authentication:
        return Colors.purple;
      case ErrorStateType.permission:
        return Colors.amber;
      case ErrorStateType.generic:
      default:
        return Colors.red.shade400;
    }
  }

  IconData _getErrorIcon([ErrorStateType? t]) {
    switch (t ?? type) {
      case ErrorStateType.network:
        return Icons.wifi_off;
      case ErrorStateType.server:
        return Icons.cloud_off;
      case ErrorStateType.authentication:
        return Icons.lock_outline;
      case ErrorStateType.permission:
        return Icons.block;
      case ErrorStateType.generic:
      default:
        return Icons.error_outline;
    }
  }
}

/// Loading state component
class LoadingState extends StatelessWidget {
  final String? message;
  final LoadingStateType type;
  final Color? color;
  final double? size;

  const LoadingState({
    Key? key,
    this.message,
    this.type = LoadingStateType.bybata,
    this.color,
    this.size,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loadingColor = color ?? theme.primaryColor;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLoadingIndicator(loadingColor),
            if (message != null) ...[
              const SizedBox(height: 24),
              Text(
                message!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(Color color) {
    final indicatorSize = size ?? 48.0;

    switch (type) {
      case LoadingStateType.bybata:
        return BybataLoadingIndicator(
          size: indicatorSize >= 32
              ? BybataLoadingSize.large
              : indicatorSize >= 20
                  ? BybataLoadingSize.medium
                  : BybataLoadingSize.compact,
          color: color,
          highlightColor: color,
        );

      case LoadingStateType.circular:
        return SizedBox(
          width: indicatorSize,
          height: indicatorSize,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(color),
            strokeWidth: 3,
          ),
        );
      
      case LoadingStateType.linear:
        return SizedBox(
          width: 200,
          child: LinearProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(color),
            backgroundColor: color.withValues(alpha: 0.2),
          ),
        );
      
      case LoadingStateType.dots:
        return _buildDotsIndicator(color);
      
      case LoadingStateType.pulse:
        return _buildPulseIndicator(color, indicatorSize);
    }
  }

  Widget _buildDotsIndicator(Color color) {
    return SizedBox(
      width: 60,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: Duration(milliseconds: 600 + (index * 200)),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: value),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
            onEnd: () {
              // Animation will repeat automatically
            },
          );
        }),
      ),
    );
  }

  Widget _buildPulseIndicator(Color color, double size) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.2),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {
        // Animation will repeat automatically
      },
    );
  }
}

/// Network state component for connectivity issues
class NetworkState extends StatelessWidget {
  final bool isConnected;
  final String? offlineMessage;
  final String? reconnectingMessage;
  final VoidCallback? onRetry;

  const NetworkState({
    Key? key,
    required this.isConnected,
    this.offlineMessage,
    this.reconnectingMessage,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isConnected) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: Colors.orange.shade100,
        child: SafeArea(
          child: Row(
            children: [
              Icon(
                Icons.wifi_off,
                color: Colors.orange.shade700,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  offlineMessage ?? 'No internet connection',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search state component for search results
class SearchState extends StatelessWidget {
  final String query;
  final int resultCount;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onClear;
  final String? loadingMessage;
  final String? errorMessage;

  const SearchState({
    Key? key,
    required this.query,
    required this.resultCount,
    this.isLoading = false,
    this.hasError = false,
    this.onClear,
    this.loadingMessage,
    this.errorMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              loadingMessage ?? 'Searching for "$query"...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (hasError) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: Colors.red.shade50,
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade600,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                errorMessage ?? 'Error searching for "$query"',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                icon: Icon(
                  Icons.close,
                  color: Colors.red.shade600,
                  size: 20,
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                ),
                children: [
                  TextSpan(
                    text: '$resultCount result${resultCount != 1 ? 's' : ''} for "',
                  ),
                  TextSpan(
                    text: query,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const TextSpan(text: '"'),
                ],
              ),
            ),
          ),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              icon: Icon(
                Icons.close,
                color: AppColors.primary,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}

/// Shimmer loading component for skeleton screens
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration period;

  const ShimmerLoading({
    Key? key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.period = const Duration(milliseconds: 1500),
  }) : super(key: key);

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.period,
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.baseColor ?? Colors.grey.shade300;
    final highlightColor = widget.highlightColor ?? Colors.grey.shade100;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ],
              transform: GradientRotation(_animation.value),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Pre-built shimmer containers
class ShimmerContainer extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const ShimmerContainer({
    Key? key,
    this.width,
    this.height,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: borderRadius ?? BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// Enumerations for different state types
enum EmptyStateType {
  generic,
  search,
  favorites,
  notifications,
  messages,
  activities,
  transactions,
}

enum ErrorStateType {
  generic,
  network,
  server,
  authentication,
  permission,
}

enum LoadingStateType {
  bybata,
  circular,
  linear,
  dots,
  pulse,
}