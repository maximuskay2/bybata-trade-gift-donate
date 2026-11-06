import 'package:flutter/material.dart';
import 'dart:ui';

/// [EnhancedFormField] provides real-time validation, visual feedback, and better UX.
/// 
/// Features:
/// - Real-time validation with inline error messages
/// - Visual feedback (green check, red X icons)
/// - Optional field indicators (*Required)
/// - Helper text for context
/// - Supports custom validators
/// - Reduces form friction significantly
class EnhancedFormField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? helperText;
  final IconData? icon;
  final bool isRequired;
  final int maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator; // Real-time validator
  final VoidCallback? onChanged;
  final bool isDark;
  final int minLength;
  final int? maxLength;
  /// When true (after a failed submit/next), empty or invalid required fields show errors.
  final bool showValidationHighlight;

  const EnhancedFormField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.helperText,
    this.icon,
    this.isRequired = false,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    required this.isDark,
    this.minLength = 0,
    this.maxLength,
    this.showValidationHighlight = false,
  });

  @override
  State<EnhancedFormField> createState() => _EnhancedFormFieldState();
}

class _EnhancedFormFieldState extends State<EnhancedFormField> {
  String? _errorText;
  bool _isFocused = false;
  bool _isValid = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_validateField);
    _focusNode = FocusNode();
    _focusNode.addListener(() => setState(() => _isFocused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validateField);
    _focusNode.removeListener(() {});
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EnhancedFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showValidationHighlight != oldWidget.showValidationHighlight) {
      _validateField();
    }
  }

  void _validateField() {
    final value = widget.controller.text.trim();
    String? error;

    if (widget.isRequired && value.isEmpty) {
      if (widget.showValidationHighlight || _focusNode.hasFocus) {
        error = '${widget.label} is required';
      }
    } else if (widget.validator != null &&
        (value.isNotEmpty || widget.showValidationHighlight)) {
      error = widget.validator!(value);
    } else if (value.isNotEmpty && value.length < widget.minLength) {
      if (widget.showValidationHighlight || _focusNode.hasFocus) {
        error = 'Must be at least ${widget.minLength} characters';
      }
    }

    setState(() {
      _errorText = error;
      _isValid = error == null && (widget.isRequired ? value.isNotEmpty : true);
    });

    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? const Color(0xFF1E1E24) : Colors.white;
    final borderColor = _errorText != null
      ? Colors.red
      : _isValid
        ? Colors.green
        : (widget.isDark ? Colors.white.withOpacity(0.1) : (Colors.grey[300] ?? Colors.grey));
    const primaryColor = Color(0xFF5E35B1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label + Required indicator
        Row(
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (widget.isRequired)
              const Text(
                ' *',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Input field with glass morphism
        Container(
          decoration: BoxDecoration(
            color: bgColor.withOpacity(0.8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor ?? Colors.grey, width: 2),
            boxShadow: [
              if (_isFocused)
                BoxShadow(
                  color: primaryColor.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
            ],
          ),
          child: TextField(
            focusNode: _focusNode,
            controller: widget.controller,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            keyboardType: widget.keyboardType,
            onEditingComplete: () => _focusNode.unfocus(),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: widget.isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: widget.icon != null
                  ? Icon(widget.icon,
                      color: widget.isDark
                          ? Colors.grey[500]
                          : Colors.grey[400])
                  : null,
              suffixIcon: _buildSuffixIcon(),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
              hintStyle: TextStyle(
                color: widget.isDark ? Colors.grey[600] : Colors.grey[400],
                fontWeight: FontWeight.normal,
              ),
              counterText: '', // Hide character count by default
            ),
          ),
        ),

        // Error message or helper text
        const SizedBox(height: 6),
        if (_errorText != null)
          Row(
            children: [
              Icon(Icons.error_outline, size: 14, color: Colors.red),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _errorText!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )
        else if (widget.helperText != null)
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 14,
                  color: widget.isDark ? Colors.grey[500] : Colors.grey[500]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.helperText!,
                  style: TextStyle(
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    if (widget.controller.text.isEmpty) return null;

    if (_errorText != null) {
      return Icon(Icons.close_rounded, color: Colors.red, size: 18);
    } else if (_isValid) {
      return Icon(Icons.check_circle_rounded, color: Colors.green, size: 18);
    }
    return null;
  }
}

// End of file
