import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/karma_service.dart';
import 'models/karma_models.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';

/// Test widget to demonstrate karma API integration
class TestKarmaIntegration extends StatefulWidget {
  const TestKarmaIntegration({super.key});

  @override
  State<TestKarmaIntegration> createState() => _TestKarmaIntegrationState();
}

class _TestKarmaIntegrationState extends State<TestKarmaIntegration> {
  @override
  void initState() {
    super.initState();
    // Test initializing karma service with API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _testKarmaIntegration();
    });
  }

  Future<void> _testKarmaIntegration() async {
    final karmaService = Provider.of<KarmaService>(context, listen: false);
    
    try {
      print('Testing Karma API integration...');
      print('Using backend API: ${karmaService.isUsingBackendApi}');
      
      // Test initialization with a mock user ID
      await karmaService.initialize('test_user_123');
      
      print('Karma service initialized successfully!');
      print('Current karma points: ${karmaService.userKarmaPoints}');
      print('Current level: ${karmaService.currentUserKarma?.level.name ?? 'Unknown'}');
      print('Trust level: ${karmaService.currentUserKarma?.trustLevel.name ?? 'Unknown'}');
      
      // Test refreshing leaderboard
      await karmaService.refreshLeaderboard();
      print('Leaderboard entries: ${karmaService.leaderboard.length}');
      
    } catch (e) {
      print('Karma API integration test failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karma API Integration Test'),
      ),
      body: ListenableBuilder(
        listenable: KarmaService(),
        builder: (context, child) {
          final karmaService = KarmaService();
          if (karmaService.isLoading) {
            return const BybataLoader();
          }

          if (karmaService.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${karmaService.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _testKarmaIntegration(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final userKarma = karmaService.currentUserKarma;
          if (userKarma == null) {
            return const Center(
              child: Text('No karma data available'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'API Mode: ',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Chip(
                              label: Text(
                                karmaService.isUsingBackendApi ? 'Backend API Connected' : 'API Disconnected',
                              ),
                              backgroundColor: karmaService.isUsingBackendApi 
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total Points: ${userKarma.totalPoints}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Level: ${userKarma.level.emoji} ${userKarma.level.name}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Trust Level: ${userKarma.trustLevel.emoji} ${userKarma.trustLevel.name}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Current Streak: ${userKarma.currentStreak.currentStreak} days',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Rank: #${userKarma.stats.globalRank}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Recent Activity (${userKarma.recentActivity.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: userKarma.recentActivity.length,
                    itemBuilder: (context, index) {
                      final transaction = userKarma.recentActivity[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            transaction.activity.icon,
                            color: transaction.activity.color,
                          ),
                          title: Text(transaction.activity.name),
                          subtitle: Text(transaction.description),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '+${transaction.pointsEarned}',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _formatDate(transaction.timestamp),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _testKarmaIntegration(),
                        child: const Text('Refresh Data'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => karmaService.refreshAllKarmaData(),
                        child: const Text('Refresh All Data'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}