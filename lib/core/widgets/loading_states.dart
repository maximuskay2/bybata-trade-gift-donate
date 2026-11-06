import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bybata_loading_indicator.dart';

/// Enhanced loading state system with progress indicators and contextual messages

class SmartLoadingIndicator extends StatelessWidget {
  final String? message;
  final String? subMessage;
  final double? progress;
  final LoadingType type;
  final Color? color;
  final double size;
  final bool showProgress;
  final Duration? estimatedDuration;

  const SmartLoadingIndicator({
    Key? key,
    this.message,
    this.subMessage,
    this.progress,
    this.type = LoadingType.bybata,
    this.color,
    this.size = 48.0,
    this.showProgress = false,
    this.estimatedDuration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLoadingIndicator(context),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (subMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                subMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (showProgress && progress != null) ...[
              const SizedBox(height: 16),
              _buildProgressText(),
            ],
            if (estimatedDuration != null) ...[
              const SizedBox(height: 8),
              Text(
                'Estimated time: ${_formatDuration(estimatedDuration!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    final indicatorColor = color ?? Theme.of(context).primaryColor;

    switch (type) {
      case LoadingType.bybata:
        return BybataLoadingIndicator(
          size: size >= 32
              ? BybataLoadingSize.large
              : size >= 20
                  ? BybataLoadingSize.medium
                  : BybataLoadingSize.compact,
          color: indicatorColor,
          highlightColor: indicatorColor,
        );

      case LoadingType.circular:
        return SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            value: progress,
            color: indicatorColor,
            strokeWidth: 3,
          ),
        );
      
      case LoadingType.linear:
        return Container(
          width: size * 2,
          child: LinearProgressIndicator(
            value: progress,
            color: indicatorColor,
            backgroundColor: indicatorColor.withValues(alpha: 0.2),
            minHeight: 6,
          ),
        );
      
      case LoadingType.adaptive:
        return SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator.adaptive(
            value: progress,
            valueColor: AlwaysStoppedAnimation(indicatorColor),
          ),
        );
      
      case LoadingType.dots:
        return _buildDotsIndicator(indicatorColor);
      
      case LoadingType.pulse:
        return _buildPulseIndicator(indicatorColor);
    }
  }

  Widget _buildDotsIndicator(Color color) {
    return SizedBox(
      width: size,
      height: size / 4,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return AnimatedContainer(
            duration: Duration(milliseconds: 600 + (index * 200)),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPulseIndicator(Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.3),
      ),
      child: Center(
        child: Container(
          width: size * 0.6,
          height: size * 0.6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressText() {
    final percentage = ((progress ?? 0) * 100).toInt();
    return Text(
      '$percentage%',
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}

enum LoadingType { bybata, circular, linear, adaptive, dots, pulse }

/// Full screen loading overlay
class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? message;
  final String? subMessage;
  final double? progress;
  final LoadingType type;
  final Color? overlayColor;
  final bool dismissible;

  const LoadingOverlay({
    Key? key,
    required this.child,
    required this.isLoading,
    this.message,
    this.subMessage,
    this.progress,
    this.type = LoadingType.bybata,
    this.overlayColor,
    this.dismissible = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: GestureDetector(
              onTap: dismissible ? () {} : null,
              child: Container(
                color: overlayColor ?? Colors.black.withValues(alpha: 0.5),
                child: SmartLoadingIndicator(
                  message: message,
                  subMessage: subMessage,
                  progress: progress,
                  type: type,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Loading dialog that can be shown over content
class LoadingDialog extends StatelessWidget {
  final String? title;
  final String? message;
  final double? progress;
  final bool showProgress;
  final VoidCallback? onCancel;
  final LoadingType type;

  const LoadingDialog({
    Key? key,
    this.title,
    this.message,
    this.progress,
    this.showProgress = false,
    this.onCancel,
    this.type = LoadingType.bybata,
  }) : super(key: key);

  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? message,
    double? progress,
    bool showProgress = false,
    VoidCallback? onCancel,
    LoadingType type = LoadingType.bybata,
    bool barrierDismissible = false,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => LoadingDialog(
        title: title,
        message: message,
        progress: progress,
        showProgress: showProgress,
        onCancel: onCancel,
        type: type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SmartLoadingIndicator(
              message: title,
              subMessage: message,
              progress: progress,
              type: type,
              showProgress: showProgress,
            ),
            if (onCancel != null) ...[
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onCancel!();
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmer loading effect for list items
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration period;

  const ShimmerLoading({
    Key? key,
    required this.child,
    this.enabled = true,
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
    );
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(ShimmerLoading oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _controller.repeat();
    } else if (!widget.enabled && oldWidget.enabled) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final baseColor = widget.baseColor ?? Colors.grey.shade300;
    final highlightColor = widget.highlightColor ?? Colors.grey.shade100;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                _animation.value - 1.0,
                _animation.value,
                _animation.value + 1.0,
              ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Skeleton loading for cards and lists
class SkeletonLoader extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    Key? key,
    this.width,
    this.height = 16,
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

/// List of skeleton items for loading lists
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final Widget? Function(BuildContext, int) itemBuilder;
  final EdgeInsetsGeometry? padding;

  const SkeletonList({
    Key? key,
    this.itemCount = 5,
    required this.itemBuilder,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

/// Predefined skeleton cards
class SkeletonCard extends StatelessWidget {
  final bool showAvatar;
  final bool showImage;
  final int lineCount;

  const SkeletonCard({
    Key? key,
    this.showAvatar = true,
    this.showImage = false,
    this.lineCount = 3,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showAvatar)
              Row(
                children: [
                  const SkeletonLoader(
                    width: 40,
                    height: 40,
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLoader(
                          width: MediaQuery.of(context).size.width * 0.3,
                          height: 14,
                        ),
                        const SizedBox(height: 4),
                        SkeletonLoader(
                          width: MediaQuery.of(context).size.width * 0.2,
                          height: 12,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            if (showAvatar && (showImage || lineCount > 0)) 
              const SizedBox(height: 12),
            if (showImage) ...[
              SkeletonLoader(
                width: double.infinity,
                height: 200,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 12),
            ],
            ...List.generate(lineCount, (index) => Padding(
              padding: EdgeInsets.only(bottom: index < lineCount - 1 ? 8 : 0),
              child: SkeletonLoader(
                width: index == lineCount - 1
                    ? MediaQuery.of(context).size.width * 0.6
                    : double.infinity,
                height: 12,
              ),
            )),
          ],
        ),
      ),
    );
  }
}