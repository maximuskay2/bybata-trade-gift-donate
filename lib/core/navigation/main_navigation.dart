import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/theme_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../features/home_v2/screens/home_screen_v2.dart';
import '../../features/wallet/screens/wallet_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../providers/notification_provider.dart';
import 'app_routes.dart';
import '../providers/auth_provider.dart';
import '../widgets/location_chip.dart';
import '../widgets/app_side_drawer.dart';
import 'app_drawer_opener.dart';
import '../widgets/cached_media_image.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Opens the global create sheet (Trade, Gift, Donate, Ask for help).
void showAppCreateSheet(BuildContext context) {
  final auth = context.read<AuthProvider>();
  if (!auth.isAuthenticated) {
    AppRoutes.showLoginRequired(context);
    return;
  }
  HapticFeedback.mediumImpact();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (ctx) => _CreateSheet(
      onCreateTrade: () {
        Navigator.pop(ctx);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) AppRoutes.navigateToCreateTrade(context);
        });
      },
      onCreateGift: () {
        Navigator.pop(ctx);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) AppRoutes.navigateToCreateGift(context);
        });
      },
      onCreateCampaign: () {
        Navigator.pop(ctx);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) AppRoutes.navigateToCreateCampaign(context);
        });
      },
      onAskForHelp: () {
        Navigator.pop(ctx);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) AppRoutes.navigateToAskForHelp(context);
        });
      },
    ),
  );
}

class MainNavigation extends StatefulWidget {
  final String? initialScreen;

  const MainNavigation({super.key, this.initialScreen});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late String _selectedScreen;
  int _navIndex = 0;
  bool _showOthersMenu = false;
  int _prevIndex = 0;

  @override
  void initState() {
    super.initState();
    AppDrawerOpener.registerMainScaffoldKey(_scaffoldKey);
    final screen = widget.initialScreen ?? 'home';
    _selectedScreen = (screen == 'community') ? 'home' : screen;
    _navIndex = _mapScreenToIndex(_selectedScreen);
  }

  @override
  void dispose() {
    AppDrawerOpener.unregisterMainScaffoldKey(_scaffoldKey);
    super.dispose();
  }

  Widget get _currentScreen {
    switch (_selectedScreen) {
      case 'home':
        return const HomeScreenV2();
      case 'wallet':
        return const WalletScreen();
      case 'chats':
      case 'chat':
        return const ChatListScreen(showBackButton: false);
      case 'you':
      case 'profile':
        return const ProfileScreen();
      default:
        return const HomeScreenV2();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        if (_showOthersMenu) {
          setState(() => _showOthersMenu = false);
          return false;
        }
        if (_navIndex != 0) {
          setState(() {
            _prevIndex = _navIndex;
            _navIndex = 0;
            _selectedScreen = 'home';
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const AppSideDrawer(),
        extendBody: true, 
        resizeToAvoidBottomInset: true, 
        backgroundColor: isDark ? const Color(0xFF0D0B12) : Colors.white,
        body: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              color: isDark ? const Color(0xFF0D0B12) : Colors.white,
            ),
            
            Column(
              children: [
                Container(
                  height: MediaQuery.of(context).padding.top + 56,
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: MediaQuery.of(context).padding.top,
                  ),
                  decoration: BoxDecoration(
                    color: themeProvider.isGlassModeEnabled
                        ? (isDark ? const Color(0xFF15101F).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.4))
                        : Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: themeProvider.isGlassModeEnabled
                            ? (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))
                            : Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.grid_view_rounded,
                          color: isDark
                              ? Colors.white
                              : (themeProvider.isGlassModeEnabled
                                  ? Theme.of(context).colorScheme.onSurface
                                  : AppTheme.primaryColor),
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _scaffoldKey.currentState?.openDrawer();
                        },
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                      if (_selectedScreen == 'home') ...[
  // This layout wrapper ensures the chip shrinks down precisely to the text size
  Expanded(
    child: Center(
      child: IntrinsicWidth(
        child: LocationChip(
          isGlassTheme: themeProvider.isGlassModeEnabled,
        ),
      ),
    ),
  ),
] else ...[
                        const SizedBox(width: 4),
                        Consumer<AuthProvider>(
                          builder: (context, authProvider, child) {
                            final user = authProvider.currentUser;
                            final userName = user?.displayName ?? user?.email ?? 'User';
                            final initials = _getInitials(userName);
                            final textColor = themeProvider.isGlassModeEnabled
                                ? Theme.of(context).colorScheme.onSurface
                                : AppTheme.primaryColor;
                            final placeholder = CircleAvatar(
                              radius: 18,
                              backgroundColor: themeProvider.isGlassModeEnabled
                                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)
                                  : AppTheme.primaryColor.withValues(alpha: 0.1),
                              child: Text(
                                initials,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                              ),
                            );
                            
                            final photoUrl = user?.photoUrl;
                            final hasPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedScreen = 'you';
                                  _navIndex = 4;
                                });
                              },
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                // FIXED NULL-SAFETY ERROR PASSES: Safe chained syntax definitions
                                child: hasPhoto
                                    ? ClipOval(
                                        child: CachedMediaImage(
                                          mediaKey: photoUrl,
                                          width: 36,
                                          height: 36,
                                          fit: BoxFit.cover,
                                          placeholder: placeholder,
                                          errorWidget: placeholder,
                                        ),
                                      )
                                    : placeholder,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        Text(
                          _getScreenTitle(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: themeProvider.isGlassModeEnabled
                                ? Theme.of(context).colorScheme.onSurface
                                : null,
                          ),
                        ),
                        const Spacer(),
                      ],
                      Consumer<NotificationProvider>(
                        builder: (context, notificationProvider, child) {
                          final unreadCount = notificationProvider.unreadCount;
                          return _NotificationButton(
                            unreadCount: unreadCount,
                            isGlassTheme: themeProvider.isGlassModeEnabled,
                            onTap: () =>
                                AppRoutes.navigateToNotifications(context),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.fastOutSlowIn,
                    switchOutCurve: Curves.fastOutSlowIn,
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        children: <Widget>[
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    transitionBuilder: (child, animation) {
                      final direction = _navIndex >= _prevIndex ? 0.08 : -0.08;
                      final slide = Tween<Offset>(
                        begin: Offset(direction, 0),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey<String>(_selectedScreen),
                      child: _currentScreen,
                    ),
                  ),
                ),
              ],
            ),
            
            if (_showOthersMenu)
              Positioned(
                left: 0,
                right: 0,
                bottom: 80,
                child: _ModernOthersMenu(
                  onNavigate: (route) {
                    setState(() => _showOthersMenu = false);
                    GuardedNavigator.pushNamed(context, route);
                  },
                ),
              ),
          ],
        ),
        floatingActionButton: _buildFloatingActionButton(context),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  String _getScreenTitle() {
    switch (_selectedScreen) {
      case 'home':
        return '';
      case 'wallet':
        return 'Wallet';
      case 'chats':
      case 'chat':
        return 'Messages';
      case 'you':
      case 'profile':
        return 'You';
      default:
        return '';
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  int _mapScreenToIndex(String screen) {
    switch (screen) {
      case 'home':
        return 0;
      case 'wallet':
        return 1;
      case 'chats':
      case 'chat':
        return 3;
      case 'you':
      case 'profile':
        return 4;
      default:
        return 0;
    }
  }

  String _mapIndexToScreen(int index) {
    switch (index) {
      case 0:
        return 'home';
      case 1:
        return 'wallet';
      case 3:
        return 'chats';
      case 4:
        return 'you';
      default:
        return 'home';
    }
  }

  Widget? _buildFloatingActionButton(BuildContext context) {
    return null;
  }
}

class _ModernOthersMenu extends StatelessWidget {
  final ValueChanged<String> onNavigate;
  const _ModernOthersMenu({required this.onNavigate});
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); 
  }
}

class _NotificationButton extends StatelessWidget {
  final int unreadCount;
  final bool isGlassTheme;
  final VoidCallback onTap;

  const _NotificationButton({
    required this.unreadCount,
    required this.isGlassTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isGlassTheme
                  ? scheme.onSurface.withValues(alpha: 0.15)
                  : scheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_outlined,
              size: 20,
              color: isGlassTheme ? scheme.onSurface : scheme.primary,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                decoration: BoxDecoration(
                  color: scheme.error,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isGlassTheme ? scheme.surface : Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: TextStyle(
                    color: scheme.onError,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CreateSheet extends StatelessWidget {
  final VoidCallback onCreateTrade;
  final VoidCallback onCreateGift;
  final VoidCallback onCreateCampaign;
  final VoidCallback onAskForHelp;

  const _CreateSheet({
    required this.onCreateTrade,
    required this.onCreateGift,
    required this.onCreateCampaign,
    required this.onAskForHelp,
  });

  static const _actions = [
    (
      icon: Icons.swap_horiz_rounded,
      color: AppTheme.tradeColor,
      title: 'Trade',
      subtitle: 'List something to swap or sell',
    ),
    (
      icon: Icons.card_giftcard_rounded,
      color: AppTheme.giftColor,
      title: 'Gift',
      subtitle: 'Share something with the community',
    ),
    (
      icon: Icons.volunteer_activism_rounded,
      color: AppTheme.donationColor,
      title: 'Donate',
      subtitle: 'Start a campaign and raise support',
    ),
    (
      icon: Icons.forum_rounded,
      color: AppColors.primary,
      title: 'Ask for help',
      subtitle: 'Reach out when you need a hand',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What would you like to create?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick an option below to get started',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: scheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _CreateSheetRow(
                  icon: _actions[0].icon,
                  color: _actions[0].color,
                  title: _actions[0].title,
                  subtitle: _actions[0].subtitle,
                  onTap: onCreateTrade,
                ),
                const SizedBox(height: 10),
                _CreateSheetRow(
                  icon: _actions[1].icon,
                  color: _actions[1].color,
                  title: _actions[1].title,
                  subtitle: _actions[1].subtitle,
                  onTap: onCreateGift,
                ),
                const SizedBox(height: 10),
                _CreateSheetRow(
                  icon: _actions[2].icon,
                  color: _actions[2].color,
                  title: _actions[2].title,
                  subtitle: _actions[2].subtitle,
                  onTap: onCreateCampaign,
                ),
                const SizedBox(height: 10),
                _CreateSheetRow(
                  icon: _actions[3].icon,
                  color: _actions[3].color,
                  title: _actions[3].title,
                  subtitle: _actions[3].subtitle,
                  onTap: onAskForHelp,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset > 0 ? bottomInset + 8 : 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurface.withValues(alpha: 0.55),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Not now',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateSheetRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CreateSheetRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : color.withValues(alpha: 0.07),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.28 : 0.18),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color,
                        Color.lerp(color, Colors.black, 0.12)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: scheme.onSurface.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: color.withValues(alpha: 0.75),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}