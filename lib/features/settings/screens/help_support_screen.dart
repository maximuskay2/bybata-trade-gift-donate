import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/borderless_input_decoration.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../core/widgets/guest_browse_helpers.dart';
import '../../../core/widgets/hub_fluid_tab_switcher.dart';
import '../../../core/widgets/hub_screen_top_bar.dart';
import '../../../features/settings/widgets/settings_ui.dart';
import '../../../core/widgets/loading_states.dart';
import '../../../features/common/widgets/interaction_components.dart';
import '../../../features/karma/navigation/karma_navigator.dart';
import '../models/faq_item.dart';
import '../models/support_ticket.dart';
import '../services/support_api.dart';
import '../widgets/contact_method_card.dart';
import '../widgets/faq_expansion_tile.dart';
import '../widgets/support_chat_widget.dart';
import '../widgets/ticket_status_card.dart';
import 'support_ticket_screens.dart';
import 'package:bybata/core/theme/app_theme.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

const _kSupportEmail = 'info@bybata.com';
const _kSupportPhone = '08036954577';

class HelpSupportScreen extends StatefulWidget {
  final int initialTab;
  
  const HelpSupportScreen({
    super.key,
    this.initialTab = 0,
  });

  /// Opens Help & Support only for signed-in users; guests see the sign-in dialog.
  static void open(BuildContext context, {int initialTab = 0}) {
    if (AppRoutes.requireSignIn(context)) return;
    GuardedNavigator.push(context,
      MaterialPageRoute(
        builder: (_) => HelpSupportScreen(initialTab: initialTab),
      ),
    );
  }

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<FAQItem> _faqItems = [];
  List<FAQItem> _filteredFAQs = [];
  List<SupportTicket> _userTickets = [];
  bool _isLoadingFAQs = false;
  bool _isLoadingTickets = false;
  String? _loadError;
  SupportApi? _supportApi;
  bool _apiInitialized = false;
  bool _guestPromptShown = false;

  static const _tabLabels = ['FAQ', 'Contact', 'Chat', 'Tickets'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabLabels.length,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabController.addListener(_onTabControllerUpdate);
  }

  void _onTabControllerUpdate() {
    if (_tabController.indexIsChanging) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    setState(() {});
  }

  void _ensureApiLoaded() {
    if (_apiInitialized) return;
    _apiInitialized = true;
    _initApi();
  }

  void _promptGuestSignIn() {
    if (_guestPromptShown) return;
    _guestPromptShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppRoutes.showLoginRequired(context);
    });
  }

  Future<void> _initApi() async {
    try {
      const storage = FlutterSecureStorage();
      final client = ApiClient(await EnvConfig.getBaseUrl(), storage);
      _supportApi = SupportApi(client);
      await Future.wait([_loadFAQs(), _loadUserTickets()]);
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabControllerUpdate);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFAQs() async {
    if (_supportApi == null) return;
    setState(() => _isLoadingFAQs = true);
    try {
      final items = await _supportApi!.fetchFaqs();
      if (!mounted) return;
      setState(() {
        _faqItems = items;
        _filteredFAQs = items;
      });
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Could not load FAQs: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoadingFAQs = false);
    }
  }

  Future<void> _loadUserTickets() async {
    if (_supportApi == null) return;
    setState(() => _isLoadingTickets = true);
    try {
      final items = await _supportApi!.fetchTickets();
      if (!mounted) return;
      setState(() => _userTickets = items);
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Could not load tickets: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoadingTickets = false);
    }
  }

  void _searchFAQs(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFAQs = _faqItems;
      } else {
        _filteredFAQs = _faqItems.where((faq) {
          return faq.question.toLowerCase().contains(query.toLowerCase()) ||
                 faq.answer.toLowerCase().contains(query.toLowerCase()) ||
                 faq.category.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAuthed = context.watch<AuthProvider>().isAuthenticated;
    if (!isAuthed) {
      _promptGuestSignIn();
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Help & Support',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        body: const GuestSignInPrompt(
          title: 'Sign in for Help & Support',
          message:
              'Create an account or sign in to access FAQs, live chat, and support tickets.',
        ),
      );
    }

    _ensureApiLoaded();

    return Scaffold(
      backgroundColor: SettingsUi.pageBackground(context),
      body: Column(
        children: [
          HubScreenTopBar(
            title: 'Help & Support',
            onBack: () => Navigator.of(context).pop(),
            trailingActions: [
              HubTopBarIconButton(
                icon: Icons.emergency_rounded,
                onTap: _showEmergencyHelp,
                isDark: Theme.of(context).brightness == Brightness.dark,
                iconColor: Colors.red,
              ),
            ],
          ),
          HubFluidTabSwitcher(
            controller: _tabController,
            labels: _tabLabels,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFAQTab(),
                _buildContactTab(),
                _buildChatTab(),
                _buildTicketsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQTab() {
    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: _searchFAQs,
            decoration: BorderlessInputDecoration.search(
              hintText: 'Search FAQs...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _searchFAQs('');
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
          ),
        ),

        // FAQ Content
        Expanded(
          child: _isLoadingFAQs
              ? const Center(
                  child: SmartLoadingIndicator(
                    message: 'Loading FAQs...',
                    type: LoadingType.circular,
                  ),
                )
              : _filteredFAQs.isEmpty
                  ? _buildEmptyFAQState()
                  : _buildFAQList(),
        ),
      ],
    );
  }

  Widget _buildFAQList() {
    // Group FAQs by category
    final groupedFAQs = <String, List<FAQItem>>{};
    for (final faq in _filteredFAQs) {
      groupedFAQs.putIfAbsent(faq.category, () => []).add(faq);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedFAQs.length,
      itemBuilder: (context, index) {
        final category = groupedFAQs.keys.elementAt(index);
        final faqs = groupedFAQs[category]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: 24),
            
            // Category Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _getCategoryIcon(category),
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${faqs.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // FAQ Items
            ...faqs.map((faq) => FAQExpansionTile(
                faqItem: faq,
              )).toList(),
          ],
        );
      },
    );
  }

  Widget _buildEmptyFAQState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No FAQs found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search terms',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ActionButton(
            text: 'Clear Search',
            style: ActionButtonStyle.outline,
            onPressed: () {
              _searchController.clear();
              _searchFAQs('');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.support_agent,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Get Help from Our Team',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Choose the best way to reach us',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Quick Contact Methods
          const Text(
            'Contact Methods',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          ContactMethodCard(
            icon: Icons.chat_bubble,
            title: 'Live Chat',
            description: 'Chat with our support team • Usually responds within 5 minutes',
            value: 'Available 24/7',
            color: Colors.green,
            onTap: () => _startLiveChat(),
          ),

          const SizedBox(height: 12),

          ContactMethodCard(
            icon: Icons.email,
            title: 'Email Support',
            description: 'Send us a detailed email • Usually responds within 2-4 hours',
            value: _kSupportEmail,
            color: AppColors.primary,
            onTap: () => _sendEmail(),
          ),

          const SizedBox(height: 12),

          ContactMethodCard(
            icon: Icons.phone,
            title: 'Phone Support',
            description: 'Call our support hotline • For urgent issues only',
            value: _kSupportPhone,
            color: Colors.orange,
            onTap: () => _callSupport(),
          ),

          const SizedBox(height: 12),

          ContactMethodCard(
            icon: Icons.bug_report,
            title: 'Report Bug',
            description: 'Found a bug? Let us know with details',
            value: 'Submit Report',
            color: Colors.red,
            onTap: () => _reportBug(),
          ),

          const SizedBox(height: 24),

          // Community Support
          const Text(
            'Community Support',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          ContactMethodCard(
            icon: Icons.forum,
            title: 'Community Forum',
            description: 'Ask questions and get help from other users',
            value: 'Join Community',
            color: Colors.purple,
            onTap: () => _openForum(),
          ),

          const SizedBox(height: 12),

          ContactMethodCard(
            icon: Icons.school,
            title: 'Tutorials & Guides',
            description: 'Learn how to use BYBATA with step-by-step guides',
            value: 'View Tutorials',
            color: Colors.teal,
            onTap: () => _openTutorials(),
          ),

          const SizedBox(height: 24),

          // Emergency Contact
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emergency, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Emergency Support',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'For urgent security issues, account compromise, or safety concerns.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ActionButton(
                    text: 'Emergency Contact',
                    style: ActionButtonStyle.danger,
                    onPressed: () => _emergencyContact(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return const SupportChatWidget();
  }

  Widget _buildTicketsTab() {
    return Column(
      children: [
        // Header with Create Ticket Button
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Support Tickets',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Track your support requests',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              ActionButton(
                text: 'New Ticket',
                icon: Icons.add,
                onPressed: () => _createNewTicket(),
              ),
            ],
          ),
        ),

        // Tickets List
        Expanded(
          child: _isLoadingTickets
              ? const Center(
                  child: SmartLoadingIndicator(
                    message: 'Loading tickets...',
                    type: LoadingType.circular,
                  ),
                )
              : _userTickets.isEmpty
                  ? _buildEmptyTicketsState()
                  : _buildTicketsList(),
        ),
      ],
    );
  }

  Widget _buildTicketsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userTickets.length,
      itemBuilder: (context, index) {
        final ticket = _userTickets[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TicketStatusCard(
            ticket: ticket,
            onTap: () => _viewTicket(ticket),
          ),
        );
      },
    );
  }

  Widget _buildEmptyTicketsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.confirmation_number_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Support Tickets',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You haven\'t created any support tickets yet',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ActionButton(
            text: 'Create First Ticket',
            icon: Icons.add,
            onPressed: () => _createNewTicket(),
          ),
        ],
      ),
    );
  }

  // Helper Methods
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'account':
        return Icons.account_circle;
      case 'trading':
        return Icons.swap_horiz;
      case 'gifts':
        return Icons.card_giftcard;
      case 'donations':
        return Icons.favorite;
      case 'community':
        return Icons.groups;
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'karma':
        return Icons.auto_awesome;
      case 'support':
        return Icons.support_agent;
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'technical':
        return Icons.build;
      case 'security':
        return Icons.security;
      default:
        return Icons.help_outline;
    }
  }

  void _recordFeedback(String faqId, bool helpful) {
    HapticUtils.light();
    // Record feedback for analytics
    AppToast.show(context, helpful ? 'Thanks for your feedback!' : 'Feedback recorded');
  }

  void _showEmergencyHelp() {
    EmergencySupportIntroSheet.show(
      context,
      onContinue: _emergencyContact,
    );
  }

  // Action Methods
  void _startLiveChat() {
    HapticUtils.light();
    _tabController.animateTo(2); // Switch to chat tab
  }

  void _sendEmail() async {
    HapticUtils.light();
    final uri = Uri(
      scheme: 'mailto',
      path: _kSupportEmail,
      queryParameters: {'subject': 'BYBATA Support Request'},
    );
    if (!await launchUrl(uri)) {
      await Clipboard.setData(const ClipboardData(text: _kSupportEmail));
      if (mounted) {
        AppToast.show(context, 'Email copied to clipboard');
      }
    }
  }

  void _callSupport() {
    HapticUtils.light();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Support Hotline: $_kSupportPhone'),
            const SizedBox(height: 8),
            Text(
              'Hours: Monday – Friday, 9:00 AM – 6:00 PM WAT',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ActionButton(
            text: 'Call Now',
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri(scheme: 'tel', path: _kSupportPhone);
              if (!await launchUrl(uri)) {
                await Clipboard.setData(const ClipboardData(text: _kSupportPhone));
                if (context.mounted) {
                  AppToast.show(context, 'Phone number copied to clipboard');
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _reportBug() {
    HapticUtils.light();
    CreateSupportTicketSheet.show(
      context,
      isBugReport: true,
      onCreated: _loadUserTickets,
    );
  }

  void _openForum() {
    HapticUtils.light();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Community Forum'),
        content: const Text(
          'The community forum is coming soon. For now, use Live Chat or create a support ticket.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _openTutorials() {
    HapticUtils.light();
    KarmaNavigator.toEarnKarma(context);
  }

  void _emergencyContact() {
    HapticUtils.heavy();
    CreateSupportTicketSheet.show(
      context,
      isEmergency: true,
      onCreated: () {
        _loadUserTickets();
        _tabController.animateTo(3);
      },
    );
  }

  void _createNewTicket() {
    HapticUtils.light();
    CreateSupportTicketSheet.show(context, onCreated: _loadUserTickets);
  }

  void _viewTicket(SupportTicket ticket) {
    HapticUtils.light();
    GuardedNavigator.push(context,
      MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: ticket.id)),
    );
  }
}