import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Visual selector for types/categories with grid or compact chip layouts.
class SmartTypeSelector<T> extends StatelessWidget {
  final T? selectedValue;
  final List<TypeOption<T>> options;
  final Function(T) onSelected;
  final bool isDark;
  final Color primaryColor;
  final String? title;
  final String? subtitle;
  final bool allowMultiple;
  /// `grid` (default) or `chips` for denser category lists.
  final SmartTypeSelectorLayout layout;

  const SmartTypeSelector({
    super.key,
    required this.selectedValue,
    required this.options,
    required this.onSelected,
    required this.isDark,
    required this.primaryColor,
    this.title,
    this.subtitle,
    this.allowMultiple = false,
    this.layout = SmartTypeSelectorLayout.grid,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (layout == SmartTypeSelectorLayout.chips)
          _buildChips()
        else
          _buildGrid(),
      ],
    );
  }

  Widget _buildChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = option.value == selectedValue;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(option.value);
            },
            borderRadius: BorderRadius.circular(22),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withValues(alpha: isDark ? 0.22 : 0.14)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.white),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected
                      ? primaryColor
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08)),
                  width: isSelected ? 1.6 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    option.icon,
                    size: 16,
                    color: isSelected
                        ? primaryColor
                        : (isDark ? Colors.grey[400] : Colors.grey[700]),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? primaryColor
                          : (isDark ? Colors.grey[200] : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGrid() {
    final bgColor = isDark ? const Color(0xFF1E1E24) : Colors.white;
    final useDescription = options.any((o) => (o.description ?? '').isNotEmpty);

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: useDescription ? 1.05 : 1.15,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        final isSelected = option.value == selectedValue;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(option.value);
            },
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.14)
                    : bgColor.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? primaryColor
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey[300] ?? Colors.grey),
                  width: isSelected ? 2 : 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.16),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? primaryColor.withValues(alpha: 0.2)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey[200]),
                    ),
                    child: Icon(
                      option.icon,
                      color: isSelected
                          ? primaryColor
                          : (isDark ? Colors.grey[500] : Colors.grey[600]),
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    option.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? primaryColor
                          : (isDark ? Colors.grey[200] : Colors.black87),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((option.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      option.description!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.25,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum SmartTypeSelectorLayout { grid, chips }

class TypeOption<T> {
  final T value;
  final String label;
  final IconData icon;
  final String? description;

  TypeOption({
    required this.value,
    required this.label,
    required this.icon,
    this.description,
  });
}
