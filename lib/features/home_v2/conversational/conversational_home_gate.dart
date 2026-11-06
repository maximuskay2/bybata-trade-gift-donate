import 'package:flutter/material.dart';

import '../../../core/config/feature_flags.dart';
import '../screens/legacy_home_body.dart';
import 'conversational_home_body.dart';

/// Selects conversational bento home vs legacy feed based on feature flag.
class ConversationalHomeGate extends StatefulWidget {
  final bool isAuthed;
  final double bottomReserve;

  const ConversationalHomeGate({
    super.key,
    required this.isAuthed,
    this.bottomReserve = 16,
  });

  @override
  State<ConversationalHomeGate> createState() => _ConversationalHomeGateState();
}

class _ConversationalHomeGateState extends State<ConversationalHomeGate> {
  late Future<bool> _enabledFuture;

  @override
  void initState() {
    super.initState();
    _enabledFuture = FeatureFlags.enableConversationalFeed;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _enabledFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!) {
          return ConversationalHomeBody(
            isAuthed: widget.isAuthed,
            bottomReserve: widget.bottomReserve,
          );
        }
        return LegacyHomeBody(isAuthed: widget.isAuthed);
      },
    );
  }
}
