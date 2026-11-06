import 'package:flutter/material.dart';

import '../conversational/conversational_home_body.dart';

/// Authenticated home root — Gemini-style conversational entry inside
/// [MainNavigation]. Top chrome is owned by MainNavigation.
class HomeScreenV2 extends StatelessWidget {
  const HomeScreenV2({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Allow seamless layout translation when the keyboard slides up
      resizeToAvoidBottomInset: true, 
      backgroundColor: isDark ? const Color(0xFF0D0B12) : Colors.white,
      body: const ConversationalHomeBody(
        isAuthed: true,
        bottomReserve: 16,
      ),
    );
  }
}