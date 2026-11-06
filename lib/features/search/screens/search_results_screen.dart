import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/search_models.dart';
import '../providers/search_provider.dart';
import '../widgets/search_widgets.dart';
import '../../../screens/coming_soon_screen.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/theme/app_theme.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Screen displaying search results with premium frosted glass bento layouts
class SearchResultsScreen extends StatefulWidget {
  final String query;
  
  const SearchResultsScreen({
    super.key,
    required this.query,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Perform search when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SearchProvider>().search(widget.query);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      // Load more results when near the bottom
      context.read<SearchProvider>().loadMoreResults();
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SearchFiltersSheet(
        initialFilters: context.read<SearchProvider>().filters,
        onFiltersChanged: (filters) {
          context.read<SearchProvider>().updateFilters(filters);
          context.read<SearchProvider>().search(widget.query);
        },
      ),
    );
  }

  void _showSortDialog() {
    final provider = context.read<SearchProvider>();
    final currentSort = provider.filters.sortBy;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1A28) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Sort Framework', 
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.4)
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SearchSort.values.map((sortType) {
            return RadioListTile<SearchSort>(
              title: Text(_getSortDisplayName(sortType), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              value: sortType,
              activeColor: const Color(0xFF7B2CBF),
              groupValue: currentSort,
              onChanged: (value) {
                if (value != null) {
                  final newFilters = provider.filters.copyWith(sortBy: value);
                  provider.updateFilters(newFilters);
                  provider.search(widget.query);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0B12) : Colors.white,
      appBar: AppBar(
        title: const Text(
          'Search Results',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            onPressed: _showSortDialog,
          ),
        ],
      ),
      body: Consumer<SearchProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.currentSearchResponse == null) {
            return const Center(child: BybataLoadingIndicator(color: Color(0xFF7B2CBF)));
          }

          if (provider.error != null) {
            return _buildErrorView(provider.error!);
          }

          final response = provider.currentSearchResponse;
          if (response == null || response.results.isEmpty) {
            return _buildEmptyView();
          }

          return Column(
            children: [
              _buildResultsHeader(response),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: response.results.length + (provider.hasMoreResults ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == response.results.length) {
                      return _buildLoadingIndicator();
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SearchResultCard(
                        result: response.results[index],
                        onTap: () => _navigateToDetail(response.results[index]),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResultsHeader(SearchResponse response) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15101F).withValues(alpha: 0.5) : AppColors.primaryTintSoft,
        border: Border(
          bottom: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Results for "${response.query}"',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B2CBF).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${response.totalCount} found',
                  style: const TextStyle(
                    color: Color(0xFF7B2CBF),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (response.categoryCounts.isNotEmpty)
                Expanded(
                  child: _buildCategoryFilters(response.categoryCounts),
                ),
            ],
          ),
          if (_hasActiveFilters()) ...[
            const SizedBox(height: 12),
            _buildActiveFilters(),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryFilters(Map<SearchCategory, int> categoryCounts) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: categoryCounts.entries.map((entry) {
          final category = entry.key;
          final count = entry.value;
          final isSelected = context.read<SearchProvider>().filters.category == category;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text('${_getCategoryDisplayName(category)} ($count)'),
              selected: isSelected,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              selectedColor: const Color(0xFF7B2CBF),
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
              showCheckmark: false,
              onSelected: (selected) {
                final provider = context.read<SearchProvider>();
                final newCategory = selected ? category : SearchCategory.all;
                final newFilters = provider.filters.copyWith(category: newCategory);
                provider.updateFilters(newFilters);
                provider.search(widget.query);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveFilters() {
    final filters = context.read<SearchProvider>().filters;
    final activeFilters = <Widget>[];

    if (filters.maxDistance != null) {
      activeFilters.add(
        Chip(
          label: Text('Max Distance: ${filters.maxDistance!.toInt()}km'),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          onDeleted: () => _removeFilter('distance'),
          deleteIcon: const Icon(Icons.close_rounded, size: 16),
        ),
      );
    }

    if (filters.location != null) {
      activeFilters.add(
        Chip(
          label: Text('Near: ${filters.location}'),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          onDeleted: () => _removeFilter('location'),
          deleteIcon: const Icon(Icons.close_rounded, size: 16),
        ),
      );
    }

    if (filters.dateRange != null) {
      activeFilters.add(
        Chip(
          label: Text('Date: ${_formatDateRange(filters.dateRange!)}'),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          onDeleted: () => _removeFilter('date'),
          deleteIcon: const Icon(Icons.close_rounded, size: 16),
        ),
      );
    }

    if (filters.tags.isNotEmpty) {
      for (final tag in filters.tags) {
        activeFilters.add(
          Chip(
            label: Text('#$tag'),
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            onDeleted: () => _removeTag(tag),
            deleteIcon: const Icon(Icons.close_rounded, size: 16),
          ),
        );
      }
    }

    if (activeFilters.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Active constraints:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.grey)),
            const Spacer(),
            TextButton(
              onPressed: _clearAllFilters,
              child: const Text('Clear All', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: activeFilters,
        ),
      ],
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search terms or filter constraints.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                context.read<SearchProvider>().resetFilters();
                context.read<SearchProvider>().search(widget.query);
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))
              ),
              child: const Text('Clear Active Filters', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Search Failed',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                context.read<SearchProvider>().search(widget.query);
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7B2CBF)),
              child: const Text('Retry Search', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: BybataLoadingIndicator(color: Color(0xFF7B2CBF))),
    );
  }

  bool _hasActiveFilters() {
    final filters = context.read<SearchProvider>().filters;
    return filters.maxDistance != null ||
           filters.location != null ||
           filters.dateRange != null ||
           filters.tags.isNotEmpty;
  }

  void _removeFilter(String filterType) {
    final provider = context.read<SearchProvider>();
    SearchFilters newFilters;

    switch (filterType) {
      case 'distance':
        newFilters = provider.filters.copyWith(maxDistance: null);
        break;
      case 'location':
        newFilters = provider.filters.copyWith(location: null);
        break;
      case 'date':
        newFilters = provider.filters.copyWith(dateRange: null);
        break;
      default:
        return;
    }

    provider.updateFilters(newFilters);
    provider.search(widget.query);
  }

  void _removeTag(String tag) {
    final provider = context.read<SearchProvider>();
    final newTags = List<String>.from(provider.filters.tags)..remove(tag);
    final newFilters = provider.filters.copyWith(tags: newTags);
    
    provider.updateFilters(newFilters);
    provider.search(widget.query);
  }

  void _clearAllFilters() {
    final provider = context.read<SearchProvider>();
    provider.resetFilters();
    provider.search(widget.query);
  }

  void _navigateToDetail(SearchResult result) {
    switch (result.category) {
      case SearchCategory.trades:
        if (result is TradeSearchResult) {
          GuardedNavigator.pushNamed(context, '/trade_detail', arguments: result.id);
        }
        break;
      case SearchCategory.gifts:
        if (result is GiftSearchResult) {
          GuardedNavigator.pushNamed(context, '/gift_detail', arguments: result.id);
        }
        break;
      case SearchCategory.campaigns:
        if (result is CampaignSearchResult) {
          GuardedNavigator.pushNamed(context, '/campaign_detail', arguments: result.id);
        }
        break;
      case SearchCategory.communities:
        if (result is CommunitySearchResult) {
          GuardedNavigator.push(context,
            MaterialPageRoute(
              builder: (_) => const ComingSoonScreen(title: 'Community'),
            ),
          );
        }
        break;
      case SearchCategory.users:
        if (result is UserSearchResult) {
          GuardedNavigator.pushNamed(context, '/user_profile', arguments: result.id);
        }
        break;
      default:
        AppToast.show(context, 'Unable to open this item');
        break;
    }
  }

  String _getCategoryDisplayName(SearchCategory category) {
    switch (category) {
      case SearchCategory.all: return 'All';
      case SearchCategory.trades: return 'Trades';
      case SearchCategory.gifts: return 'Gifts';
      case SearchCategory.campaigns: return 'Campaigns';
      case SearchCategory.communities: return 'Communities';
      case SearchCategory.users: return 'Users';
    }
  }

  String _getSortDisplayName(SearchSort sortType) {
    switch (sortType) {
      case SearchSort.relevance: return 'Most Relevant';
      case SearchSort.newest: return 'Newest First';
      case SearchSort.oldest: return 'Oldest First';
      case SearchSort.popular: return 'Most Popular';
      case SearchSort.nearby: return 'Nearest First';
    }
  }

  String _formatDateRange(DateTimeRange dateRange) {
    final startDate = '${dateRange.start.day}/${dateRange.start.month}';
    final endDate = '${dateRange.end.day}/${dateRange.end.month}';
    return '$startDate - $endDate';
  }
}