import 'package:flutter/material.dart';
import 'dart:ui';

/// [OptionalLocationCard] provides an improved location selection UX:
/// - Location is disabled by default (user chooses to add)
/// - Shows inline option to use current location or enter manually
/// - No permission friction on screen load
/// - Beautiful card-based UI
class OptionalLocationCard extends StatefulWidget {
  final TextEditingController controller;
  final bool isDark;
  final Color primaryColor;
  final VoidCallback onLocationRequested;
  final Function(String)? onLocationChanged;
  final bool required;
  final bool showValidationHighlight;

  const OptionalLocationCard({
    super.key,
    required this.controller,
    required this.isDark,
    required this.primaryColor,
    required this.onLocationRequested,
    this.onLocationChanged,
    this.required = false,
    this.showValidationHighlight = false,
  });

  @override
  State<OptionalLocationCard> createState() => _OptionalLocationCardState();
}

class _OptionalLocationCardState extends State<OptionalLocationCard> {
  late bool _isExpanded;
  bool _isLoadingLocation = false;
  bool _useCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.required || widget.controller.text.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant OptionalLocationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.required && widget.controller.text.isEmpty && !_isExpanded) {
      _isExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? const Color(0xFF1E1E24) : Colors.white;
    final locationMissing =
        widget.required &&
        widget.showValidationHighlight &&
        widget.controller.text.trim().isEmpty;
    final borderColor = locationMissing
        ? Colors.red
        : (widget.isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.grey[300] ?? Colors.grey);

    // Compact view (collapsed)
    if (!_isExpanded && widget.controller.text.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isExpanded = true),
            child: Container(
              decoration: BoxDecoration(
                color: bgColor.withOpacity(0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: locationMissing ? 2 : 1.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      color: widget.primaryColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.required ? 'Add location (required)' : 'Add location (optional)',
                      style: TextStyle(
                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: widget.isDark ? Colors.grey[500] : Colors.grey[400]),
                ],
              ),
            ),
          ),
          if (locationMissing) ...[
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: Colors.red),
                SizedBox(width: 6),
                Text(
                  'Location is required',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    // Expanded view
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.required ? 'Location (required)' : 'Location',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() {
                _isExpanded = false;
                if (widget.controller.text.isEmpty) {
                  _useCurrentLocation = false;
                }
              }),
              child: Text(
                'Hide',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Options: Use Current or Enter Manual
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _isLoadingLocation
                    ? null
                    : () {
                        setState(() => _isLoadingLocation = true);
                        widget.onLocationRequested();
                        setState(() {
                          _useCurrentLocation = true;
                          _isLoadingLocation = false;
                        });
                      },
                child: Container(
                  decoration: BoxDecoration(
                    color: _useCurrentLocation
                        ? widget.primaryColor.withValues(alpha: 0.15)
                        : bgColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _useCurrentLocation
                          ? widget.primaryColor
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _isLoadingLocation
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    widget.primaryColor),
                              ),
                            )
                          : Icon(Icons.my_location_rounded,
                              color: widget.primaryColor, size: 24),
                      const SizedBox(height: 8),
                      Text(
                        'Use Current',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _useCurrentLocation
                              ? widget.primaryColor
                              : (widget.isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _useCurrentLocation = false),
                child: Container(
                  decoration: BoxDecoration(
                    color: !_useCurrentLocation
                        ? widget.primaryColor.withValues(alpha: 0.15)
                        : bgColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !_useCurrentLocation
                          ? widget.primaryColor
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Icon(Icons.edit_location_alt_rounded,
                          color: widget.primaryColor, size: 24),
                      const SizedBox(height: 8),
                      Text(
                        'Enter Manual',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: !_useCurrentLocation
                              ? widget.primaryColor
                              : (widget.isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Text input (visible only if manual entry selected)
        if (!_useCurrentLocation || widget.controller.text.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: bgColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: locationMissing
                    ? Colors.red
                    : (widget.isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey[300] ?? Colors.grey),
                width: locationMissing ? 2 : 1.5,
              ),
            ),
            child: TextField(
              controller: widget.controller,
              onChanged: (value) => widget.onLocationChanged?.call(value),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'e.g., Lagos, Nigeria',
                prefixIcon: Icon(Icons.location_on_outlined,
                    color: widget.isDark
                        ? Colors.grey[500]
                        : Colors.grey[400]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
                hintStyle: TextStyle(
                  color: widget.isDark ? Colors.grey[600] : Colors.grey[400],
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
        if (locationMissing) ...[
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.error_outline, size: 14, color: Colors.red),
              SizedBox(width: 6),
              Text(
                'Location is required',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
