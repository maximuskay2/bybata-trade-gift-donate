import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../providers/feed_provider.dart';
import '../widgets/home_app_bar.dart';
import '../widgets/home_shell.dart';
import '../widgets/near_you_section.dart';

/// Discover tab — a full-viewport unified feed.
///
/// Reachable from both auth states; the only behaviour that branches is
/// whether card taps route into detail screens or trigger the login dialog
/// (handled inside FeedCard's default tap via AppRoutes).
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  Future<void> _onRefresh(BuildContext context) async {
    await context.read<FeedProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isAuthed = context.watch<AuthProvider>().isAuthenticated;
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: HomeShell(
        onRefresh: () => _onRefresh(context),
        slivers: [
          HomeAppBar(isAuthed: isAuthed),
          ...NearYouSection.buildSlivers(context, isAuthed: isAuthed),
        ],
      ),
    );
  }
}
