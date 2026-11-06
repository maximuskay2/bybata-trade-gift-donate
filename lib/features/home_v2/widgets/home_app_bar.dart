import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/widgets/location_chip.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Minimal 56dp sticky app bar for V2 home surfaces.
///
/// Used by:
///   * BrowseHomeScreenV2 (standalone, unauthenticated)
///   * DiscoverScreen
///
/// NOT used inside HomeScreenV2 when it's nested in MainNavigation, because
/// MainNavigation already renders its own top chrome.
class HomeAppBar extends StatelessWidget {
  final bool isAuthed;
  final VoidCallback? onMenuTap;

  const HomeAppBar({
    super.key,
    required this.isAuthed,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      toolbarHeight: 56,
      backgroundColor:
          Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
      leading: IconButton(
        icon: const Icon(Icons.grid_view_rounded),
        onPressed: () {
          HapticFeedback.selectionClick();
          onMenuTap?.call();
        },
      ),
      titleSpacing: 0,
      title: const LocationChip(isGlassTheme: false),
      centerTitle: true,
      actions: [
        if (isAuthed)
          Consumer<NotificationProvider>(
            builder: (context, np, _) => _BellButton(
              unread: np.unreadCount,
              onTap: () => AppRoutes.navigateToNotifications(context),
            ),
          )
        else
          const SizedBox.shrink(),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: isAuthed
              ? _AvatarButton()
              : _SignInPill(
                  onTap: () => GuardedNavigator.pushNamed(context,
                    AppConstants.loginRoute,
                  ),
                ),
        ),
      ],
    );
  }
}

class _BellButton extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;

  const _BellButton({required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: onTap,
        ),
        if (unread > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AvatarButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final name = (user?.displayName.trim().isNotEmpty ?? false)
        ? user!.displayName
        : (user?.email ?? 'U');
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return GestureDetector(
      onTap: () => GuardedNavigator.pushNamed(context, AppConstants.profileRoute),
      child: CircleAvatar(
        radius: 18,
        backgroundColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _SignInPill extends StatelessWidget {
  final VoidCallback onTap;

  const _SignInPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: primary,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Sign In',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
