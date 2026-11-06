import 'package:flutter/material.dart';
import 'package:bybata/core/theme/app_theme.dart';

import '../../../core/widgets/bybata_loading_indicator.dart';

/// Category filter chip component
class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? selectedColor;
  final Color? unselectedColor;
  final CategoryChipSize size;
  final int? count;

  const CategoryChip({
    Key? key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.icon,
    this.selectedColor,
    this.unselectedColor,
    this.size = CategoryChipSize.medium,
    this.count,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedBgColor = selectedColor ?? theme.primaryColor;
    final unselectedBgColor = unselectedColor ?? Colors.grey.shade200;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_getBorderRadius()),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: _getHorizontalPadding(),
          vertical: _getVerticalPadding(),
        ),
        decoration: BoxDecoration(
          color: isSelected ? selectedBgColor : unselectedBgColor,
          borderRadius: BorderRadius.circular(_getBorderRadius()),
          border: Border.all(
            color: isSelected ? selectedBgColor : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: _getIconSize(),
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
              SizedBox(width: _getSpacing()),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: _getFontSize(),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
            if (count != null) ...[
              SizedBox(width: _getSpacing()),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
color: isSelected 
                      ? Colors.white.withValues(alpha: 0.2) 
                      : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: _getFontSize() * 0.8,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _getBorderRadius() {
    switch (size) {
      case CategoryChipSize.small:
        return 16;
      case CategoryChipSize.medium:
        return 20;
      case CategoryChipSize.large:
        return 24;
    }
  }

  double _getHorizontalPadding() {
    switch (size) {
      case CategoryChipSize.small:
        return 12;
      case CategoryChipSize.medium:
        return 16;
      case CategoryChipSize.large:
        return 20;
    }
  }

  double _getVerticalPadding() {
    switch (size) {
      case CategoryChipSize.small:
        return 6;
      case CategoryChipSize.medium:
        return 8;
      case CategoryChipSize.large:
        return 10;
    }
  }

  double _getIconSize() {
    switch (size) {
      case CategoryChipSize.small:
        return 14;
      case CategoryChipSize.medium:
        return 16;
      case CategoryChipSize.large:
        return 18;
    }
  }

  double _getFontSize() {
    switch (size) {
      case CategoryChipSize.small:
        return 12;
      case CategoryChipSize.medium:
        return 14;
      case CategoryChipSize.large:
        return 16;
    }
  }

  double _getSpacing() {
    switch (size) {
      case CategoryChipSize.small:
        return 4;
      case CategoryChipSize.medium:
        return 6;
      case CategoryChipSize.large:
        return 8;
    }
  }
}

/// Action button with consistent styling
class ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ActionButtonStyle style;
  final ActionButtonSize size;
  final bool isLoading;
  final bool isEnabled;
  final double? width;
  final Color? color;

  const ActionButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.icon,
    this.style = ActionButtonStyle.primary,
    this.size = ActionButtonSize.medium,
    this.isLoading = false,
    this.isEnabled = true,
    this.width,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isButtonEnabled = isEnabled && !isLoading && onPressed != null;

    switch (style) {
      case ActionButtonStyle.primary:
        return _buildPrimaryButton(context, theme, isButtonEnabled);
      case ActionButtonStyle.secondary:
        return _buildSecondaryButton(context, theme, isButtonEnabled);
      case ActionButtonStyle.outline:
        return _buildOutlineButton(context, theme, isButtonEnabled);
      case ActionButtonStyle.text:
        return _buildTextButton(context, theme, isButtonEnabled);
      case ActionButtonStyle.danger:
        return _buildDangerButton(context, theme, isButtonEnabled);
    }
  }

  Widget _buildPrimaryButton(BuildContext context, ThemeData theme, bool enabled) {
    final buttonColor = color ?? theme.primaryColor;
    
    return SizedBox(
      width: width,
      height: _getButtonHeight(),
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade500,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_getBorderRadius()),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: _getHorizontalPadding(),
            vertical: _getVerticalPadding(),
          ),
        ),
        child: _buildButtonContent(),
      ),
    );
  }

  Widget _buildSecondaryButton(BuildContext context, ThemeData theme, bool enabled) {
    return SizedBox(
      width: width,
      height: _getButtonHeight(),
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade100,
          foregroundColor: Colors.grey.shade800,
          disabledBackgroundColor: Colors.grey.shade200,
          disabledForegroundColor: Colors.grey.shade400,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_getBorderRadius()),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: _getHorizontalPadding(),
            vertical: _getVerticalPadding(),
          ),
        ),
        child: _buildButtonContent(),
      ),
    );
  }

  Widget _buildOutlineButton(BuildContext context, ThemeData theme, bool enabled) {
    final buttonColor = color ?? theme.primaryColor;
    
    return SizedBox(
      width: width,
      height: _getButtonHeight(),
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonColor,
          disabledForegroundColor: Colors.grey.shade400,
          side: BorderSide(
            color: enabled ? buttonColor : Colors.grey.shade300,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_getBorderRadius()),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: _getHorizontalPadding(),
            vertical: _getVerticalPadding(),
          ),
        ),
        child: _buildButtonContent(),
      ),
    );
  }

  Widget _buildTextButton(BuildContext context, ThemeData theme, bool enabled) {
    final buttonColor = color ?? theme.primaryColor;
    
    return SizedBox(
      width: width,
      height: _getButtonHeight(),
      child: TextButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          foregroundColor: buttonColor,
          disabledForegroundColor: Colors.grey.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_getBorderRadius()),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: _getHorizontalPadding(),
            vertical: _getVerticalPadding(),
          ),
        ),
        child: _buildButtonContent(),
      ),
    );
  }

  Widget _buildDangerButton(BuildContext context, ThemeData theme, bool enabled) {
    return SizedBox(
      width: width,
      height: _getButtonHeight(),
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade500,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_getBorderRadius()),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: _getHorizontalPadding(),
            vertical: _getVerticalPadding(),
          ),
        ),
        child: _buildButtonContent(),
      ),
    );
  }

  Widget _buildButtonContent() {
    if (isLoading) {
      return SizedBox(
        width: _getIconSize(),
        height: _getIconSize(),
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _getIconSize()),
          SizedBox(width: _getSpacing()),
          Text(
            text,
            style: TextStyle(
              fontSize: _getFontSize(),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: _getFontSize(),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  double _getButtonHeight() {
    switch (size) {
      case ActionButtonSize.small:
        return 36;
      case ActionButtonSize.medium:
        return 44;
      case ActionButtonSize.large:
        return 52;
    }
  }

  double _getBorderRadius() {
    switch (size) {
      case ActionButtonSize.small:
        return 8;
      case ActionButtonSize.medium:
        return 10;
      case ActionButtonSize.large:
        return 12;
    }
  }

  double _getHorizontalPadding() {
    switch (size) {
      case ActionButtonSize.small:
        return 16;
      case ActionButtonSize.medium:
        return 20;
      case ActionButtonSize.large:
        return 24;
    }
  }

  double _getVerticalPadding() {
    switch (size) {
      case ActionButtonSize.small:
        return 8;
      case ActionButtonSize.medium:
        return 10;
      case ActionButtonSize.large:
        return 12;
    }
  }

  double _getIconSize() {
    switch (size) {
      case ActionButtonSize.small:
        return 16;
      case ActionButtonSize.medium:
        return 18;
      case ActionButtonSize.large:
        return 20;
    }
  }

  double _getFontSize() {
    switch (size) {
      case ActionButtonSize.small:
        return 14;
      case ActionButtonSize.medium:
        return 16;
      case ActionButtonSize.large:
        return 18;
    }
  }

  double _getSpacing() {
    switch (size) {
      case ActionButtonSize.small:
        return 6;
      case ActionButtonSize.medium:
        return 8;
      case ActionButtonSize.large:
        return 10;
    }
  }
}

/// Confirmation dialog for actions
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final IconData? icon;
  final Color? iconColor;
  final bool isDangerous;

  const ConfirmationDialog({
    Key? key,
    required this.title,
    required this.message,
    this.confirmText,
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.icon,
    this.iconColor,
    this.isDangerous = false,
  }) : super(key: key);

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    IconData? icon,
    Color? iconColor,
    bool isDangerous = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
        onCancel: onCancel,
        icon: icon,
        iconColor: iconColor,
        isDangerous: isDangerous,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: (iconColor ?? (isDangerous ? Colors.red : AppColors.primary))
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: iconColor ?? (isDangerous ? Colors.red : AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ActionButton(
                  text: cancelText ?? 'Cancel',
                  style: ActionButtonStyle.secondary,
                  onPressed: () {
                    Navigator.of(context).pop(false);
                    onCancel?.call();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ActionButton(
                  text: confirmText ?? 'Confirm',
                  style: isDangerous 
                      ? ActionButtonStyle.danger 
                      : ActionButtonStyle.primary,
                  onPressed: () {
                    Navigator.of(context).pop(true);
                    onConfirm?.call();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Loading dialog
class LoadingDialog extends StatelessWidget {
  final String? message;

  const LoadingDialog({
    Key? key,
    this.message,
  }) : super(key: key);

  static void show({
    required BuildContext context,
    String? message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LoadingDialog(message: message),
    );
  }

  static void hide(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.all(32),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BybataLoadingIndicator(size: BybataLoadingSize.compact),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Success dialog
class SuccessDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onConfirm;
  final String? confirmText;

  const SuccessDialog({
    Key? key,
    required this.title,
    required this.message,
    this.onConfirm,
    this.confirmText,
  }) : super(key: key);

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    VoidCallback? onConfirm,
    String? confirmText,
  }) {
    return showDialog(
      context: context,
      builder: (context) => SuccessDialog(
        title: title,
        message: message,
        onConfirm: onConfirm,
        confirmText: confirmText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 32,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ActionButton(
              text: confirmText ?? 'OK',
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm?.call();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact action button for lists
class ActionButtonCompact extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool isOutlined;

  const ActionButtonCompact({
    Key? key,
    required this.text,
    this.onPressed,
    this.icon,
    this.color,
    this.isOutlined = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ActionButton(
      text: text,
      onPressed: onPressed,
      icon: icon,
      color: color,
      style: isOutlined ? ActionButtonStyle.outline : ActionButtonStyle.primary,
      size: ActionButtonSize.small,
    );
  }
}

/// Category chip group for multiple selection
class CategoryChipGroup extends StatelessWidget {
  final List<CategoryChipData> categories;
  final Set<String> selectedCategories;
  final Function(String)? onCategoryToggle;
  final bool multiSelect;
  final Axis direction;

  const CategoryChipGroup({
    Key? key,
    required this.categories,
    required this.selectedCategories,
    this.onCategoryToggle,
    this.multiSelect = true,
    this.direction = Axis.horizontal,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (direction == Axis.horizontal) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories.map((category) {
          return CategoryChip(
            label: category.label,
            icon: category.icon,
            count: category.count,
            isSelected: selectedCategories.contains(category.id),
            onTap: () => onCategoryToggle?.call(category.id),
          );
        }).toList(),
      );
    }

    return Column(
      children: categories.map((category) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            width: double.infinity,
            child: CategoryChip(
              label: category.label,
              icon: category.icon,
              count: category.count,
              isSelected: selectedCategories.contains(category.id),
              onTap: () => onCategoryToggle?.call(category.id),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Category chip size enumeration
enum CategoryChipSize {
  small,
  medium,
  large,
}

/// Action button style enumeration
enum ActionButtonStyle {
  primary,
  secondary,
  outline,
  text,
  danger,
}

/// Action button size enumeration
enum ActionButtonSize {
  small,
  medium,
  large,
}

/// Data class for category chip
class CategoryChipData {
  final String id;
  final String label;
  final IconData? icon;
  final int? count;

  CategoryChipData({
    required this.id,
    required this.label,
    this.icon,
    this.count,
  });
}