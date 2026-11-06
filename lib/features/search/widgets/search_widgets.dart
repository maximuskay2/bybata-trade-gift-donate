import 'package:flutter/material.dart';
import '../../common/widgets/verified_badge.dart';
import '../models/search_models.dart';
import 'package:bybata/core/theme/app_theme.dart';

/// Reusable search result card widget
class SearchResultCard extends StatelessWidget {
  final SearchResult result;
  final VoidCallback? onTap;

  const SearchResultCard({
    Key? key,
    required this.result,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
              Row(
                children: [
                  _buildCategoryIcon(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (result is TradeSearchResult || result is GiftSearchResult)
                    _buildPriceTag(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                result.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (result.location != null) ...[
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      result.location!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimestamp(result.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  _buildResultSpecificInfo(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryIcon() {
    IconData iconData;
    Color iconColor;

    switch (result.category) {
      case SearchCategory.trades:
        iconData = Icons.swap_horiz;
        iconColor = AppColors.primary;
        break;
      case SearchCategory.gifts:
        iconData = Icons.card_giftcard;
        iconColor = Colors.green;
        break;
      case SearchCategory.campaigns:
        iconData = Icons.campaign;
        iconColor = Colors.orange;
        break;
      case SearchCategory.communities:
        iconData = Icons.groups;
        iconColor = Colors.purple;
        break;
      case SearchCategory.users:
        iconData = Icons.person;
        iconColor = Colors.teal;
        break;
      default:
        iconData = Icons.search;
        iconColor = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        size: 20,
        color: iconColor,
      ),
    );
  }

  Widget _buildPriceTag() {
    String? priceText;
    Color backgroundColor = Colors.grey.shade100;
    Color textColor = Colors.grey.shade800;

    if (result is TradeSearchResult) {
      final trade = result as TradeSearchResult;
      if (trade.estimatedValue != null) {
        priceText = '\$${trade.estimatedValue!.toStringAsFixed(0)}';
        backgroundColor = AppColors.primary.withValues(alpha: 0.12);
        textColor = AppColors.primary;
      }
    } else if (result is GiftSearchResult) {
      priceText = 'FREE';
      backgroundColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
    }

    if (priceText == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        priceText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildResultSpecificInfo() {
    if (result is TradeSearchResult) {
      final trade = result as TradeSearchResult;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trade.condition != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                trade.condition!,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ],
      );
    } else if (result is CampaignSearchResult) {
      final campaign = result as CampaignSearchResult;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${campaign.progress.toInt()}% funded',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: campaign.progress >= 100 ? Colors.green : Colors.orange,
            ),
          ),
        ],
      );
    } else if (result is CommunitySearchResult) {
      final community = result as CommunitySearchResult;
      return Text(
        '${community.memberCount} members',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      );
    } else if (result is UserSearchResult) {
      final user = result as UserSearchResult;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          VerifiedBadge(isVerified: user.isVerified, size: 16, showTooltip: true),
          const SizedBox(width: 4),
          Text(
            '${user.karmaPoints} karma',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

/// Filter sheet widget for advanced search filters
class SearchFiltersSheet extends StatefulWidget {
  final SearchFilters initialFilters;
  final Function(SearchFilters) onFiltersChanged;

  const SearchFiltersSheet({
    Key? key,
    required this.initialFilters,
    required this.onFiltersChanged,
  }) : super(key: key);

  @override
  State<SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends State<SearchFiltersSheet> {
  late SearchFilters _filters;
  late RangeValues _priceRange;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
    _priceRange = RangeValues(0, 1000);
    _locationController.text = _filters.location ?? '';
  }

  @override
  void dispose() {
    _locationController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Search Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _resetFilters,
                      child: const Text('Reset'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        widget.onFiltersChanged(_filters);
                        Navigator.pop(context);
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildCategoryFilter(),
                    const SizedBox(height: 24),
                    _buildPriceRangeFilter(),
                    const SizedBox(height: 24),
                    _buildLocationFilter(),
                    const SizedBox(height: 24),
                    _buildDateRangeFilter(),
                    const SizedBox(height: 24),
                    _buildTagsFilter(),
                    const SizedBox(height: 24),
                    _buildSortFilter(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SearchCategory.values.map((category) {
            final isSelected = _filters.category == category;
            return FilterChip(
              label: Text(_getCategoryDisplayName(category)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _filters = _filters.copyWith(
                    category: selected ? category : SearchCategory.all,
                  );
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPriceRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Price Range',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 12),
        RangeSlider(
          values: _priceRange,
          min: 0,
          max: 5000,
          divisions: 100,
          labels: RangeLabels(
            '\$${_priceRange.start.toInt()}',
            '\$${_priceRange.end.toInt()}',
          ),
          onChanged: (values) {
            setState(() {
              _priceRange = values;
              _filters = _filters.copyWith(
                maxDistance: values.end,
              );
            });
          },
        ),
        Text(
          '\$${_priceRange.start.toInt()} - \$${_priceRange.end.toInt()}',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildLocationFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _locationController,
          decoration: const InputDecoration(
            hintText: 'Enter city or postal code',
            prefixIcon: Icon(Icons.location_on),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            _filters = _filters.copyWith(location: value.isEmpty ? null : value);
          },
        ),
      ],
    );
  }

  Widget _buildDateRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date Range',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(
                      _filters.dateRange?.start != null
                          ? _formatDate(_filters.dateRange!.start)
                          : 'Start Date',
                ),
                onPressed: () => _selectStartDate(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(
                      _filters.dateRange?.end != null
                          ? _formatDate(_filters.dateRange!.end)
                          : 'End Date',
                ),
                onPressed: () => _selectEndDate(),
              ),
            ),
          ],
        ),
        if (_filters.dateRange != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: () {
                setState(() {
                  _filters = _filters.copyWith(dateRange: null);
                });
              },
              child: const Text('Clear Date Range'),
            ),
          ),
      ],
    );
  }

  Widget _buildTagsFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tags',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                decoration: const InputDecoration(
                  hintText: 'Add tag',
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _addTag,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _addTag(_tagController.text),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        if (_filters.tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _filters.tags.map((tag) {
              return Chip(
                label: Text('#$tag'),
                onDeleted: () => _removeTag(tag),
                deleteIcon: const Icon(Icons.close, size: 16),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSortFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sort By',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SearchSort.values.map((sortType) {
            final isSelected = _filters.sortBy == sortType;
            return FilterChip(
              label: Text(_getSortDisplayName(sortType)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _filters = _filters.copyWith(
                    sortBy: selected ? sortType : SearchSort.relevance,
                  );
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  void _resetFilters() {
    setState(() {
      _filters = const SearchFilters();
      _priceRange = const RangeValues(0, 1000);
      _locationController.clear();
      _tagController.clear();
    });
  }

  void _addTag(String tag) {
    if (tag.trim().isNotEmpty && !_filters.tags.contains(tag.trim())) {
      setState(() {
        _filters = _filters.copyWith(
          tags: [..._filters.tags, tag.trim()],
        );
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      final newTags = List<String>.from(_filters.tags)..remove(tag);
      _filters = _filters.copyWith(tags: newTags);
    });
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _filters.dateRange?.start ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      setState(() {
        _filters = _filters.copyWith(
          dateRange: DateTimeRange(
            start: date,
            end: _filters.dateRange?.end ?? date,
          ),
        );
      });
    }
  }

  Future<void> _selectEndDate() async {
    final startDate = _filters.dateRange?.start ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _filters.dateRange?.end ?? DateTime.now(),
      firstDate: startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      setState(() {
        _filters = _filters.copyWith(
          dateRange: DateTimeRange(
            start: startDate,
            end: date,
          ),
        );
      });
    }
  }

  String _getCategoryDisplayName(SearchCategory category) {
    switch (category) {
      case SearchCategory.all:
        return 'All';
      case SearchCategory.trades:
        return 'Trades';
      case SearchCategory.gifts:
        return 'Gifts';
      case SearchCategory.campaigns:
        return 'Campaigns';
      case SearchCategory.communities:
        return 'Communities';
      case SearchCategory.users:
        return 'Users';
    }
  }

  String _getSortDisplayName(SearchSort sortType) {
    switch (sortType) {
      case SearchSort.relevance:
        return 'Relevance';
      case SearchSort.newest:
        return 'Newest';
      case SearchSort.oldest:
        return 'Oldest';
      case SearchSort.popular:
        return 'Popular';
      case SearchSort.nearby:
        return 'Nearby';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}