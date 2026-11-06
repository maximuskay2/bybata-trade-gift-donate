import 'package:flutter/material.dart';

/// Rating stars display component
class RatingStars extends StatelessWidget {
  final double rating; // 0.0 to 5.0
  final int maxStars;
  final double size;
  final Color activeColor;
  final Color inactiveColor;
  final bool allowHalfStars;
  final bool showRating;
  final String? label;
  final Function(double)? onRatingChanged;

  const RatingStars({
    Key? key,
    required this.rating,
    this.maxStars = 5,
    this.size = 20,
    this.activeColor = const Color(0xFFFFB300), // Amber
    this.inactiveColor = const Color(0xFFE0E0E0), // Light grey
    this.allowHalfStars = true,
    this.showRating = false,
    this.label,
    this.onRatingChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(maxStars, (index) {
          return GestureDetector(
            onTap: onRatingChanged != null
                ? () => onRatingChanged!(index + 1.0)
                : null,
            child: _buildStar(index),
          );
        }),
        if (showRating) ...[
          const SizedBox(width: 8),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: size * 0.7,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
        if (label != null) ...[
          const SizedBox(width: 8),
          Text(
            label!,
            style: TextStyle(
              fontSize: size * 0.7,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStar(int index) {
    final starValue = index + 1;
    IconData icon;
    Color color;

    if (rating >= starValue) {
      // Full star
      icon = Icons.star;
      color = activeColor;
    } else if (allowHalfStars && rating >= starValue - 0.5) {
      // Half star
      icon = Icons.star_half;
      color = activeColor;
    } else {
      // Empty star
      icon = Icons.star_border;
      color = inactiveColor;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Icon(
        icon,
        size: size,
        color: color,
      ),
    );
  }
}

/// Interactive rating stars for user input
class InteractiveRatingStars extends StatefulWidget {
  final double initialRating;
  final int maxStars;
  final double size;
  final Color activeColor;
  final Color inactiveColor;
  final Function(double)? onRatingChanged;
  final bool allowClear;

  const InteractiveRatingStars({
    Key? key,
    this.initialRating = 0.0,
    this.maxStars = 5,
    this.size = 24,
    this.activeColor = const Color(0xFFFFB300),
    this.inactiveColor = const Color(0xFFE0E0E0),
    this.onRatingChanged,
    this.allowClear = true,
  }) : super(key: key);

  @override
  State<InteractiveRatingStars> createState() => _InteractiveRatingStarsState();
}

class _InteractiveRatingStarsState extends State<InteractiveRatingStars> {
  late double _currentRating;
  double? _hoverRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.maxStars, (index) {
        return MouseRegion(
          onEnter: (_) => setState(() => _hoverRating = index + 1.0),
          onExit: (_) => setState(() => _hoverRating = null),
          child: GestureDetector(
            onTap: () => _handleTap(index + 1.0),
            child: _buildInteractiveStar(index),
          ),
        );
      }),
    );
  }

  Widget _buildInteractiveStar(int index) {
    final starValue = index + 1;
    final displayRating = _hoverRating ?? _currentRating;
    
    IconData icon;
    Color color;

    if (displayRating >= starValue) {
      icon = Icons.star;
      color = widget.activeColor;
    } else {
      icon = Icons.star_border;
      color = widget.inactiveColor;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Icon(
        icon,
        size: widget.size,
        color: color,
      ),
    );
  }

  void _handleTap(double rating) {
    setState(() {
      if (widget.allowClear && _currentRating == rating) {
        _currentRating = 0.0;
      } else {
        _currentRating = rating;
      }
    });
    
    widget.onRatingChanged?.call(_currentRating);
  }
}

/// Compact rating display for lists
class RatingStarsCompact extends StatelessWidget {
  final double rating;
  final bool showCount;
  final int? reviewCount;

  const RatingStarsCompact({
    Key? key,
    required this.rating,
    this.showCount = false,
    this.reviewCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RatingStars(
          rating: rating,
          size: 14,
          showRating: false,
        ),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        if (showCount && reviewCount != null) ...[
          const SizedBox(width: 4),
          Text(
            '($reviewCount)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Large rating display for detail views
class RatingStarsLarge extends StatelessWidget {
  final double rating;
  final int reviewCount;
  final String? subtitle;

  const RatingStarsLarge({
    Key? key,
    required this.rating,
    required this.reviewCount,
    this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            RatingStars(
              rating: rating,
              size: 28,
              showRating: false,
            ),
            const SizedBox(width: 12),
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$reviewCount reviews',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ],
    );
  }
}

/// Rating breakdown component
class RatingBreakdown extends StatelessWidget {
  final Map<int, int> ratingCounts; // star -> count
  final int totalReviews;

  const RatingBreakdown({
    Key? key,
    required this.ratingCounts,
    required this.totalReviews,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(5, (index) {
        final stars = 5 - index;
        final count = ratingCounts[stars] ?? 0;
        final percentage = totalReviews > 0 ? count / totalReviews : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Text(
                '$stars',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.star, size: 12, color: Color(0xFFFFB300)),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFB300)),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text(
                  '$count',
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Rating input with feedback text
class RatingInput extends StatefulWidget {
  final String title;
  final String? subtitle;
  final double initialRating;
  final Function(double, String?)? onRatingSubmitted;
  final List<String>? ratingLabels;

  const RatingInput({
    Key? key,
    required this.title,
    this.subtitle,
    this.initialRating = 0.0,
    this.onRatingSubmitted,
    this.ratingLabels,
  }) : super(key: key);

  @override
  State<RatingInput> createState() => _RatingInputState();
}

class _RatingInputState extends State<RatingInput> {
  late double _rating;
  final TextEditingController _commentController = TextEditingController();
  
  static const List<String> _defaultLabels = [
    'Poor',
    'Fair', 
    'Good',
    'Very Good',
    'Excellent',
  ];

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.ratingLabels ?? _defaultLabels;
    final currentLabel = _rating > 0 ? labels[(_rating - 1).toInt()] : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.subtitle!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
        const SizedBox(height: 16),
        
        // Rating stars
        Row(
          children: [
            InteractiveRatingStars(
              initialRating: _rating,
              size: 32,
              onRatingChanged: (rating) {
                setState(() {
                  _rating = rating;
                });
              },
            ),
            if (currentLabel.isNotEmpty) ...[
              const SizedBox(width: 16),
              Text(
                currentLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ],
        ),
        
        const SizedBox(height: 20),
        
        // Comment field
        TextField(
          controller: _commentController,
          decoration: const InputDecoration(
            labelText: 'Add a comment (optional)',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
        ),
        
        const SizedBox(height: 20),
        
        // Submit button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _rating > 0
                ? () => widget.onRatingSubmitted?.call(
                    _rating,
                    _commentController.text.isEmpty ? null : _commentController.text,
                  )
                : null,
            child: const Text('Submit Rating'),
          ),
        ),
      ],
    );
  }
}