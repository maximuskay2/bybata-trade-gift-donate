import 'package:flutter/material.dart';
import 'shadow_card.dart';
import '../theme/borderless_input_decoration.dart';
import '../theme/shadow_styles.dart';

class SearchBarWidget extends StatefulWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFilterTap;
  final VoidCallback? onSortTap;
  final bool showFilterButton;
  final bool showSortButton;
  final TextEditingController? controller;
  final List<Widget>? suffixActions;

  const SearchBarWidget({
    super.key,
    this.hintText = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.onFilterTap,
    this.onSortTap,
    this.showFilterButton = true,
    this.showSortButton = true,
    this.controller,
    this.suffixActions,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget>
    with TickerProviderStateMixin {
  late TextEditingController _controller;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;
  bool _isSearching = false;
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
    
    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _shimmerAnimation = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));
    
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
      
      if (_isFocused) {
        _pulseController.repeat(reverse: true);
        _shimmerController.repeat();
      } else {
        _pulseController.stop();
        _shimmerController.stop();
      }
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    _pulseController.dispose();
    _shimmerController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final isSearching = _controller.text.isNotEmpty;
    if (isSearching != _isSearching) {
      setState(() {
        _isSearching = isSearching;
      });
    }
    widget.onChanged?.call(_controller.text);
  }

  void _clearSearch() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _shimmerAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _isFocused ? _pulseAnimation.value : 1.0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: _isFocused || _isSearching
                  ? LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        Theme.of(context).primaryColor.withValues(alpha: 0.05),
                        Colors.white,
                        Theme.of(context).primaryColor.withValues(alpha: 0.05),
                        Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      ],
                      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                      begin: Alignment(-1.0 + _shimmerAnimation.value, 0.0),
                      end: Alignment(1.0 + _shimmerAnimation.value, 0.0),
                    )
                  : null,
              boxShadow: _isFocused || _isSearching
                  ? [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        blurRadius: 25,
                        spreadRadius: 5,
                        offset: const Offset(0, 0),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: ShadowCard(
              shadowIntensity: ShadowIntensity.light,
              borderRadius: 16,
              color: Colors.white,
              child: Row(
                children: [
                  // Search Input
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onSubmitted: widget.onSubmitted,
                      decoration: BorderlessInputDecoration.search(
                        hintText: widget.hintText,
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                        prefixIcon: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            Icons.search,
                            color: _isFocused || _isSearching
                                ? Theme.of(context).primaryColor
                                : Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white70
                                  : Colors.black87,
                            size: _isFocused || _isSearching ? 24 : 22,
                          ),
                        ),
                        suffixIcon: _isSearching
                            ? AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                child: IconButton(
                                  onPressed: _clearSearch,
                                  icon: Icon(
                                    Icons.clear,
                                    color: Theme.of(context).primaryColor,
                                    size: 20,
                                  ),
                                ),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: _isSearching 
                          ? Theme.of(context).primaryColor 
                          : Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                        fontWeight: FontWeight.w600, // Always bold for better visibility
                      ),
                    ),
                  ),
                  
                  // Divider
                  if (widget.showFilterButton || widget.showSortButton || (widget.suffixActions?.isNotEmpty ?? false))
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 1,
                      height: 24,
                      color: _isFocused || _isSearching
                          ? Theme.of(context).primaryColor.withValues(alpha: 0.3)
                          : Colors.grey[300],
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  
                  // Action buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Custom suffix actions
                      if (widget.suffixActions != null)
                        ...widget.suffixActions!,
                      
                      // Filter button
                      if (widget.showFilterButton)
                        _buildActionButton(
                          icon: Icons.filter_list,
                          onTap: widget.onFilterTap,
                          tooltip: 'Filter',
                        ),
                      
                      // Sort button
                      if (widget.showSortButton)
                        _buildActionButton(
                          icon: Icons.sort,
                          onTap: widget.onSortTap,
                          tooltip: 'Sort',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: _isFocused || _isSearching
                ? LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      Theme.of(context).primaryColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Icon(
            icon,
            color: _isFocused || _isSearching
                ? Theme.of(context).primaryColor
                : Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.black87,
            size: _isFocused || _isSearching ? 22 : 20, // Bigger for better visibility
          ),
        ),
      ),
    );
  }
}

// Filter Chip Widget for use with search
class FilterChipWidget extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final IconData? icon;

  const FilterChipWidget({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).primaryColor 
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).primaryColor 
                : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Sort Options Widget
class SortOptionsWidget extends StatelessWidget {
  final List<SortOption> options;
  final String selectedOption;
  final ValueChanged<String> onChanged;

  const SortOptionsWidget({
    super.key,
    required this.options,
    required this.selectedOption,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ShadowCard(
      shadowIntensity: ShadowIntensity.light,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sort By',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...options.map((option) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Radio<String>(
              value: option.value,
              groupValue: selectedOption,
              onChanged: (value) => onChanged(value!),
            ),
            title: Text(
              option.label,
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: option.description != null
                ? Text(
                    option.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  )
                : null,
            onTap: () => onChanged(option.value),
          )),
        ],
      ),
    );
  }
}

class SortOption {
  final String value;
  final String label;
  final String? description;

  const SortOption({
    required this.value,
    required this.label,
    this.description,
  });
}