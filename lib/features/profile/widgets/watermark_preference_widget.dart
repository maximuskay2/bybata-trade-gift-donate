import 'package:flutter/material.dart';
import '../../../core/config/watermark_config.dart';

/// Widget for controlling watermark visibility preferences
class WatermarkPreferenceWidget extends StatefulWidget {
  final bool enableWatermark;
  final double watermarkOpacity;
  final Function(bool enable, double opacity) onChanged;

  const WatermarkPreferenceWidget({
    Key? key,
    required this.enableWatermark,
    required this.watermarkOpacity,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<WatermarkPreferenceWidget> createState() =>
      _WatermarkPreferenceWidgetState();
}

class _WatermarkPreferenceWidgetState extends State<WatermarkPreferenceWidget> {
  late bool _enableWatermark;
  late double _opacity;

  @override
  void initState() {
    super.initState();
    _enableWatermark = widget.enableWatermark;
    _opacity = widget.watermarkOpacity;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: isDark ? 0.3 : 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.2),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and info
          Row(
            children: [
              Icon(
                Icons.watermark,
                color: scheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Watermark Settings',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Protect your uploads with watermarks',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Enable/Disable Toggle
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _enableWatermark
                          ? Icons.check_circle
                          : Icons.cancel_outlined,
                      color: _enableWatermark
                          ? Colors.green
                          : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _enableWatermark
                          ? 'Watermarks Enabled'
                          : 'Watermarks Disabled',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _enableWatermark,
                  onChanged: (value) {
                    setState(() {
                      _enableWatermark = value;
                      // If disabling, don't worry about opacity
                      // If enabling, reset to full opacity
                      if (value && _opacity == 0) {
                        _opacity = 1.0;
                      }
                    });
                    widget.onChanged(_enableWatermark, _opacity);
                  },
                  activeColor: scheme.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Opacity Control (only show if watermarks are enabled)
          if (_enableWatermark) ...[
            Text(
              'Watermark Opacity',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                // Slider
                Slider(
                  value: _opacity,
                  onChanged: (value) {
                    setState(() {
                      _opacity = value;
                    });
                    widget.onChanged(_enableWatermark, _opacity);
                  },
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: '${(_opacity * 100).toStringAsFixed(0)}%',
                  activeColor: scheme.primary,
                ),
                const SizedBox(height: 8),
                // Opacity percentage display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Invisible',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(_opacity * 100).toStringAsFixed(0)}% Visible',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      'Maximum',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Preview info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: scheme.secondary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: scheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Preview: Your username will be ' +
                      (_opacity == 1.0
                          ? 'fully visible'
                          : _opacity == 0
                              ? 'invisible'
                              : 'semi-transparent') +
                      ' on all your uploads',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Disabled state info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    size: 18,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Watermarks are disabled. Your uploads will not have any watermark protection.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
