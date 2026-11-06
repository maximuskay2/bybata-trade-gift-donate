import 'package:flutter/material.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/borderless_input_decoration.dart';
import '../../../core/theme/shadow_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../models/achievement.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Achievement> _achievements = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadAchievements();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadAchievements() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 800));

    // Mock achievement data
    final mockAchievements = [
      // Trade Achievements
      Achievement(
        id: '1',
        name: 'First Trade',
        description: 'Complete your first trade',
        icon: 'trade',
        type: AchievementType.trade,
        rarity: AchievementRarity.common,
        karmaReward: 10,
        unlockedAt: DateTime.now().subtract(const Duration(days: 30)),
        category: 'Trading',
      ),
      Achievement(
        id: '2',
        name: 'Active Trader',
        description: 'Complete 20 successful trades',
        icon: 'active_trade',
        type: AchievementType.trade,
        rarity: AchievementRarity.uncommon,
        karmaReward: 50,
        unlockedAt: DateTime.now().subtract(const Duration(days: 7)),
        category: 'Trading',
      ),
      Achievement(
        id: '3',
        name: 'Trade Master',
        description: 'Complete 100 successful trades',
        icon: 'trade_master',
        type: AchievementType.trade,
        rarity: AchievementRarity.rare,
        karmaReward: 200,
        category: 'Trading',
      ),
      
      // Gift Achievements
      Achievement(
        id: '4',
        name: 'First Gift',
        description: 'Send your first gift',
        icon: 'gift',
        type: AchievementType.gift,
        rarity: AchievementRarity.common,
        karmaReward: 5,
        unlockedAt: DateTime.now().subtract(const Duration(days: 25)),
        category: 'Gifting',
      ),
      Achievement(
        id: '5',
        name: 'Generous Giver',
        description: 'Send 10 gifts to community members',
        icon: 'generous',
        type: AchievementType.gift,
        rarity: AchievementRarity.uncommon,
        karmaReward: 30,
        unlockedAt: DateTime.now().subtract(const Duration(days: 14)),
        category: 'Gifting',
      ),
      Achievement(
        id: '6',
        name: 'Gift Master',
        description: 'Send 50 gifts to others',
        icon: 'gift_master',
        type: AchievementType.gift,
        rarity: AchievementRarity.rare,
        karmaReward: 150,
        category: 'Gifting',
      ),

      // Community Achievements
      Achievement(
        id: '7',
        name: 'Community Helper',
        description: 'Help 10 people in communities',
        icon: 'helper',
        type: AchievementType.community,
        rarity: AchievementRarity.uncommon,
        karmaReward: 40,
        unlockedAt: DateTime.now().subtract(const Duration(days: 5)),
        category: 'Community',
      ),
      Achievement(
        id: '8',
        name: 'Popular Member',
        description: 'Get 100 likes on your posts',
        icon: 'popular',
        type: AchievementType.social,
        rarity: AchievementRarity.rare,
        karmaReward: 100,
        category: 'Community',
      ),

      // Milestone Achievements
      Achievement(
        id: '9',
        name: 'Welcome Aboard',
        description: 'Complete your profile setup',
        icon: 'welcome',
        type: AchievementType.milestone,
        rarity: AchievementRarity.common,
        karmaReward: 25,
        unlockedAt: DateTime.now().subtract(const Duration(days: 45)),
        category: 'Milestone',
      ),
      Achievement(
        id: '10',
        name: 'Verified Member',
        description: 'Complete identity verification',
        icon: 'verified',
        type: AchievementType.milestone,
        rarity: AchievementRarity.uncommon,
        karmaReward: 100,
        unlockedAt: DateTime.now().subtract(const Duration(days: 30)),
        category: 'Milestone',
      ),

      // Special Achievements
      Achievement(
        id: '11',
        name: 'Early Adopter',
        description: 'One of the first 1000 users',
        icon: 'early_adopter',
        type: AchievementType.special,
        rarity: AchievementRarity.legendary,
        karmaReward: 500,
        unlockedAt: DateTime.now().subtract(const Duration(days: 60)),
        category: 'Special',
      ),
      Achievement(
        id: '12',
        name: 'Beta Tester',
        description: 'Participated in beta testing',
        icon: 'beta',
        type: AchievementType.special,
        rarity: AchievementRarity.epic,
        karmaReward: 300,
        category: 'Special',
      ),

      // KARMA Achievements
      Achievement(
        id: '13',
        name: 'KARMA Collector',
        description: 'Earn 1000 KARMA points',
        icon: 'karma_collector',
        type: AchievementType.karma,
        rarity: AchievementRarity.uncommon,
        karmaReward: 50,
        unlockedAt: DateTime.now().subtract(const Duration(days: 10)),
        category: 'KARMA',
      ),
      Achievement(
        id: '14',
        name: 'KARMA Master',
        description: 'Earn 10,000 KARMA points',
        icon: 'karma_master',
        type: AchievementType.karma,
        rarity: AchievementRarity.epic,
        karmaReward: 500,
        category: 'KARMA',
      ),
    ];

    setState(() {
      _achievements = mockAchievements;
      _isLoading = false;
    });
  }

  List<Achievement> get _filteredAchievements {
    var filtered = _achievements.where((achievement) {
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        if (!achievement.name.toLowerCase().contains(_searchQuery.toLowerCase()) &&
            !achievement.description.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }

      // Apply category filter based on selected tab
      switch (_tabController.index) {
        case 0: // All
          return true;
        case 1: // Unlocked
          return achievement.isUnlocked;
        case 2: // Trade
          return achievement.type == AchievementType.trade;
        case 3: // Community
          return achievement.type == AchievementType.community || 
                 achievement.type == AchievementType.social;
        case 4: // Milestone
          return achievement.type == AchievementType.milestone;
        case 5: // Special
          return achievement.type == AchievementType.special;
        default:
          return true;
      }
    }).toList();

    // Sort by rarity and unlock status
    filtered.sort((a, b) {
      if (a.isUnlocked && !b.isUnlocked) return -1;
      if (!a.isUnlocked && b.isUnlocked) return 1;
      return b.rarity.index.compareTo(a.rarity.index);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Unlocked'),
            Tab(text: 'Trade'),
            Tab(text: 'Community'),
            Tab(text: 'Milestone'),
            Tab(text: 'Special'),
          ],
          onTap: (index) {
            setState(() {
              // Filter will be applied in _filteredAchievements getter
            });
          },
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Column(
        children: [
          // Statistics Header
          _buildStatsHeader(),

          // Search Bar
          _buildSearchBar(),

          // Achievements Grid
          Expanded(
            child: _isLoading
                ? const BybataLoader()
                : _filteredAchievements.isEmpty
                    ? _buildEmptyState()
                    : _buildAchievementsGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    final unlockedCount = _achievements.where((a) => a.isUnlocked).length;
    final totalKarma = _achievements
        .where((a) => a.isUnlocked)
        .fold(0, (sum, a) => sum + a.karmaReward);

    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'Unlocked',
              '$unlockedCount/${_achievements.length}',
              Icons.emoji_events,
              AppTheme.karmaColor,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              'KARMA Earned',
              totalKarma.toString(),
              Icons.star,
              AppTheme.successColor,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              'Completion',
              '${((unlockedCount / _achievements.length) * 100).toInt()}%',
              Icons.trending_up,
              scheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: BorderlessInputDecoration.search(
          hintText: 'Search achievements...',
          prefixIcon: Icon(Icons.search, color: scheme.onSurface.withValues(alpha: 0.6)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: scheme.onSurface.withValues(alpha: 0.6)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildAchievementsGrid() {
    final achievements = _filteredAchievements;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final achievement = achievements[index];
        return _buildAchievementCard(achievement);
      },
    );
  }

  Widget _buildAchievementCard(Achievement achievement) {
    final isUnlocked = achievement.isUnlocked;
    final rarityColor = _getRarityColor(achievement.rarity);

    return GestureDetector(
      onTap: () => _showAchievementDetails(achievement),
      child: ShadowCard(
        shadowIntensity: ShadowIntensity.medium,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: isUnlocked
                ? LinearGradient(
                    colors: [
                      rarityColor.withValues(alpha: 0.1),
                      Theme.of(context).colorScheme.surface,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Achievement Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? rarityColor.withValues(alpha: 0.1)
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isUnlocked
                          ? rarityColor
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _getAchievementIcon(achievement.type),
                    color: isUnlocked
                        ? rarityColor
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),

                // Rarity Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: rarityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    achievement.rarityDisplayName,
                    style: TextStyle(
                      fontSize: 10,
                      color: rarityColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Achievement Name
                Text(
                  achievement.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isUnlocked
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Achievement Description
                Expanded(
                  child: Text(
                    achievement.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: isUnlocked
                          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // KARMA Reward
                if (isUnlocked) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: 12,
                          color: AppTheme.successColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '+${achievement.karmaReward}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Icon(
                    Icons.lock,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No achievements found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search terms'
                : 'Keep using the app to unlock achievements',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  void _showAchievementDetails(Achievement achievement) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Achievement Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: achievement.isUnlocked
                      ? _getRarityColor(achievement.rarity).withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: achievement.isUnlocked
                        ? _getRarityColor(achievement.rarity)
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    width: 3,
                  ),
                ),
                child: Icon(
                  _getAchievementIcon(achievement.type),
                  color: achievement.isUnlocked
                      ? _getRarityColor(achievement.rarity)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),

              // Achievement Name
              Text(
                achievement.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Rarity Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getRarityColor(achievement.rarity).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  achievement.rarityDisplayName,
                  style: TextStyle(
                    fontSize: 12,
                    color: _getRarityColor(achievement.rarity),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                achievement.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // KARMA Reward
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: AppTheme.karmaColor, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${achievement.karmaReward} KARMA',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.karmaColor,
                    ),
                  ),
                ],
              ),

              if (achievement.isUnlocked) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: AppTheme.successColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Unlocked ${_formatDate(achievement.unlockedAt!)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Not yet unlocked',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRarityColor(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
      case AchievementRarity.uncommon:
        return AppTheme.successColor;
      case AchievementRarity.rare:
        return Theme.of(context).colorScheme.primary;
      case AchievementRarity.epic:
        return Theme.of(context).colorScheme.secondary;
      case AchievementRarity.legendary:
        return AppTheme.karmaColor;
    }
  }

  IconData _getAchievementIcon(AchievementType type) {
    switch (type) {
      case AchievementType.trade:
        return Icons.swap_horiz;
      case AchievementType.gift:
        return Icons.card_giftcard;
      case AchievementType.donation:
        return Icons.favorite;
      case AchievementType.community:
        return Icons.groups;
      case AchievementType.karma:
        return Icons.star;
      case AchievementType.social:
        return Icons.people;
      case AchievementType.milestone:
        return Icons.flag;
      case AchievementType.special:
        return Icons.emoji_events;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}