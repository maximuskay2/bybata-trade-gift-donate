/// Community navigation routes helper
library;

import 'package:flutter/material.dart';
import '../screens/community_discover_screen.dart';
import '../screens/create_community_screen.dart';
import '../screens/community_hub_screen.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Community-specific navigation helper.
class CommunityRoutes {
  CommunityRoutes._();

  /// Navigate to community discover feed.
  static void navigateToDiscover(BuildContext context) {
    GuardedNavigator.push(context, 
      MaterialPageRoute(builder: (_) => const CommunityDiscoverScreen()),
    );
  }

  /// Navigate to create community screen.
  static Future<dynamic> navigateToCreateCommunity(BuildContext context) async {
    return GuardedNavigator.push(context, 
      MaterialPageRoute(builder: (_) => const CreateCommunityScreen()),
    );
  }

  /// Navigate to a community hub.
  static Future<void> navigateToCommunityHub(
    BuildContext context, {
    required String communityId,
    required String communityName,
    double? lat,
    double? lng,
    bool isMember = false,
  }) async {
    await GuardedNavigator.push(context, 
      MaterialPageRoute(
        builder: (_) => CommunityHubScreen(
          communityId: communityId,
          communityName: communityName,
          communityLat: lat,
          communityLng: lng,
          isMember: isMember,
        ),
      ),
    );
  }
}
