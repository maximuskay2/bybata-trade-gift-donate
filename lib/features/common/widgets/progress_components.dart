import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bybata/core/theme/app_theme.dart';

/// Countdown timer component for time-limited content
class CountdownTimer extends StatefulWidget {
  final DateTime endTime;
  final CountdownTimerStyle style;
  final VoidCallback? onComplete;
  final String? completedText;
  final bool showMilliseconds;
  final Color? textColor;
  final Color? backgroundColor;

  const CountdownTimer({
    Key? key,
    required this.endTime,
    this.style = CountdownTimerStyle.standard,
    this.onComplete,
    this.completedText,
    this.showMilliseconds = false,
    this.textColor,
    this.backgroundColor,
  }) : super(key: key);

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _calculateRemainingTime();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateRemainingTime() {
    final now = DateTime.now();
    if (widget.endTime.isAfter(now)) {
      setState(() {
        _remainingTime = widget.endTime.difference(now);
        _isCompleted = false;
      });
    } else {
      setState(() {
        _remainingTime = Duration.zero;
        _isCompleted = true;
      });
      widget.onComplete?.call();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(
      widget.showMilliseconds 
          ? const Duration(milliseconds: 100) 
          : const Duration(seconds: 1),
      (timer) => _calculateRemainingTime(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCompleted) {
      return _buildCompletedWidget();
    }

    switch (widget.style) {
      case CountdownTimerStyle.standard:
        return _buildStandardTimer();
      case CountdownTimerStyle.compact:
        return _buildCompactTimer();
      case CountdownTimerStyle.card:
        return _buildCardTimer();
      case CountdownTimerStyle.circular:
        return _buildCircularTimer();
    }
  }

  Widget _buildStandardTimer() {
    final components = _getTimeComponents();
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (components['days']! > 0) ...[
          _buildTimeUnit('${components['days']}', 'Days'),
          const SizedBox(width: 8),
        ],
        if (components['hours']! > 0 || components['days']! > 0) ...[
          _buildTimeUnit('${components['hours']!.toString().padLeft(2, '0')}', 'Hours'),
          const SizedBox(width: 8),
        ],
        _buildTimeUnit('${components['minutes']!.toString().padLeft(2, '0')}', 'Min'),
        const SizedBox(width: 8),
        _buildTimeUnit('${components['seconds']!.toString().padLeft(2, '0')}', 'Sec'),
      ],
    );
  }

  Widget _buildCompactTimer() {
    final components = _getTimeComponents();
    String timeString = '';
    
    if (components['days']! > 0) {
      timeString = '${components['days']}d ${components['hours']!.toString().padLeft(2, '0')}h';
    } else if (components['hours']! > 0) {
      timeString = '${components['hours']!.toString().padLeft(2, '0')}:${components['minutes']!.toString().padLeft(2, '0')}:${components['seconds']!.toString().padLeft(2, '0')}';
    } else {
      timeString = '${components['minutes']!.toString().padLeft(2, '0')}:${components['seconds']!.toString().padLeft(2, '0')}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            size: 16,
            color: widget.textColor ?? Colors.red.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            timeString,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.textColor ?? Colors.red.shade700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTimer() {
    final components = _getTimeComponents();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.access_time,
              size: 24,
              color: Colors.red,
            ),
            const SizedBox(height: 8),
            const Text(
              'Time Remaining',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (components['days']! > 0) ...[
                  _buildTimeUnitLarge('${components['days']}', 'Days'),
                  const SizedBox(width: 12),
                ],
                _buildTimeUnitLarge('${components['hours']!.toString().padLeft(2, '0')}', 'Hours'),
                const SizedBox(width: 12),
                _buildTimeUnitLarge('${components['minutes']!.toString().padLeft(2, '0')}', 'Min'),
                const SizedBox(width: 12),
                _buildTimeUnitLarge('${components['seconds']!.toString().padLeft(2, '0')}', 'Sec'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularTimer() {
    final totalSeconds = widget.endTime.difference(DateTime.now().subtract(_remainingTime)).inSeconds;
    final remainingSeconds = _remainingTime.inSeconds;
    final progress = totalSeconds > 0 ? (totalSeconds - remainingSeconds) / totalSeconds : 0.0;

    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            strokeWidth: 6,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.textColor ?? Colors.red,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getRemainingTime(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.textColor ?? Colors.red,
                ),
              ),
              Text(
                'left',
                style: TextStyle(
                  fontSize: 10,
color: widget.textColor?.withValues(alpha: 0.7) ?? Colors.red.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? Colors.grey.shade800,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: widget.textColor ?? Colors.white,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeUnitLarge(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? Colors.red.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: widget.textColor ?? Colors.red.shade700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: Colors.green.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            widget.completedText ?? 'Completed',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _getTimeComponents() {
    return {
      'days': _remainingTime.inDays,
      'hours': _remainingTime.inHours % 24,
      'minutes': _remainingTime.inMinutes % 60,
      'seconds': _remainingTime.inSeconds % 60,
    };
  }

  String _getRemainingTime() {
    if (_remainingTime.inDays > 0) {
      return '${_remainingTime.inDays}d';
    } else if (_remainingTime.inHours > 0) {
      return '${_remainingTime.inHours}h';
    } else if (_remainingTime.inMinutes > 0) {
      return '${_remainingTime.inMinutes}m';
    } else {
      return '${_remainingTime.inSeconds}s';
    }
  }
}

/// Progress bar component for campaigns and levels
class ProgressBar extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final double? height;
  final Color? backgroundColor;
  final Color? valueColor;
  final BorderRadius? borderRadius;
  final bool showPercentage;
  final String? label;
  final ProgressBarStyle style;

  const ProgressBar({
    Key? key,
    required this.value,
    this.height,
    this.backgroundColor,
    this.valueColor,
    this.borderRadius,
    this.showPercentage = false,
    this.label,
    this.style = ProgressBarStyle.standard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case ProgressBarStyle.standard:
        return _buildStandardProgress(context);
      case ProgressBarStyle.withLabel:
        return _buildProgressWithLabel(context);
      case ProgressBarStyle.circular:
        return _buildCircularProgress(context);
      case ProgressBarStyle.stepped:
        return _buildSteppedProgress(context);
    }
  }

  Widget _buildStandardProgress(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null || showPercentage) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (label != null)
                Text(
                  label!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (showPercentage)
                Text(
                  '${(value * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Container(
          width: double.infinity,
          height: height ?? 8,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.grey.shade200,
            borderRadius: borderRadius ?? BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: valueColor ?? Theme.of(context).primaryColor,
                borderRadius: borderRadius ?? BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressWithLabel(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStandardProgress(context),
        ),
        const SizedBox(width: 12),
        Text(
          '${(value * 100).round()}%',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCircularProgress(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 6,
            backgroundColor: backgroundColor ?? Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              valueColor ?? Theme.of(context).primaryColor,
            ),
          ),
          Text(
            '${(value * 100).round()}%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSteppedProgress(BuildContext context) {
    const steps = 5;
    final completedSteps = (value * steps).round();

    return Row(
      children: List.generate(steps, (index) {
        final isCompleted = index < completedSteps;
        final isActive = index == completedSteps - 1;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < steps - 1 ? 4 : 0),
            height: height ?? 8,
            decoration: BoxDecoration(
              color: isCompleted
                  ? (valueColor ?? Theme.of(context).primaryColor)
                  : (backgroundColor ?? Colors.grey.shade200),
              borderRadius: BorderRadius.circular(4),
              border: isActive
                  ? Border.all(
                      color: valueColor ?? Theme.of(context).primaryColor,
                      width: 2,
                    )
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

/// Campaign progress card
class CampaignProgressCard extends StatelessWidget {
  final String title;
  final double currentAmount;
  final double targetAmount;
  final int donorCount;
  final DateTime? deadline;
  final VoidCallback? onTap;

  const CampaignProgressCard({
    Key? key,
    required this.title,
    required this.currentAmount,
    required this.targetAmount,
    required this.donorCount,
    this.deadline,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progress = targetAmount > 0 ? currentAmount / targetAmount : 0.0;
    final percentage = (progress * 100).round();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              
              // Progress bar
              ProgressBar(
                value: progress,
                height: 8,
                showPercentage: false,
                valueColor: _getProgressColor(progress),
              ),
              
              const SizedBox(height: 12),
              
              // Stats row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$${currentAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          'of \$${targetAmount.toStringAsFixed(0)} goal',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
color: _getProgressColor(progress).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _getProgressColor(progress),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Bottom info
              Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$donorCount donors',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (deadline != null) ...[
                    const Spacer(),
                    CountdownTimer(
                      endTime: deadline!,
                      style: CountdownTimerStyle.compact,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 1.0) {
      return Colors.green;
    } else if (progress >= 0.75) {
      return Colors.lightGreen;
    } else if (progress >= 0.5) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}

/// Level progress indicator
class LevelProgressIndicator extends StatelessWidget {
  final int currentLevel;
  final double currentXP;
  final double nextLevelXP;
  final String? levelName;

  const LevelProgressIndicator({
    Key? key,
    required this.currentLevel,
    required this.currentXP,
    required this.nextLevelXP,
    this.levelName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progress = nextLevelXP > 0 ? currentXP / nextLevelXP : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Colors.purple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'LV $currentLevel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (levelName != null)
                Expanded(
                  child: Text(
                    levelName!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ProgressBar(
            value: progress,
backgroundColor: Colors.white.withValues(alpha: 0.3),
            valueColor: Colors.white,
            height: 10,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${currentXP.toInt()} XP',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(nextLevelXP - currentXP).toInt()} to next level',
                style: TextStyle(
color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Timer style enumeration
enum CountdownTimerStyle {
  standard,
  compact,
  card,
  circular,
}

/// Progress bar style enumeration
enum ProgressBarStyle {
  standard,
  withLabel,
  circular,
  stepped,
}