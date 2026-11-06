import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../theme/shadow_styles.dart';
import '../navigation/app_routes.dart';
import '../providers/auth_provider.dart';
import 'cached_media_image.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Side drawer inspired by modern app design: user profile at top,
/// menu items, and sign out at bottom. Replaces the floating draggable menu.
class AppSideDrawer extends StatelessWidget {
  final VoidCallback? onClose;

  const AppSideDrawer({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();
    final isGlass = themeProvider.isGlassModeEnabled;

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.surface,
                    scheme.surface.withValues(alpha: 0.98),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.surface,
                    scheme.surface.withValues(alpha: 0.95),
                  ],
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              offset: const Offset(4, 0),
              blurRadius: 20,
              spreadRadius: -4,
            ),
          ],
        ),
        child: isGlass
            ? ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: _buildDrawerContent(context, scheme, isDark),
                ),
              )
            : _buildDrawerContent(context, scheme, isDark),
      ),
    );
  }

  Widget _buildDrawerContent(
    BuildContext context,
    ColorScheme scheme,
    bool isDark,
  ) {
    return SafeArea(
      child: Column(
        children: [
          // --- User Profile Header (3D) ---
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              final user = authProvider.currentUser;
              final displayName = user?.displayName?.trim().isNotEmpty == true
                  ? user!.displayName!
                  : (user?.email ?? 'User');
              final email = user?.email ?? '';
              final initials = _getInitials(displayName);

              return InkWell(
                onTap: () {
                  if (AppRoutes.requireSignIn(context)) return;
                  _navigateAndClose(context, () {
                    AppRoutes.navigateToProfile(context);
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  children: [
                    // Profile image with 3D shadow and gradient border - CachedMediaImage avoids flicker on rebuild
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: ShadowStyles.coloredShadow(
                          AppTheme.primaryColor,
                          opacity: isDark ? 0.2 : 0.35,
                        ),
                      ),
                      child: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                          ? ClipOval(
                              child: CachedMediaImage(
                                mediaKey: user.photoUrl,
                                width: 88,
                                height: 88,
                                fit: BoxFit.cover,
                                placeholder: SizedBox(
                                  width: 88,
                                  height: 88,
                                  child: Center(
                                    child: Text(
                                      initials,
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: SizedBox(
                                  width: 88,
                                  height: 88,
                                  child: Center(
                                    child: Text(
                                      initials,
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : SizedBox(
                              width: 88,
                              height: 88,
                              child: Center(
                                child: Text(
                                  initials,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurface.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              );
                },
              ),
              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.3)),
              const SizedBox(height: 8),

              // --- Menu Items ---
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    _DrawerMenuItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      color: AppTheme.primaryColor,
                      onTap: () => _navigateAndClose(context, () {
                        AppRoutes.navigateToHome(context);
                      }),
                    ),
                    _DrawerMenuItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Profile',
                      color: AppTheme.primaryColor,
                      onTap: () {
                        if (AppRoutes.requireSignIn(context)) return;
                        _navigateAndClose(context, () {
                          AppRoutes.navigateToProfile(context);
                        });
                      },
                    ),
                    _DrawerMenuItem(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Wallet',
                      color: AppTheme.primaryColor,
                      onTap: () => _navigateAndClose(
                        context,
                        () => AppRoutes.navigateToWallet(context),
                      ),
                    ),
                    _DrawerMenuItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Messages',
                      color: AppTheme.communityColor,
                      onTap: () {
                        if (AppRoutes.requireSignIn(context)) return;
                        _navigateAndClose(context, () {
                          GuardedNavigator.push(context,
                            MaterialPageRoute(
                              builder: (_) => const ChatListScreen(showBackButton: true),
                            ),
                          );
                        });
                      },
                    ),

                    _DrawerMenuItem(
                      icon: Icons.trending_up,
                      label: 'Promotions',
                      color: AppTheme.primaryColor,
                      onTap: () => _navigateAndClose(
                        context,
                        () => AppRoutes.navigateToPromotions(context),
                      ),
                    ),
                  ],
                ),
              ),

              // --- Sign Out / Sign In ---
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  final isAuthed = auth.isAuthenticated;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: ShadowStyles.getThemeAwareShadow(
                          context,
                          intensity: ShadowIntensity.medium,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: isAuthed
                              ? () => _signOut(context)
                              : () => _navigateAndClose(context, () {
                                    GuardedNavigator.pushNamed(context,
                                      AppConstants.loginRoute,
                                    );
                                  }),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: scheme.outline.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              isAuthed ? 'Sign out' : 'Sign in',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  void _navigateAndClose(BuildContext context, VoidCallback navigate) {
    Navigator.pop(context);
    onClose?.call();
    // Run after the drawer close frame so NavigationTapGuard isn't fighting
    // the pop, and the destination push isn't dropped.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) navigate();
    });
  }

  void _signOut(BuildContext context) {
    Navigator.pop(context);
    onClose?.call();
    AppRoutes.completeSignOut(context);
  }
}

class _DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DrawerMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surface.withValues(alpha: 0.6)
            : scheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: ShadowStyles.getThemeAwareShadow(
          context,
          intensity: ShadowIntensity.light,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.25),
                        color.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        offset: const Offset(0, 3),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: scheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
