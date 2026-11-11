import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../providers/trade_backend_provider.dart';
import '../models/trade_models.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/enhanced_form_field.dart';
import '../../../core/widgets/listing_media_picker.dart';
import '../../../core/models/listing_media.dart';
import '../../../core/widgets/enhanced_stepper.dart';
import '../../../core/widgets/optional_location_card.dart';
import '../../../core/widgets/smart_type_selector.dart';
import '../../../core/widgets/preference_radio_group.dart';
import '../../../core/widgets/fiat_byc_value_field.dart';
import '../../../core/utils/permissions_helper.dart';
import '../../../core/services/location_service.dart';
import '../../../core/motion/publish_finale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/navigation/main_navigation.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/services/listing_seeding_context.dart';
import '../../../core/widgets/listing_creation_progress.dart';
import '../../../core/utils/listing_form_validation.dart';
import '../../../core/widgets/validation_highlight_border.dart';
import '../../../core/widgets/listing_create_shell.dart';
import '../../wallet/services/wallet_service.dart';

class CreateTradeScreen extends StatefulWidget {
  const CreateTradeScreen({super.key});

  @override
  State<CreateTradeScreen> createState() => _CreateTradeScreenState();
}

class _CreateTradeScreenState extends State<CreateTradeScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;
  bool _showValidationHighlight = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _estimatedValueController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  TradeCategory _selectedCategory = TradeCategory.others;
  ItemCondition _selectedCondition = ItemCondition.good;
  ListingMediaDraft _mediaDraft = const ListingMediaDraft();

  DeliveryPreference _deliveryPreference = DeliveryPreference.pickupOnly;
  bool _enableBYCPromotion = false;
  bool _isNegotiable = true;

  bool _isLocationLoading = false;
  String? _currentLocation;
  Position? _currentPosition;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const Duration _stepTransition = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
    for (final c in [_titleController, _descriptionController, _locationController]) {
      c.addListener(_clearValidationHighlight);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _estimatedValueController.dispose();
    _locationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);
    try {
      final status = await LocationService.instance.ensureForFunction(context);
      final granted = status == LocationPermission.always || status == LocationPermission.whileInUse;

      if (!granted) {
        if (!mounted) return;
        setState(() => _isLocationLoading = false);
        return;
      }

      final position = await LocationService.instance.getCurrentPosition(forceRefresh: true);
      if (position == null) {
        if (!mounted) return;
        setState(() => _isLocationLoading = false);
        return;
      }

      setState(() => _currentPosition = position);

      try {
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final locationName =
              [place.locality, place.administrativeArea].where((e) => e != null && e.isNotEmpty).join(', ');
          setState(() {
            _currentLocation = locationName.isNotEmpty ? locationName : 'Current Location';
            _locationController.text = _currentLocation ?? '';
            _isLocationLoading = false;
          });
        }
      } catch (_) {
        setState(() {
          _currentLocation = 'Current Location';
          _locationController.text = _currentLocation ?? '';
          _isLocationLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLocationLoading = false);
    }
  }

  void _clearValidationHighlight() {
    if (_showValidationHighlight) {
      setState(() => _showValidationHighlight = false);
    }
  }

  void _failValidation() {
    setState(() => _showValidationHighlight = true);
    ListingFormValidation.showRequiredFieldsToast(context);
  }

  bool _isStepValid(int step) {
    switch (step) {
      case 0:
        final title = _titleController.text.trim();
        return title.isNotEmpty && title.length >= 3 && !_mediaDraft.isEmpty;
      case 1:
        final desc = _descriptionController.text.trim();
        return desc.isNotEmpty &&
            desc.length >= 10 &&
            _locationController.text.trim().isNotEmpty;
      case 2:
        return true;
      default:
        return false;
    }
  }

  bool _validateCurrentStep() {
    if (_isStepValid(_currentStep)) {
      _clearValidationHighlight();
      return true;
    }
    _failValidation();
    return false;
  }

  Future<void> _goToStep(int step) async {
    if (_currentStep == step) return;
    setState(() => _currentStep = step);
    await _pageController.animateToPage(
      step,
      duration: _stepTransition,
      curve: Curves.easeInOut,
    );
  }

  bool _validateStep(int step) => _isStepValid(step);

  void _nextStep() {
    if (_validateCurrentStep() && _currentStep < 2) {
      _pageController.nextPage(duration: _stepTransition, curve: Curves.easeInOut);
    }
  }

  Future<void> _openReview() async {
    for (var step = 0; step < 2; step++) {
      if (!_isStepValid(step)) {
        await _goToStep(step);
        _failValidation();
        return;
      }
    }
    await _goToStep(2);
  }

  Future<void> _leaveListed() async {
    await showPublishFinale(
      context,
      line: 'Listed',
      color: AppTheme.tradeColor,
      imagePath: _mediaDraft.heroPath,
    );
    if (mounted) AppRoutes.replaceWithTradeHub(context);
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: _stepTransition, curve: Curves.easeInOut);
    }
  }

  void _onPageChanged(int page) => setState(() => _currentStep = page);

  Future<void> _submitTrade() async {
    for (var step = 0; step <= 1; step++) {
      if (!_isStepValid(step)) {
        await _goToStep(step);
        _failValidation();
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<TradeBackendProvider>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final title = _titleController.text.trim();
      final asDraft = _enableBYCPromotion;
      final isSeedingListing = ListingSeedingContext.consumeTradeSeed();

      final success = await ListingCreationProgress.run<bool>(
        context: context,
        accentColor: AppTheme.tradeColor,
        icon: Icons.swap_horiz_rounded,
        title: 'Creating your trade',
        task: (report) => provider.createTrade(
          title: title,
          description: _descriptionController.text.trim(),
          mediaDraft: _mediaDraft,
          category: _selectedCategory.name.toUpperCase(),
          isNegotiable: _isNegotiable,
          requiresPickup: _deliveryPreference == DeliveryPreference.pickupOnly,
          allowDelivery: _deliveryPreference == DeliveryPreference.mixed,
          allowShipping: false,
          enableBYCPromotion: _enableBYCPromotion,
          location: _locationController.text.trim(),
          latitude: _currentPosition?.latitude,
          longitude: _currentPosition?.longitude,
          asDraft: asDraft,
          isSeedingListing: isSeedingListing,
          onProgress: report,
        ),
      );

      if (success != true || !mounted) {
        if (mounted) AppToast.error(context, provider.error ?? 'Failed to create trade');
        return;
      }

      if (_enableBYCPromotion) {
        final tradeId = provider.lastCreatedTradeId;
        if (tradeId == null || tradeId.isEmpty) {
          AppToast.error(context, 'Trade created but could not promote.');
          if (mounted) AppRoutes.replaceWithTradeHub(context);
          return;
        }
        final walletService = WalletService();
        if (auth.currentUser != null && !walletService.isInitialized) {
          await walletService.initializeWallet(auth.currentUser!.id);
        }
        final boostOk = await walletService.tryPurchaseDefaultBoostForTrade(tradeId, title);
        if (boostOk && mounted) {
          final publishOk = await provider.publishDraft(tradeId);
          if (publishOk && mounted) {
            await _leaveListed();
          } else if (mounted) {
            await _leaveListed();
          }
        } else if (mounted) {
          AppToast.success(context, 'Trade saved as draft.');
          AppRoutes.replaceWithTradeHub(context);
        }
      } else {
        if (mounted) await _leaveListed();
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'An error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stage create sits on a light glass sheet — keep form chrome light.
    const isDark = false;
    final accent = AppTheme.tradeColor;

    return ListingCreateShell(
      title: 'Create Trade',
      accentColor: accent,
      currentStep: _currentStep,
      steps: [
        StepConfig(
          title: 'What & photos',
          subtitle: 'Add a clear title, category, and photos',
          icon: Icons.photo_camera_outlined,
        ),
        StepConfig(
          title: 'Story & place',
          subtitle: 'Describe the item and where it is',
          icon: Icons.description_outlined,
        ),
        StepConfig(
          title: 'Preferences',
          subtitle: 'Delivery, negotiation, and boost',
          icon: Icons.tune_rounded,
        ),
      ],
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildCoreInfoStep(isDark, accent),
            _buildDetailsStep(isDark, accent),
            _buildPreferencesStep(isDark, accent),
          ],
        ),
      ),
      showBackButton: true,
      onBack: _previousStep,
      onPrimary: _currentStep < 2 ? _openReview : _submitTrade,
      primaryLabel: _currentStep < 2 ? 'Review' : 'Publish Trade',
      chapterCaption: '${_currentStep + 1} of 3 · ${[
        'What & photos',
        'Story & place',
        'Preferences',
      ][_currentStep]}',
      swipeCommitLabel: _currentStep < 2 ? null : 'Publish Trade',
      onSwipeCommit: _currentStep < 2 ? null : _submitTrade,
      onStage: true,
      heroPath: _mediaDraft.heroPath,
      onHeroTap: _captureFromHero,
      reviewLabel: _currentStep < 2 ? 'Continue' : null,
      isLoading: _isLoading,
    );
  }

  Future<void> _captureFromHero() async {
    final next = await ListingMediaPicker.captureInto(
      context,
      draft: _mediaDraft,
      accentColor: AppTheme.tradeColor,
      title: 'Add photos or a short video',
    );
    if (!mounted || next == null) return;
    setState(() {
      _mediaDraft = next;
      _clearValidationHighlight();
    });
  }

  Widget _buildCoreInfoStep(bool isDark, Color accent) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListingCreateTipCard(
            text: 'Clear photos and a specific title help people trust your listing faster.',
            accentColor: accent,
            isDark: isDark,
          ),
          const SizedBox(height: 18),
          EnhancedFormField(
            controller: _titleController,
            label: 'Trade Title',
            hint: 'e.g., Vintage Camera Collection',
            icon: Icons.title_rounded,
            isRequired: true,
            isDark: isDark,
            minLength: 3,
            helperText: 'Be specific so the right people find you',
            showValidationHighlight: _showValidationHighlight,
          ),
          const SizedBox(height: 20),
          SmartTypeSelector<TradeCategory>(
            selectedValue: _selectedCategory,
            options: TradeCategory.values
                .map((cat) => TypeOption(
                      value: cat,
                      label: _getCategoryLabel(cat),
                      icon: _getCategoryIcon(cat),
                    ))
                .toList(),
            onSelected: (category) => setState(() => _selectedCategory = category),
            isDark: isDark,
            primaryColor: accent,
            title: 'Category',
            subtitle: 'Pick the closest match',
            layout: SmartTypeSelectorLayout.chips,
          ),
          const SizedBox(height: 20),
          ValidationHighlightBorder(
            highlight: _showValidationHighlight && _mediaDraft.isEmpty,
            message: 'Add at least one photo or a video',
            isDark: isDark,
            child: ListingMediaPicker(
              accentColor: accent,
              title: 'Add photos or a short video',
              moduleLabel: 'trade',
              hidePrimaryCapture: true,
              onChanged: (draft) => setState(() {
                _mediaDraft = draft;
                _clearValidationHighlight();
              }),
              initial: _mediaDraft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep(bool isDark, Color accent) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EnhancedFormField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Condition, what’s included, why you’re trading…',
            isRequired: true,
            maxLines: 5,
            isDark: isDark,
            minLength: 10,
            helperText: 'A short honest story gets better offers',
            showValidationHighlight: _showValidationHighlight,
          ),
          const SizedBox(height: 20),
          SmartTypeSelector<ItemCondition>(
            selectedValue: _selectedCondition,
            options: ItemCondition.values
                .map((cond) => TypeOption(
                      value: cond,
                      label: _getConditionLabel(cond),
                      icon: _getConditionIcon(cond),
                    ))
                .toList(),
            onSelected: (condition) => setState(() => _selectedCondition = condition),
            isDark: isDark,
            primaryColor: accent,
            title: 'Condition',
            layout: SmartTypeSelectorLayout.chips,
          ),
          const SizedBox(height: 20),
          UserFiatBycValueField(
            bycController: _estimatedValueController,
            isDark: isDark,
            primaryColor: accent,
          ),
          const SizedBox(height: 20),
          Text(
            'Location',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          OptionalLocationCard(
            controller: _locationController,
            isDark: isDark,
            primaryColor: accent,
            onLocationRequested: _getCurrentLocation,
            onLocationChanged: (_) => _clearValidationHighlight(),
            required: true,
            showValidationHighlight: _showValidationHighlight,
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesStep(bool isDark, Color accent) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListingCreateSummaryCard(
            title: 'Ready to publish',
            accentColor: accent,
            isDark: isDark,
            rows: [
              ('Title', _titleController.text.trim().isEmpty ? '—' : _titleController.text.trim()),
              ('Category', _getCategoryLabel(_selectedCategory)),
              ('Location', _locationController.text.trim().isEmpty ? '—' : _locationController.text.trim()),
            ],
          ),
          const SizedBox(height: 18),
          PreferenceRadioGroup<DeliveryPreference>(
            selectedValue: _deliveryPreference,
            options: [
              PreferenceOption(
                value: DeliveryPreference.pickupOnly,
                label: 'Pickup only',
                description: 'Meet locally to exchange',
                icon: Icons.location_on_rounded,
              ),
              PreferenceOption(
                value: DeliveryPreference.mixed,
                label: 'Flexible',
                description: 'Pickup or delivery options',
                icon: Icons.local_shipping_rounded,
              ),
            ],
            onChanged: (pref) => setState(() => _deliveryPreference = pref),
            isDark: isDark,
            primaryColor: accent,
            title: 'How should people get this?',
          ),
          const SizedBox(height: 18),
          ListingEditToggleCard(
            isDark: isDark,
            accent: accent,
            icon: Icons.handshake_rounded,
            title: 'Open to negotiation',
            subtitle: 'Allow counter-offers from interested people',
            value: _isNegotiable,
            onChanged: (value) => setState(() => _isNegotiable = value),
          ),
          const SizedBox(height: 12),
          ListingEditToggleCard(
            isDark: isDark,
            accent: accent,
            icon: Icons.star_rounded,
            title: 'Promote with BYC',
            subtitle: 'Feature this trade for 7 days',
            value: _enableBYCPromotion,
            onChanged: (value) => setState(() => _enableBYCPromotion = value),
            highlighted: true,
          ),
        ],
      ),
    );
  }

  String _getCategoryLabel(TradeCategory cat) {
    switch (cat) {
      case TradeCategory.electronics:
        return 'Electronics';
      case TradeCategory.homeGarden:
        return 'Home & Garden';
      case TradeCategory.clothing:
        return 'Clothing';
      case TradeCategory.books:
        return 'Books';
      case TradeCategory.sports:
        return 'Sports';
      case TradeCategory.fashion:
        return 'Fashion';
      case TradeCategory.tools:
        return 'Tools';
      case TradeCategory.automotive:
        return 'Automotive';
      case TradeCategory.collectibles:
        return 'Collectibles';
      case TradeCategory.others:
        return 'Others';
    }
  }

  IconData _getCategoryIcon(TradeCategory cat) {
    switch (cat) {
      case TradeCategory.electronics:
        return Icons.devices_rounded;
      case TradeCategory.homeGarden:
        return Icons.home_rounded;
      case TradeCategory.clothing:
        return Icons.checkroom_rounded;
      case TradeCategory.books:
        return Icons.library_books_rounded;
      case TradeCategory.sports:
        return Icons.sports_soccer_rounded;
      case TradeCategory.fashion:
        return Icons.shopping_bag_rounded;
      case TradeCategory.tools:
        return Icons.build_rounded;
      case TradeCategory.automotive:
        return Icons.directions_car_rounded;
      case TradeCategory.collectibles:
        return Icons.collections_rounded;
      case TradeCategory.others:
        return Icons.category_rounded;
    }
  }

  String _getConditionLabel(ItemCondition cond) {
    switch (cond) {
      case ItemCondition.excellent:
        return 'Excellent';
      case ItemCondition.good:
        return 'Good';
      case ItemCondition.fair:
        return 'Fair';
      default:
        return cond.name.replaceFirst(cond.name[0], cond.name[0].toUpperCase());
    }
  }

  IconData _getConditionIcon(ItemCondition cond) {
    switch (cond) {
      case ItemCondition.excellent:
        return Icons.stars_rounded;
      case ItemCondition.good:
        return Icons.thumb_up_rounded;
      case ItemCondition.fair:
        return Icons.info_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}

enum DeliveryPreference { pickupOnly, mixed }
