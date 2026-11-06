import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/karma_service.dart';
import '../models/karma_models.dart';
import '../navigation/karma_navigator.dart';
import 'package:bybata/core/theme/app_theme.dart';
import 'package:bybata/core/widgets/app_toast.dart';

/// Screen explaining how to earn KARMA points with interactive examples
class EarnKarmaScreen extends StatefulWidget {
  const EarnKarmaScreen({super.key});

  @override
  State<EarnKarmaScreen> createState() => _EarnKarmaScreenState();
}

class _EarnKarmaScreenState extends State<EarnKarmaScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _selectedCategoryIndex = 0;
  bool _isLoading = false;
  String? _errorMessage;

  final List<KarmaActivityCategory> _categories = [
    KarmaActivityCategory(
      name: 'Quick Wins',
      emoji: '⚡',
      description: 'Easy ways to earn KARMA quickly',
      activities: [
        KarmaActivity.shareContent,
        KarmaActivity.createPost,
        KarmaActivity.joinEvent,
        KarmaActivity.reportIssue,
      ],
    ),
    KarmaActivityCategory(
      name: 'Trading & Commerce',
      emoji: '💼',
      description: 'Earn through trading and business activities',
      activities: [
        KarmaActivity.completeTrade,
        KarmaActivity.giveGift,
        KarmaActivity.makeDonation,
        KarmaActivity.receiveReview,
      ],
    ),
    KarmaActivityCategory(
      name: 'Community Help',
      emoji: '🤝',
      description: 'Help others and build community',
      activities: [
        KarmaActivity.helpCommunity,
        KarmaActivity.mentorUser,
        KarmaActivity.referFriend,
      ],
    ),
    KarmaActivityCategory(
      name: 'Verification',
      emoji: '🛡️',
      description: 'Secure your account and build trust',
      activities: [
        KarmaActivity.getVerified,
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Earn KARMA'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showKarmaGuideInfo,
            icon: const Icon(Icons.help_outline),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.local_fire_department),
              text: 'Activities',
            ),
            Tab(
              icon: Icon(Icons.lightbulb_outline),
              text: 'Tips & Tricks',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActivitiesTab(),
          _buildTipsAndTricksTab(),
        ],
      ),
    );
  }

  Widget _buildActivitiesTab() {
    return Column(
      children: [
        // Category selector
        Container(
          height: 120,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isSelected = index == _selectedCategoryIndex;
              
              return GestureDetector(
                onTap: () => setState(() => _selectedCategoryIndex = index),
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green.shade600 : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? Colors.green.shade600 : Colors.grey.shade300,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        category.emoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category.description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? Colors.white70 : Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ).animate().scale(
                duration: Duration(milliseconds: 400 + (index * 100)),
                delay: Duration(milliseconds: index * 50),
                curve: Curves.elasticOut,
              );
            },
          ),
        ),
        
        // Activities list
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _categories[_selectedCategoryIndex].name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _categories[_selectedCategoryIndex].description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Activity cards
                ..._categories[_selectedCategoryIndex].activities.asMap().entries.map(
                  (entry) => _buildActivityCard(entry.value, entry.key),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityCard(KarmaActivity activity, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activity.color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Activity icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: activity.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  activity.icon,
                  color: activity.color,
                  size: 30,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Activity info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          activity.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '+${activity.points} KARMA',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      activity.description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showActivityDetails(activity),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Learn More'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: activity.color,
                    side: BorderSide(color: activity.color.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _simulateActivity(activity),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Try Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activity.color,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().slideX(
      begin: 0.3,
      duration: Duration(milliseconds: 400 + (index * 100)),
      delay: Duration(milliseconds: index * 50),
      curve: Curves.easeOut,
    ).fadeIn(
      duration: Duration(milliseconds: 400 + (index * 100)),
      delay: Duration(milliseconds: index * 50),
    );
  }

  Widget _buildTipsAndTricksTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Daily KARMA challenge
          _buildDailyChallenge(),
          
          const SizedBox(height: 20),
          
          // Tips section
          _buildTipsSection(),
          
          const SizedBox(height: 20),
          
          // Strategies section
          _buildStrategiesSection(),
          
          const SizedBox(height: 20),
          
          // Common mistakes section
          _buildCommonMistakesSection(),
        ],
      ),
    );
  }

  Widget _buildDailyChallenge() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily KARMA Challenge',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Complete daily activities to earn bonus points',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'Today\'s Goal: Earn 50 KARMA Points',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: 0.6, // Mock progress
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '30/50 points earned • 20 points to go',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _viewDailyChallenges,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green.shade700,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('View All Challenges'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection() {
    final tips = [
      KarmaTip(
        title: 'Start Small',
        description: 'Begin with simple activities like sharing content or creating posts',
        icon: Icons.rocket_launch,
        color: AppColors.primary,
      ),
      KarmaTip(
        title: 'Be Consistent',
        description: 'Daily activities build up over time and create earning streaks',
        icon: Icons.schedule,
        color: Colors.orange,
      ),
      KarmaTip(
        title: 'Help Others',
        description: 'Community activities often have the highest KARMA rewards',
        icon: Icons.favorite,
        color: Colors.red,
      ),
      KarmaTip(
        title: 'Verify Early',
        description: 'Account verification gives a significant one-time KARMA boost',
        icon: Icons.verified,
        color: Colors.green,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pro Tips for Earning KARMA',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...tips.asMap().entries.map((entry) => _buildTipCard(entry.value, entry.key)),
      ],
    );
  }

  Widget _buildTipCard(KarmaTip tip, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tip.color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tip.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              tip.icon,
              color: tip.color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip.description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().slideX(
      begin: 0.2,
      duration: Duration(milliseconds: 400 + (index * 50)),
      delay: Duration(milliseconds: index * 50),
      curve: Curves.easeOut,
    );
  }

  Widget _buildStrategiesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earning Strategies',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildStrategyItem(
            '🏃‍♂️ Quick Start Strategy',
            'Focus on verification and easy activities first',
            ['Complete email verification (+100 KARMA)', 'Share 3 posts (+15 KARMA)', 'Join an event (+15 KARMA)'],
          ),
          
          _buildStrategyItem(
            '🤝 Community Builder Strategy',
            'Help others and build relationships',
            ['Help 5 community members (+100 KARMA)', 'Mentor a new user (+50 KARMA)', 'Refer friends (+1 KARMA each)'],
          ),
          
          _buildStrategyItem(
            '💼 Trader Strategy',
            'Earn through business activities',
            ['Complete trades (+1 KARMA each)', 'Give gifts (+1 KARMA each)', 'Receive positive reviews (+25 KARMA each)'],
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyItem(String title, String description, List<String> steps) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...steps.map((step) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildCommonMistakesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_outlined, color: Colors.red.shade600),
              const SizedBox(width: 8),
              Text(
                'Common Mistakes to Avoid',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildMistakeItem('Forgetting daily activities', 'Set reminders to maintain your earning streak'),
          _buildMistakeItem('Ignoring verification', 'Complete verifications early for maximum bonus'),
          _buildMistakeItem('Not helping others', 'Community activities have high KARMA rewards'),
          _buildMistakeItem('Focusing only on points', 'Build genuine relationships and value'),
        ],
      ),
    );
  }

  Widget _buildMistakeItem(String mistake, String solution) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.close, color: Colors.red.shade600, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mistake,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              solution,
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showActivityDetails(KarmaActivity activity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: activity.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  activity.icon,
                  color: activity.color,
                  size: 40,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                activity.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+${activity.points} KARMA Points',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                activity.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _simulateActivity(activity);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activity.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Get Started'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _simulateActivity(KarmaActivity activity) async {
    // Show loading state
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Map activity to action type
      final actionType = _getActionTypeFromActivity(activity);
      
      // Get the API service from KarmaService
      final karmaService = context.read<KarmaService>();
      if (karmaService.apiService == null) {
        throw Exception('API service not initialized');
      }

      // Call the API to earn karma from action
      final response = await karmaService.apiService!.earnFromAction(
        actionType,
        metadata: {
          'source': 'earn_guide',
          'activityType': activity.name,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Refresh karma service with new points (bypass TTL cache)
      final userId = karmaService.currentUserKarma?.userId ?? '';
      if (userId.isNotEmpty) {
        await karmaService.refresh(userId);
      }

      if (mounted) {
        // Show success snackbar
        AppToast.success(
          context,
          'Total: ${response.totalPoints} points',
          title: 'Earned +${response.pointsEarned} KARMA!',
        );

        // Show level up notification if applicable
        if (response.leveledUp) {
          _showLevelUpDialog(response.newLevel);
        }

        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      print('Error earning karma: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to earn KARMA: ${e.toString()}';
        });

        AppToast.error(context, _errorMessage ?? 'Failed to earn KARMA');
      }
    }
  }

  String _getActionTypeFromActivity(KarmaActivity activity) {
    switch (activity) {
      case KarmaActivity.completeTrade:
        return 'COMPLETE_TRADE';
      case KarmaActivity.giveGift:
        return 'GIVE_GIFT';
      case KarmaActivity.makeDonation:
        return 'MAKE_DONATION';
      case KarmaActivity.helpCommunity:
        return 'HELP_COMMUNITY';
      case KarmaActivity.createPost:
        return 'CREATE_POST';
      case KarmaActivity.getVerified:
        return 'GET_VERIFIED';
      case KarmaActivity.receiveReview:
        return 'RECEIVE_REVIEW';
      case KarmaActivity.mentorUser:
        return 'MENTOR_USER';
      case KarmaActivity.joinEvent:
        return 'JOIN_EVENT';
      case KarmaActivity.shareContent:
        return 'SHARE_CONTENT';
      case KarmaActivity.reportIssue:
        return 'REPORT_ISSUE';
      case KarmaActivity.referFriend:
        return 'REFER_FRIEND';
    }
  }

  void _showLevelUpDialog(int newLevel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Level Up!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You\'ve reached Level $newLevel!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Great job! Keep earning to reach higher levels.'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _viewDailyChallenges() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily Challenges'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Complete these activities today for bonus KARMA:'),
            SizedBox(height: 16),
            Text('✅ Share 3 posts (15 KARMA)'),
            Text('🔄 Help 1 community member (20 KARMA)'),
            Text('📝 Create 1 helpful post (10 KARMA)'),
            Text('🎁 Send a gift (30 KARMA)'),
            SizedBox(height: 16),
            Text('Bonus: Complete all for +25 extra KARMA!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to activities or main KARMA screen
            },
            child: const Text('Start Now'),
          ),
        ],
      ),
    );
  }

  void _showKarmaGuideInfo() {
    KarmaNavigator.showKarmaInfoDialog(context);
  }
}

class KarmaActivityCategory {
  final String name;
  final String emoji;
  final String description;
  final List<KarmaActivity> activities;

  KarmaActivityCategory({
    required this.name,
    required this.emoji,
    required this.description,
    required this.activities,
  });
}

class KarmaTip {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  KarmaTip({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}