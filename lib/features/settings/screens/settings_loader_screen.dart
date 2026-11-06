import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../profile/models/user_profile.dart';
import '../../profile/services/profile_cache.dart';
import '../widgets/settings_ui.dart';
import 'enhanced_settings_screen.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';

/// Loads [UserProfile] for routes that open settings without profile args.
class SettingsLoaderScreen extends StatefulWidget {
  final UserProfile? initialProfile;

  const SettingsLoaderScreen({super.key, this.initialProfile});

  @override
  State<SettingsLoaderScreen> createState() => _SettingsLoaderScreenState();
}

class _SettingsLoaderScreenState extends State<SettingsLoaderScreen> {
  UserProfile? _profile;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialProfile != null) {
      _profile = widget.initialProfile;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final cached = await ProfileCache.loadCurrent();
    if (cached != null && mounted) {
      setState(() {
        _profile = cached;
        _loading = false;
      });
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _error = 'Sign in to open settings';
          _loading = false;
        });
      }
      return;
    }

    // Minimal profile so hub can open; user can refresh from profile later.
    if (mounted) {
      setState(() {
        _profile = UserProfile(
          id: user.id,
          firstName: user.displayName.split(' ').first,
          lastName: user.displayName.split(' ').length > 1
              ? user.displayName.split(' ').skip(1).join(' ')
              : '',
          email: user.email,
          phone: user.phoneNumber,
          avatar: user.photoUrl,
          bio: user.bio,
          location: user.location,
          stats: ProfileStats(),
          trustScore: TrustScore(
            score: 0,
            level: 0,
            badges: [],
            lastUpdated: DateTime.now(),
          ),
          verification: VerificationStatus(),
          settings: ProfileSettings(),
          createdAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: SettingsUi.pageBackground(context),
        body: const BybataLoader(),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: SettingsUi.pageBackground(context),
        appBar: AppBar(title: const Text('Settings')),
        body: Center(child: Text(_error!)),
      );
    }
    return EnhancedSettingsScreen(userProfile: _profile!);
  }
}
