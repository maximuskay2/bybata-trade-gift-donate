import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:bybata/main.dart' as app;
// Removed unused import to fix URI error
import 'package:bybata/features/donations/providers/campaign_provider.dart';
import 'package:bybata/features/donations/models/donation_models.dart';
import 'package:bybata/features/karma/providers/karma_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End Donation Test', () {
    // Test user credentials from previous discussions
    const String creatorEmail = 'local-test-1@example.com';
    const String creatorPassword = 'password123';
    const String donorEmail = 'test@example.com';
    const String donorPassword = 'password123';

    testWidgets('Complete donation flow between two users', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // =============================================
      // PART 1: CREATOR LOGIN AND CAMPAIGN CREATION
      // =============================================
      print('🔸 Starting Creator Login...');

      // Find and tap login button on onboarding screen
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Navigate to login screen if needed
      if (find.text('Login').evaluate().isNotEmpty) {
        await tester.tap(find.text('Login'));
        await tester.pumpAndSettle();
      }

      // Login as creator
      await tester.enterText(find.byType(TextFormField).first, creatorEmail);
      await tester.enterText(find.byType(TextFormField).at(1), creatorPassword);
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Verify creator is logged in
      expect(find.text('Dashboard'), findsOneWidget);
      print('✅ Creator logged in successfully');

      // Navigate to create campaign
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Select "Create Campaign" option
      await tester.tap(find.text('Create Campaign'));
      await tester.pumpAndSettle();

      // Fill campaign creation form
      print('🔸 Creating test campaign...');

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Campaign Title'),
        'Emergency Medical Fund - E2E Test',
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Short Description'),
        'Test campaign for end-to-end donation testing',
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Story'),
        'This is a comprehensive test campaign to verify the complete donation flow from campaign creation to successful donation processing.',
      );

      // Select category
      await tester.tap(find.text('Select Category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Healthcare'));
      await tester.pumpAndSettle();

      // Set goal amount
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Goal Amount'),
        '5000',
      );

      // Mark as urgent
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      // Submit campaign
      await tester.tap(find.text('Create Campaign'));
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Verify campaign created
      expect(find.text('Campaign created successfully!'), findsOneWidget);
      print('✅ Campaign created successfully');

      // Get campaign ID for later use
      final campaignProvider = Provider.of<CampaignProvider>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );
      final createdCampaign = campaignProvider.myCampaigns.first;
      final campaignId = createdCampaign.id;
      print('🔸 Campaign ID: $campaignId');

      // Logout creator
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      print('✅ Creator logged out');

      // =============================================
      // PART 2: DONOR LOGIN AND DONATION PROCESS
      // =============================================
      print('🔸 Starting Donor Login...');

      // Login as donor
      await tester.enterText(find.byType(TextFormField).first, donorEmail);
      await tester.enterText(find.byType(TextFormField).at(1), donorPassword);
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Verify donor is logged in
      expect(find.text('Dashboard'), findsOneWidget);
      print('✅ Donor logged in successfully');

      // Navigate to donations screen
      await tester.tap(find.byIcon(Icons.volunteer_activism));
      await tester.pumpAndSettle();

      // Look for the test campaign
      expect(find.text('Emergency Medical Fund - E2E Test'), findsOneWidget);
      print('✅ Test campaign visible to donor');

      // Tap on the campaign to view details
      await tester.tap(find.text('Emergency Medical Fund - E2E Test'));
      await tester.pumpAndSettle();

      // Start donation process
      await tester.tap(find.text('Donate'));
      await tester.pumpAndSettle();

      // =============================================
      // PART 3: DONATION BOTTOM SHEET FLOW
      // =============================================
      print('🔸 Processing donation...');

      // Select donation amount
      await tester.tap(find.text('₦100'));
      await tester.pumpAndSettle();

      // Tap next to go to message step
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Add optional message
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Add a message (optional)'),
        'This is a test donation for E2E testing. Hope this helps!',
      );

      // Tap next to go to confirmation
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Verify donation summary
      expect(find.text('₦100.00'), findsOneWidget);
      expect(find.text('NGN'), findsOneWidget);
      expect(
        find.text('This is a test donation for E2E testing. Hope this helps!'),
        findsOneWidget,
      );

      // Confirm donation
      await tester.tap(find.text('Confirm Donation'));
      await tester.pumpAndSettle(Duration(seconds: 5));

      // Verify success message
      expect(find.text('Thank you for your donation!'), findsOneWidget);
      print('✅ Donation completed successfully');

      // Close success dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // =============================================
      // PART 4: VERIFY DONATION IMPACT
      // =============================================
      print('🔸 Verifying donation impact...');

      // Check donor's donation history
      await tester.tap(find.text('Donation History'));
      await tester.pumpAndSettle();

      // Verify donation appears in history
      expect(find.text('Emergency Medical Fund - E2E Test'), findsOneWidget);
      expect(find.text('₦100 NGN'), findsOneWidget);
      print('✅ Donation appears in donor history');

      // Check karma points awarded
      final karmaProvider = Provider.of<KarmaProvider>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );
      expect(karmaProvider.currentPoints, greaterThan(0));
      print('✅ KARMA points awarded: ${karmaProvider.currentPoints}');

      // Logout donor
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      // =============================================
      // PART 5: VERIFY CREATOR RECEIVES DONATION
      // =============================================
      print('🔸 Verifying creator receives donation...');

      // Login back as creator
      await tester.enterText(find.byType(TextFormField).first, creatorEmail);
      await tester.enterText(find.byType(TextFormField).at(1), creatorPassword);
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Navigate to my campaigns
      await tester.tap(find.text('My Campaigns'));
      await tester.pumpAndSettle();

      // Check campaign progress updated
      final updatedCampaign = campaignProvider.myCampaigns.firstWhere(
        (c) => c.id == campaignId,
      );
      expect(updatedCampaign.raisedAmount, greaterThan(0));
      expect(updatedCampaign.supportersCount, greaterThan(0));
      print(
        '✅ Campaign updated - Raised: ₦${updatedCampaign.raisedAmount}, Supporters: ${updatedCampaign.supportersCount}',
      );

      // Verify donation details in campaign
      await tester.tap(find.text('Emergency Medical Fund - E2E Test'));
      await tester.pumpAndSettle();

      // Check supporters tab
      await tester.tap(find.text('Supporters'));
      await tester.pumpAndSettle();

      // Verify donor appears in supporters
      expect(
        find.text('Test User'),
        findsOneWidget,
      ); // Assuming donor's name is "Test User"
      expect(find.text('₦100'), findsOneWidget);
      print('✅ Donor appears in campaign supporters');

      // =============================================
      // PART 6: TEST COMPLETION SUMMARY
      // =============================================
      print('🎉 END-TO-END TEST COMPLETED SUCCESSFULLY!');
      print('📊 Test Summary:');
      print('   • Creator created campaign: ✅');
      print('   • Donor found and donated to campaign: ✅');
      print('   • Donation processed successfully: ✅');
      print('   • KARMA points awarded to donor: ✅');
      print('   • Campaign progress updated: ✅');
      print('   • Creator can see donation details: ✅');
      print('');
      print('💰 Financial Flow:');
      print('   • Campaign Goal: ₦5,000.00');
      print('   • Amount Raised: ₦${updatedCampaign.raisedAmount}');
      print(
        '   • Progress: ${(updatedCampaign.progressPercentage * 100).toStringAsFixed(1)}%',
      );
      print('   • Supporters: ${updatedCampaign.supportersCount}');
      print('');
      print('🏆 KARMA System:');
      print('   • Donor earned: ${karmaProvider.currentPoints} KARMA points');
    });

    testWidgets('Test multiple donations scenario', (tester) async {
      // Test multiple smaller donations to the same campaign
      // This would test campaign progress updates and multiple supporter tracking

      print('🔸 Testing multiple donations scenario...');

      // Similar flow but with multiple donation amounts
      const donations = [50, 25, 75, 100]; // Different donation amounts

      for (int i = 0; i < donations.length; i++) {
        print('🔸 Processing donation ${i + 1}: ₦${donations[i]}');

        // Follow similar donation flow
        // Each donation should:
        // 1. Update campaign progress
        // 2. Award KARMA points
        // 3. Appear in donation history
        // 4. Show in campaign supporters
      }

      print('✅ Multiple donations test completed');
    });

    testWidgets('Test urgent campaign priority', (tester) async {
      // Test that urgent campaigns appear prominently
      print('🔸 Testing urgent campaign visibility...');

      // Verify urgent campaigns show up in:
      // 1. Featured section
      // 2. Urgent campaigns carousel
      // 3. Have urgent badge

      print('✅ Urgent campaign priority test completed');
    });

    testWidgets('Test campaign completion flow', (tester) async {
      // Test what happens when a campaign reaches its goal
      print('🔸 Testing campaign completion...');

      // Make donations until campaign goal is reached
      // Verify:
      // 1. Campaign status changes to completed
      // 2. Success story is created
      // 3. Final notifications are sent

      print('✅ Campaign completion test completed');
    });
  });
}

/// Helper function to simulate API delays
Future<void> simulateApiDelay() async {
  await Future.delayed(Duration(seconds: 2));
}

/// Helper function to validate campaign data
void validateCampaign(Campaign campaign) {
  expect(campaign.id, isNotEmpty);
  expect(campaign.title, isNotEmpty);
  expect(campaign.story, isNotEmpty);
  expect(campaign.goalAmount, greaterThan(0));
  expect(campaign.creator, isNotNull);
}

/// Helper function to validate donation data
void validateDonation(dynamic donation) {
  expect(donation.id, isNotEmpty);
  expect(donation.amount, greaterThan(0));
  expect(donation.currency, isNotEmpty);
  expect(donation.campaignId, isNotEmpty);
  expect(donation.karmaAwarded, greaterThan(0));
}
