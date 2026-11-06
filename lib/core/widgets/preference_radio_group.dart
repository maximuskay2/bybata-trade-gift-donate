import 'package:flutter/material.dart';

/// [PreferenceRadioGroup] replaces confusing toggles with clear radio buttons
/// and descriptions, giving users context about their choices.
class PreferenceRadioGroup<T> extends StatelessWidget {
  final T selectedValue;
  final List<PreferenceOption<T>> options;
  final Function(T) onChanged;
  final bool isDark;
  final Color primaryColor;
  final String? title;
  final String? helpText;

  const PreferenceRadioGroup({
    super.key,
    required this.selectedValue,
    required this.options,
    required this.onChanged,
    required this.isDark,
    required this.primaryColor,
    this.title,
    this.helpText,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF1E1E24) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(Icons.radio_button_checked_rounded,
                    color: primaryColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  title!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        if (helpText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              helpText!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        // Options
        ...options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final isSelected = option.value == selectedValue;

          return Padding(
            padding: EdgeInsets.only(bottom: index == options.length - 1 ? 0 : 12),
            child: GestureDetector(
              onTap: () => onChanged(option.value),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor.withOpacity(0.1)
                      : bgColor.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? primaryColor
                        : (isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey[300] ?? Colors.grey),
                    width: isSelected ? 2 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Custom radio button
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? primaryColor : Colors.grey[400] ?? Colors.grey,
                            width: isSelected ? 2 : 1.5,
                          ),
                          color: isSelected
                              ? primaryColor.withOpacity(0.2)
                              : Colors.transparent,
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: primaryColor,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (option.icon != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Icon(option.icon,
                                      size: 16,
                                      color: isSelected
                                          ? primaryColor
                                          : (isDark
                                              ? Colors.grey[500]
                                              : Colors.grey[600])),
                                ),
                              Expanded(
                                child: Text(
                                  option.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? primaryColor
                                        : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (option.description != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                option.description!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.w400,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}

/// Configuration for a preference radio option
class PreferenceOption<T> {
  final T value;
  final String label;
  final String? description;
  final IconData? icon;

  PreferenceOption({
    required this.value,
    required this.label,
    this.description,
    this.icon,
  });
}
