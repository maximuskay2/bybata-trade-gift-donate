import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bybata/features/auth/providers/auth_provider.dart';
import 'package:bybata/features/donations/providers/campaign_provider.dart';
import 'package:bybata/features/karma/providers/karma_provider.dart';
import 'package:bybata/features/donations/models/donation_models.dart';

/// Manual Test Script for End-to-End Donation Flow
/// 
/// This script provides a step-by-step guide for manually testing
/// the complete donation flow between two users.
/// 
/// Test Users:
/// - Creator: local-test-1@example.com / password123
/// - Donor: test@example.com / password123

class DonationFlowTestScript {
  static void printTestInstructions() {
    print('');
    print('🚀 BYBATA DONATION FLOW - MANUAL TEST SCRIPT');
    print('=' * 60);
    print('');
    print('This test will verify the complete donation flow between two users:');
    print('👤 Creator: local-test-1@example.com');
    print('💝 Donor: test@example.com');
    print('');
    print('📋 TEST PHASES:');
    print('1. Creator Login & Campaign Creation');
    print('2. Donor Login & Donation Process');
    print('3. Verification & Impact Assessment');
    print('');
    print('⚠️  REQUIREMENTS:');
    print('• Both test users must exist in the database');
    print('• Backend API must be running');
    print('• App must be running on device/simulator');
    print('');
    print('▶️  Ready to start? Follow the steps below...');
    print('');
  }

  /// Phase 1: Creator creates a campaign
  static void phase1Instructions() {
    print('📱 PHASE 1: CREATOR - CAMPAIGN CREATION');
    print('-' * 40);
    print('');
    print('🔐 Step 1: Login as Creator');
    print('   • Email: local-test-1@example.com');
    print('   • Password: password123');
    print('');
    print('➕ Step 2: Create New Campaign');
    print('   • Tap the + button (Create Campaign)');
    print('   • Fill in the following details:');
    print('     - Title: "Emergency Medical Fund - E2E Test"');
    print('     - Category: Healthcare');
    print('     - Goal: ₦5,000');
    print('     - Description: "Test campaign for donation flow"');
    print('     - Mark as Urgent: ✅');
    print('     - Location: Your current location');
    print('');
    print('✅ Step 3: Verify Campaign Created');
    print('   • Check success message appears');
    print('   • Note the campaign ID');
    print('   • Campaign appears in "My Campaigns"');
    print('');
    print('🚪 Step 4: Logout');
    print('   • Go to Profile > Logout');
    print('');
    print('✋ PAUSE: Complete Phase 1 before proceeding to Phase 2');
    print('');
  }

  /// Phase 2: Donor makes a donation
  static void phase2Instructions() {
    print('💝 PHASE 2: DONOR - DONATION PROCESS');
    print('-' * 40);
    print('');
    print('🔐 Step 1: Login as Donor');
    print('   • Email: test@example.com');
    print('   • Password: password123');
    print('');
    print('🔍 Step 2: Find the Test Campaign');
    print('   • Go to Donations tab');
    print('   • Look for "Emergency Medical Fund - E2E Test"');
    print('   • Verify it appears in:');
    print('     - Available Donations');
    print('     - Featured section (if marked urgent)');
    print('     - Healthcare category');
    print('');
    print('💰 Step 3: Make a Donation');
    print('   • Tap on the campaign');
    print('   • Tap "Donate" button');
    print('   • Select amount: ₦100');
    print('   • Add message: "This is a test donation - E2E flow"');
    print('   • Choose currency: NGN');
    print('   • Confirm donation');
    print('');
    print('✅ Step 4: Verify Donation Success');
    print('   • Check for success message');
    print('   • Note KARMA points awarded');
    print('   • Check donation appears in history');
    print('');
    print('📊 Step 5: Check Stats Update');
    print('   • Go to Donation History tab');
    print('   • Verify donation appears with correct amount');
    print('   • Check header stats updated');
    print('');
    print('✋ PAUSE: Complete Phase 2 before proceeding to Phase 3');
    print('');
  }

  /// Phase 3: Verification and impact assessment
  static void phase3Instructions() {
    print('🔍 PHASE 3: VERIFICATION & IMPACT ASSESSMENT');
    print('-' * 50);
    print('');
    print('👤 Step 1: Switch Back to Creator');
    print('   • Logout donor');
    print('   • Login as creator (local-test-1@example.com)');
    print('');
    print('📈 Step 2: Verify Campaign Progress');
    print('   • Go to My Campaigns');
    print('   • Find "Emergency Medical Fund - E2E Test"');
    print('   • Check updated progress:');
    print('     - Raised Amount: ₦100');
    print('     - Progress: 2% (100/5000)');
    print('     - Supporters: 1');
    print('');
    print('👥 Step 3: Check Donation Details');
    print('   • Tap on the campaign');
    print('   • Go to "Supporters" tab');
    print('   • Verify donor appears:');
    print('     - Donor name: Test User');
    print('     - Amount: ₦100');
    print('     - Message: "This is a test donation - E2E flow"');
    print('');
    print('💎 Step 4: Verify KARMA System');
    print('   • Login back as donor');
    print('   • Check KARMA points in profile');
    print('   • Typical award: 10 points per ₦100 donated');
    print('');
    print('🔄 Step 5: Test Additional Scenarios');
    print('   • Make another donation with different amount');
    print('   • Test anonymous donation option');
    print('   • Test different currencies if available');
    print('');
  }

  /// Final verification checklist
  static void verificationChecklist() {
    print('✅ VERIFICATION CHECKLIST');
    print('-' * 30);
    print('');
    print('Campaign Creation:');
    print('□ Campaign created successfully');
    print('□ Campaign visible to other users');
    print('□ Urgent badge appears if marked urgent');
    print('□ Category filtering works correctly');
    print('');
    print('Donation Process:');
    print('□ Donation amount selection works');
    print('□ Optional message can be added');
    print('□ Currency selection functions');
    print('□ Donation confirmation processes');
    print('□ Success message appears');
    print('');
    print('Data Updates:');
    print('□ Campaign progress updates immediately');
    print('□ Supporter count increments');
    print('□ Donation appears in history');
    print('□ KARMA points awarded correctly');
    print('');
    print('Creator Visibility:');
    print('□ Creator sees updated campaign stats');
    print('□ Donation details visible to creator');
    print('□ Supporter information displayed');
    print('□ Messages from donors visible');
    print('');
    print('System Integration:');
    print('□ Real-time updates work');
    print('□ Pull-to-refresh updates data');
    print('□ Navigation between screens works');
    print('□ Logout/login maintains data');
    print('');
  }

  /// Test result reporting template
  static void reportTemplate() {
    print('📄 TEST REPORT TEMPLATE');
    print('-' * 25);
    print('');
    print('Test Date: ${DateTime.now().toLocal()}');
    print('Test Duration: __ minutes');
    print('');
    print('✅ PASSED TESTS:');
    print('• Campaign Creation: ✅/❌');
    print('• Donation Process: ✅/❌');
    print('• Progress Updates: ✅/❌');
    print('• KARMA System: ✅/❌');
    print('• Data Persistence: ✅/❌');
    print('');
    print('❌ FAILED TESTS:');
    print('• List any failures here...');
    print('');
    print('🐛 BUGS FOUND:');
    print('• Describe any bugs discovered...');
    print('');
    print('💡 IMPROVEMENTS SUGGESTED:');
    print('• List any suggested improvements...');
    print('');
    print('📊 PERFORMANCE NOTES:');
    print('• API response times: __ms average');
    print('• UI responsiveness: Excellent/Good/Poor');
    print('• Data loading speed: Fast/Medium/Slow');
    print('');
  }

  /// Complete test flow runner
  static Future<void> runCompleteTest() async {
    printTestInstructions();
    
    print('Press Enter to start Phase 1...');
    // stdin.readLineSync(); // Uncomment if running in terminal
    
    phase1Instructions();
    
    print('Press Enter to proceed to Phase 2...');
    // stdin.readLineSync();
    
    phase2Instructions();
    
    print('Press Enter to proceed to Phase 3...');
    // stdin.readLineSync();
    
    phase3Instructions();
    
    verificationChecklist();
    
    reportTemplate();
    
    print('🎉 TEST COMPLETED! Please fill out the report template above.');
    print('');
  }
}

/// Sample test data for creating campaigns
class TestCampaignData {
  static final List<Map<String, dynamic>> sampleCampaigns = [
    {
      'title': 'Emergency Medical Fund - E2E Test',
      'description': 'Test campaign for end-to-end donation testing',
      'category': CampaignCategory.healthcare,
      'goalAmount': 5000.0,
      'isUrgent': true,
      'location': 'Lagos, Nigeria',
      'tags': ['emergency', 'medical', 'test'],
    },
    {
      'title': 'Education Support - Test Campaign',
      'description': 'Testing education category donations',
      'category': CampaignCategory.education,
      'goalAmount': 3000.0,
      'isUrgent': false,
      'location': 'Abuja, Nigeria',
      'tags': ['education', 'books', 'test'],
    },
    {
      'title': 'Community Kitchen - Test Project',
      'description': 'Testing community category campaigns',
      'category': CampaignCategory.community,
      'goalAmount': 2000.0,
      'isUrgent': false,
      'location': 'Port Harcourt, Nigeria',
      'tags': ['community', 'food', 'test'],
    },
  ];

  static Map<String, dynamic> getRandomCampaign() {
    sampleCampaigns.shuffle();
    return sampleCampaigns.first;
  }
}

/// Test donation amounts and messages
class TestDonationData {
  static final List<Map<String, dynamic>> sampleDonations = [
    {
      'amount': 100.0,
      'currency': 'NGN',
      'message': 'This is a test donation for E2E testing. Hope this helps!',
      'isAnonymous': false,
    },
    {
      'amount': 250.0,
      'currency': 'NGN',
      'message': 'Testing larger donation amount. Great cause!',
      'isAnonymous': false,
    },
    {
      'amount': 50.0,
      'currency': 'NGN',
      'message': 'Small but meaningful contribution for testing.',
      'isAnonymous': true,
    },
    {
      'amount': 500.0,
      'currency': 'NGN',
      'message': '',
      'isAnonymous': false,
    },
  ];

  static Map<String, dynamic> getRandomDonation() {
    sampleDonations.shuffle();
    return sampleDonations.first;
  }
}

// Main function to run the test
void main() {
  print('🧪 BYBATA DONATION FLOW - MANUAL TEST RUNNER');
  print('');
  
  DonationFlowTestScript.runCompleteTest();
}