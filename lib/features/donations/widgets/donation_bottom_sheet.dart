import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/compliance/ios_campaign_support.dart';
import '../models/donation_models.dart';
import '../providers/campaign_provider.dart';
import '../../karma/providers/karma_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/models/chat_conversation.dart';
import '../screens/donation_chat_screen.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/utils/donation_karma_utils.dart';
import '../../../core/utils/app_messenger.dart';
import 'donation_success_dialog.dart';
import '../api/campaign_api.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../wallet/services/wallet_service.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class DonationBottomSheet extends StatefulWidget {
  final Campaign campaign;

  const DonationBottomSheet({
    super.key,
    required this.campaign,
  });

  @override
  State<DonationBottomSheet> createState() => _DonationBottomSheetState();
}

class _DonationBottomSheetState extends State<DonationBottomSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final PageController _pageController = PageController();
  final WalletService _walletService = WalletService();
  
  int _currentStep = 0;
  double _donationAmount = 0.0;
  final String _selectedCurrency = 'BYC'; // Fixed to BYC only
  bool _isAnonymous = false;
  bool _isProcessing = false;
  String? _message;
  List<RewardTier> _rewardTiers = [];
  String? _selectedRewardTierId;
  bool _loadingTiers = false;
  bool _loadingBalance = true;
  double _availableBalance = 0.0;

  final List<double> _quickAmounts = [10, 25, 50, 100, 250, 500];

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tapping anywhere outside an input dismisses the keyboard — this is
      // the standard iOS/Android behaviour users expect in a form sheet.
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          color: Colors.white,
        ),
        child: Column(
          children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Support Donation',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.campaign.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(width: 48), // Balance the close button
              ],
            ),
          ),

          // Progress indicator
          _buildProgressIndicator(),

          // Content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildAmountStep(),
                _buildDetailsStep(),
                _buildConfirmationStep(),
              ],
            ),
          ),

          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (CampaignSupportCompliance.blocksInAppDonations) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pop();
        CampaignSupportCompliance.openWebSupport(
          context,
          campaignId: widget.campaign.id,
          campaign: widget.campaign,
        );
      });
      return;
    }
    _loadRewardTiers();
    _loadWalletBalance();
  }

  Future<void> _loadWalletBalance() async {
    try {
      setState(() { _loadingBalance = true; });
      
      // Get authenticated user ID
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;
      
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Initialize wallet service if not already done
      if (!_walletService.isInitialized || 
          _walletService.currentBalance?.userId != userId) {
        await _walletService.initializeWallet(userId);
      }
      
      // Get available balance
      final balance = _walletService.currentBalance?.availableBalance ?? 0.0;
      
      if (mounted) {
        setState(() {
          _availableBalance = balance;
          _loadingBalance = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loadingBalance = false; });
        AppToast.error(context, 'Failed to load wallet balance: ${e.toString()}');
      }
    }
  }

  Future<void> _loadRewardTiers() async {
    try {
      setState(() { _loadingTiers = true; });
      const storage = FlutterSecureStorage();
      final api = CampaignApi(ApiClient(EnvConfig.defaultBaseUrl, storage));
      final items = await api.getRewardTiers(widget.campaign.id);
      final tiers = items.map((m) => RewardTier(
        id: (m['id'] ?? '').toString(),
        campaignId: widget.campaign.id,
        title: (m['title'] ?? '').toString(),
        description: (m['description'] ?? '').toString(),
        minimumDonation: (m['minimumDonation'] is num ? (m['minimumDonation'] as num).toDouble() : double.tryParse('${m['minimumDonation']}') ?? 0.0),
        limitedQuantity: m['limitedQuantity'] as int?,
        claimedCount: (m['claimedCount'] as int?) ?? 0,
        status: RewardTierStatus.available,
        includes: const [],
        isPhysical: false,
      )).toList();
      setState(() { _rewardTiers = tiers; });
    } catch (_) {
    } finally {
      if (mounted) setState(() { _loadingTiers = false; });
    }
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(3, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;
          
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: isCompleted 
                    ? AppColors.primary 
                    : isCurrent 
                        ? AppColors.primary.withValues(alpha: 0.55) 
                        : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAmountStep() {
    final bycBalance = _availableBalance;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
      // Donation summary
      ShadowCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Donation Progress',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: widget.campaign.progressPercentage,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(widget.campaign.categoryColor),
              minHeight: 6,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.campaign.formattedRaised}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text(
                  'Goal: ${widget.campaign.formattedGoal}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

              const SizedBox(height: 24),

              // Wallet balance display
              ShadowCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.account_balance_wallet,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your BYBATA Coin Balance',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              _loadingBalance
                                ? const SizedBox(
                                    height: 24,
                                    child: Center(
                                      child: SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  )
                                : Text(
                                    '${bycBalance.toStringAsFixed(2)} BYC',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                            ],
                          ),
                        ),
                        if (!_loadingBalance && bycBalance < 100) // Show fund button if balance is low
                          ElevatedButton.icon(
                            onPressed: () => _showFundWalletOptions(context),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Fund'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(80, 36),
                            ),
                          ),
                      ],
                    ),
                    if (!_loadingBalance && bycBalance == 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info, color: Colors.orange[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You need BYC to make donations. Fund your wallet to continue.',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Amount selection
              Text(
                'Choose Your Donation Amount (BYC)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Quick amount buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickAmounts.map((amount) {
                  final isSelected = _donationAmount == amount;
                  final canAfford = amount <= bycBalance;
                  
                  return ActionShadowCard(
                    onTap: canAfford ? () {
                      setState(() {
                        _donationAmount = amount;
                        _amountController.text = amount.toString();
                      });
                    } : null,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: isSelected ? AppColors.primary : (canAfford ? null : Colors.grey[200]),
                    child: Text(
                      '$amount BYC',
                      style: TextStyle(
                        color: isSelected ? Colors.white : 
                               canAfford ? Colors.black87 : Colors.grey[500],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Custom amount input
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                decoration: InputDecoration(
                  labelText: 'Custom Amount (BYC)',
                  border: const OutlineInputBorder(),
                  suffixText: 'BYC',
                  helperText: bycBalance > 0 ? 'Available: ${bycBalance.toStringAsFixed(2)} BYC' : null,
                  errorText: _donationAmount > bycBalance ? 'Insufficient balance' : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _donationAmount = double.tryParse(value) ?? 0.0;
                  });
                },
                onFieldSubmitted: (_) {
                  // Dismiss the keyboard when the user taps the "Done"
                  // action on the software keyboard.
                  FocusScope.of(context).unfocus();
                },
              ),

          const SizedBox(height: 16),

              // Karma reward info
              if (_donationAmount > 0 && _donationAmount <= bycBalance) 
                ShadowCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber[100],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.stars,
                          color: Colors.orange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Earn +${_calculateKarmaReward(_donationAmount)} KARMA',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const Text(
              'For supporting this donation',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Donation summary
          ShadowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Donation Summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Amount:'),
                    Text(
                      '$_donationAmount $_selectedCurrency',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('KARMA Reward:'),
                    Text(
                      '+${_calculateKarmaReward(_donationAmount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Reward tier selection (optional)
          if (_loadingTiers) const LinearProgressIndicator(),
          if (_rewardTiers.isNotEmpty) ...[
            Text(
              'Choose a Reward (Optional)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ShadowCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _rewardTiers.map((tier) {
                  final selected = _selectedRewardTierId == tier.id;
                  return ActionShadowCard(
                    onTap: () {
                      setState(() {
                        _selectedRewardTierId = tier.id;
                        if (_donationAmount < tier.minimumDonation) {
                          _donationAmount = tier.minimumDonation;
                        }
                      });
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: selected ? AppColors.primary : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tier.title, style: TextStyle(color: selected ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Min: ${tier.minimumDonation.toStringAsFixed(0)} BYC', style: TextStyle(color: selected ? Colors.white70 : Colors.grey[700], fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Optional message
          Text(
            'Add a Message (Optional)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _messageController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Share why this campaign matters to you...',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _message = value.isEmpty ? null : value;
              });
            },
          ),

          const SizedBox(height: 24),

          // Anonymous option
          ShadowCard(
            child: CheckboxListTile(
              title: const Text('Donate Anonymously'),
              subtitle: const Text('Your name will not be shown to other supporters'),
              value: _isAnonymous,
              onChanged: (value) {
                setState(() {
                  _isAnonymous = value ?? false;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success icon
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite,
                size: 40,
                color: AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Confirm Your Donation',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Final summary
          ShadowCard(
            child: Column(
              children: [
              _buildSummaryRow('Donation:', widget.campaign.title),
                const Divider(),
                _buildSummaryRow('Amount:', '$_donationAmount $_selectedCurrency'),
                const Divider(),
                _buildSummaryRow('KARMA Reward:', '+${_calculateKarmaReward(_donationAmount)}'),
                if (_message != null) ...[
                  const Divider(),
                  _buildSummaryRow('Message:', _message!),
                ],
                const Divider(),
                _buildSummaryRow('Anonymous:', _isAnonymous ? 'Yes' : 'No'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Impact message
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Your Impact',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Your donation will help ${widget.campaign.creator.name} reach their goal of ${widget.campaign.formattedGoal}. Thank you for making a difference!',
                  style: TextStyle(color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _messageOwner,
                    icon: const Icon(Icons.chat),
                    label: const Text('Message Owner'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: _isProcessing 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : Text(_getButtonText()),
            ),
          ),
        ],
      ),
    );
  }

  String _getButtonText() {
    switch (_currentStep) {
      case 0: return 'Continue';
      case 1: return 'Review';
      case 2: return 'Donate Now';
      default: return 'Continue';
    }
  }

  bool _canProceed() {    
    switch (_currentStep) {
      case 0: return _donationAmount > 0 && _donationAmount <= _availableBalance && !_loadingBalance;
      case 1: return _donationAmount > 0 && _donationAmount <= _availableBalance && !_loadingBalance;
      case 2: return _donationAmount > 0 && _donationAmount <= _availableBalance && !_loadingBalance;
      default: return false;
    }
  }

  void _nextStep() {
    if (!_canProceed()) return;

    // Dismiss the keyboard whenever the user advances/confirms so it never
    // lingers over the review step or the success state.
    FocusScope.of(context).unfocus();

    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _processDonation();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _processDonation() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final campaignProvider = Provider.of<CampaignProvider>(context, listen: false);
      final karmaProvider = Provider.of<KarmaProvider>(context, listen: false);
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);

      // Final balance check before processing
      if (_donationAmount > _availableBalance) {
        throw Exception('Insufficient BYC balance. Available: ${_availableBalance.toStringAsFixed(2)} BYC');
      }

      // Validate donation amount
      if (_donationAmount <= 0) {
        throw Exception('Invalid donation amount');
      }

      // Make the donation (backend will handle BYC debit from donor and credit to founder)
      final donation = await campaignProvider.donateToCampaign(
        widget.campaign.id,
        amount: _donationAmount,
        currency: 'BYC', // Fixed to BYC
        isAnonymous: _isAnonymous,
        message: _message,
        rewardTierId: _selectedRewardTierId,
      );

      if (donation != null) {
        // Refresh both wallet service and provider to reflect the deducted amount
        await _loadWalletBalance();
        await walletProvider.refreshWallet();
        
        // Refresh KARMA from API (server awards DONATION_MADE on successful donate)
        await karmaProvider.initialize();
        final karmaEarned = donation.karmaAwarded > 0
            ? donation.karmaAwarded
            : calculateDonationKarmaReward(_donationAmount);

        if (mounted) {
          final amount = _donationAmount;
          final earned = karmaEarned;
          final title = widget.campaign.title;
          Navigator.of(context).pop(true);
          final dialogContext = appNavigatorKey.currentContext;
          if (dialogContext != null && dialogContext.mounted) {
            await DonationSuccessDialog.show(
              dialogContext,
              amountByc: amount,
              karmaEarned: earned,
              campaignTitle: title,
            );
          }
        }
      } else {
        throw Exception('Donation processing failed. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        AppToast.error(context, errorMsg.isNotEmpty ? errorMsg : 'Donation failed. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  int _calculateKarmaReward(double amount) => calculateDonationKarmaReward(amount);

  Future<void> _messageOwner() async {
    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      
      final existing = chatProvider.findConversationInCache(
        contextId: widget.campaign.id,
        partnerId: widget.campaign.creator.id,
      );

      if (mounted) {
        GuardedNavigator.push(context, 
          MaterialPageRoute(
            builder: (_) => DonationChatScreen(
              campaign: widget.campaign,
              partnerId: widget.campaign.creator.id,
              partnerName: widget.campaign.creator.name,
              existingConversation: existing,
            ),
          ),
        );
      }
    } catch (_) {
      AppToast.error(context, 'Failed to start chat');
    }
  }

  void _showFundWalletOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fund Wallet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'You need BYBATA Coins (BYC) to donate. Open the Wallet to add funds.',
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static void show(BuildContext context, Campaign campaign) {
    if (CampaignSupportCompliance.blocksInAppDonations) {
      CampaignSupportCompliance.openWebSupport(
        context,
        campaignId: campaign.id,
        campaign: campaign,
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DonationBottomSheet(campaign: campaign),
    );
  }
}
