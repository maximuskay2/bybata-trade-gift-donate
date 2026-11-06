import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../providers/feed_provider.dart';
import '../widgets/home_app_bar.dart';
import '../widgets/home_shell.dart';
import '../widgets/near_you_section.dart';

/// Pre-conversational home feed — used when [FeatureFlags.enableConversationalFeed] is off.
class LegacyHomeBody extends StatelessWidget {
  final bool isAuthed;

  const LegacyHomeBody({super.key, required this.isAuthed});

  Future<void> _onRefresh(BuildContext context) async {
    await context.read<FeedProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final authed = isAuthed || context.watch<AuthProvider>().isAuthenticated;
    return HomeShell(
      onRefresh: () => _onRefresh(context),
      slivers: [
        HomeAppBar(isAuthed: authed),
        ...NearYouSection.buildSlivers(context, isAuthed: authed),
      ],
    );
  }
}
