import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/gift_models.dart';
import '../providers/gift_provider.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/enhanced_form_field.dart';
import '../../../core/widgets/enhanced_stepper.dart';
import '../../../core/widgets/optional_location_card.dart';
import '../../../core/widgets/smart_type_selector.dart';
import '../../../core/widgets/preference_radio_group.dart';
import '../../storage/repository/storage_repository.dart';
import '../../../core/config/env_config.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/permissions_helper.dart';
import '../../../core/services/location_service.dart';
import '../../../core/widgets/listing_media_picker.dart';
import '../../../core/models/listing_media.dart';
import '../../../core/services/listing_media_upload_service.dart';
import '../../../core/widgets/listing_creation_progress.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/services/listing_seeding_context.dart';
import '../../../core/motion/publish_finale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_resize_utils.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/edit_form_scaffold.dart';
import '../../../core/widgets/editable_listing_media_picker.dart';
import '../../../core/karma/karma_points_config.dart';
import '../../../core/utils/listing_form_validation.dart';
import '../../../core/widgets/validation_highlight_border.dart';
import '../../../core/widgets/listing_create_shell.dart';
import '../../karma/services/karma_api_service.dart';

class CreateGiftScreen extends StatefulWidget {
  final Gift? initialGift;
  final String? chainParentId;
  const CreateGiftScreen({super.key, this.initialGift, this.chainParentId});

  @override
  State<CreateGiftScreen> createState() => _CreateGiftScreenState();
}

class _CreateGiftScreenState extends State<CreateGiftScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;
  bool _showValidationHighlight = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _skillLevelController = TextEditingController(); 
  final TextEditingController _sessionDurationController = TextEditingController();
  final TextEditingController _experienceDateController = TextEditingController();
  final TextEditingController _maxParticipantsController = TextEditingController();
  final TextEditingController _digitalUrlController = TextEditingController();
  final TextEditingController _digitalAccessCodeController = TextEditingController();

  GiftType _selectedType = GiftType.random;
  GiftCategory _selectedCategory = GiftCategory.others;
  List<String> _existingMediaKeys = [];
  final List<File> _selectedImages = [];
  ListingMediaDraft _mediaDraft = const ListingMediaDraft();
  late EditableListingMediaState _editMediaState;
  List<String> _tags = [];
  String? _initialSnapshot;
  int _karmaReward = KarmaPointsConfig.defaults.giftDefaultReward;
  int _giftRewardMin = KarmaPointsConfig.defaults.giftRewardMin;
  int _giftRewardMax = KarmaPointsConfig.defaults.giftRewardMax;
  KarmaLevel? _minimumKarmaLevel;
  int _maxClaims = 1;
  DateTime? _expiresAt;
  bool _isLocationRestricted = false;
  bool _isChainGift = false;
  String? _chainParentId;
  
  String? _skillLevel;
  int? _sessionDuration; 
  DateTime? _experienceDate;
  int? _maxParticipants;

  bool _isLocationLoading = false;
  bool _locationEnabled = true;
  String? _currentLocation;
  Position? _currentPosition;

  final ImagePicker _picker = ImagePicker();
  StorageRepository? _storage;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool get _isEdit => widget.initialGift != null;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
    _initializeStorage();
    _loadKarmaPointsConfig();
    if (!_isEdit) {
      _getCurrentLocation();
    }
    _loadInitialGift();
    _titleController.addListener(_onFormFieldChanged);
    _descriptionController.addListener(_onFormFieldChanged);
    _locationController.addListener(_onFormFieldChanged);
    _skillLevelController.addListener(_onFormFieldChanged);
    _sessionDurationController.addListener(_onFormFieldChanged);
    _experienceDateController.addListener(_onFormFieldChanged);
    _maxParticipantsController.addListener(_onFormFieldChanged);
    _digitalUrlController.addListener(_onFormFieldChanged);
  }

  void _onFormFieldChanged() {
    _clearValidationHighlight();
    _markDirty();
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

  bool _isTypeFieldsValid() {
    if (_selectedType == GiftType.skill) {
      final skill = _skillLevel ?? _skillLevelController.text.trim();
      final duration =
          _sessionDuration ?? int.tryParse(_sessionDurationController.text.trim());
      return skill.isNotEmpty && duration != null && duration > 0;
    }
    if (_selectedType == GiftType.experience) {
      final participants = _maxParticipants ??
          int.tryParse(_maxParticipantsController.text.trim());
      final hasDate = _experienceDate != null ||
          _experienceDateController.text.trim().isNotEmpty;
      return hasDate && participants != null && participants > 0;
    }
    if (_selectedType == GiftType.digital) {
      return _digitalUrlController.text.trim().isNotEmpty;
    }
    return true;
  }

  bool _isStepValid(int step) {
    switch (step) {
      case 0:
        return _titleController.text.trim().isNotEmpty &&
            _descriptionController.text.trim().isNotEmpty &&
            !_mediaDraft.isEmpty;
      case 1:
        return _isTypeFieldsValid() &&
            _locationController.text.trim().isNotEmpty;
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
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool _isEditFormValid() {
    return _titleController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty &&
        _editMediaState.hasMedia &&
        _locationController.text.trim().isNotEmpty;
  }

  Future<void> _loadKarmaPointsConfig() async {
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = KarmaApiService(
        ApiClient(baseUrl, FlutterSecureStorage()),
      );
      final res = await api.getPointsConfig();
      KarmaPointsConfigCache.instance.update(res.points);
      if (!mounted) return;
      setState(() {
        _giftRewardMin = res.points.giftRewardMin;
        _giftRewardMax = res.points.giftRewardMax;
        if (!_isEdit) {
          _karmaReward = res.points.giftDefaultReward;
        } else {
          _karmaReward = res.points.clampGiftReward(_karmaReward);
        }
      });
    } catch (_) {
      // Keep local defaults
    }
  }

  void _markDirty() {
    if (mounted) setState(() {});
  }

  String _snapshot() {
    return [
      _titleController.text.trim(),
      _descriptionController.text.trim(),
      _selectedType.name,
      _selectedCategory.name,
      _karmaReward,
      _maxClaims,
      _locationController.text.trim(),
      _existingMediaKeys.join('|'),
      _selectedImages.length,
      _tags.join('|'),
    ].join('::');
  }

  bool get _isDirty =>
      _isEdit && _initialSnapshot != null && _snapshot() != _initialSnapshot;

  void _loadInitialGift() {
    if (widget.chainParentId != null) {
      setState(() {
        _isChainGift = true;
        _chainParentId = widget.chainParentId;
      });
    }
    if (widget.initialGift != null) {
      final gift = widget.initialGift!;
      _titleController.text = gift.title;
      _descriptionController.text = gift.description;
      _selectedType = gift.type;
      _selectedCategory = gift.category;
      _karmaReward = gift.karmaReward;
      _maxClaims = gift.maxClaims;
      if (gift.location != null) _locationController.text = gift.location!;
      _tags = List<String>.from(gift.tags);
      _existingMediaKeys = List<String>.from(gift.imageUrls);
      _editMediaState = EditableListingMediaState.fromExisting(gift.listingMedia);
      _expiresAt = gift.expiresAt;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _initialSnapshot = _snapshot());
        }
      });
    }
  }

  Future<void> _initializeStorage() async {
    try {
      final base = await EnvConfig.getBaseUrl();
      final storage = FlutterSecureStorage();
      final client = ApiClient(base, storage);
      _storage = StorageRepository(client.dio);
    } catch (e) {
      debugPrint('Failed to initialize storage: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!_locationEnabled) return;
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
          final locationName = [place.locality, place.administrativeArea].where((e) => e != null && e.isNotEmpty).join(', ');
          setState(() {
            _currentLocation = locationName.isNotEmpty ? locationName : 'Current Location';
            _locationController.text = _currentLocation ?? '';
            _isLocationLoading = false;
          });
        }
      } catch (_) {
        setState(() { _currentLocation = 'Current Location'; _locationController.text = _currentLocation ?? ''; _isLocationLoading = false; });
      }
    } catch (e) {
      setState(() { _isLocationLoading = false; _locationEnabled = false; });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _skillLevelController.dispose();
    _sessionDurationController.dispose();
    _experienceDateController.dispose();
    _maxParticipantsController.dispose();
    _digitalUrlController.dispose();
    _digitalAccessCodeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  bool get _hasPhotos =>
      _existingMediaKeys.isNotEmpty || _selectedImages.isNotEmpty;

  bool _validateStep(int step) => _isStepValid(step);

  bool _validateEdit() => _isEditFormValid();

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

  void _nextStep() {
    if (_validateCurrentStep() && _currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _takeGiftPhoto() async {
    if (_selectedImages.length >= 5) {
      AppToast.error(context, 'Maximum 5 images');
      return;
    }
    if (!await PermissionsHelper.requestCameraWithFallback(context, purpose: 'take photos')) {
      return;
    }
    await _pickImage(ImageSource.camera);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 90);
      if (image != null && _selectedImages.length < 5) {
        if (!mounted) return;
        final auth = context.read<AuthProvider>();
        final user = auth.currentUser;
        final displayName = user?.displayName;
        final email = user?.email;
        final baseName = (displayName != null && displayName.trim().isNotEmpty) ? displayName.trim() : (email != null && email.isNotEmpty ? email.split('@').first : 'bybata');
        final handle = '@${baseName.replaceAll(' ', '').toLowerCase()}';
        final resized = await ImageResizeUtils.resizeAndWatermark(File(image.path), handle);
        if (!mounted) return;
        setState(() => _selectedImages.add(resized));
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Failed to pick image: $e');
    }
  }

  void _removeImage(int index) => setState(() => _selectedImages.removeAt(index));

  Future<List<String>> _uploadNewImages() async {
    final mediaKeys = <String>[..._existingMediaKeys];
    if (_selectedImages.isEmpty || _storage == null) return mediaKeys;

    for (final imageFile in _selectedImages) {
      try {
        if (!imageFile.existsSync()) continue;
        final bytes = await imageFile.readAsBytes();
        final ext = imageFile.path.split('.').last.toLowerCase();
        final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
        final up = await _storage!.createUploadUrl(
          domain: 'gifts',
          ext: ext,
          contentType: contentType,
        );
        await _storage!.uploadToSignedUrl(
          uploadUrl: up['uploadUrl'] as String,
          bytes: bytes,
          contentType: contentType,
        );
        mediaKeys.add(up['key'] as String);
      } catch (e) {
        debugPrint('Failed to upload: $e');
      }
    }
    return mediaKeys;
  }

  Future<void> _submitGift() async {
    if (_isEdit) {
      if (!_isEditFormValid()) {
        _failValidation();
        return;
      }
    } else {
      for (var step = 0; step <= 1; step++) {
        if (!_isStepValid(step)) {
          await _goToStep(step);
          _failValidation();
          return;
        }
      }
    }

    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<GiftProvider>(context, listen: false);

      if (_isEdit) {
        final mediaPayload = await ListingMediaUploadService.resolveEditMediaForApi(
          state: _editMediaState,
          domain: 'gifts',
        );

        final updated = await provider.updateGift(
          widget.initialGift!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          mediaType: mediaPayload['mediaType'] as String?,
          mediaKeys: (mediaPayload['mediaKeys'] as List?)?.cast<String>(),
          videoKey: mediaPayload['videoKey'] as String?,
          thumbnailKey: mediaPayload['thumbnailKey'] as String?,
          karmaReward: _karmaReward,
          maxClaims: _maxClaims,
          location: _locationController.text.trim(),
          tags: _tags.isEmpty ? null : _tags,
          expiresAt: _expiresAt,
        );

        if (updated != null && mounted) {
          AppToast.success(context, 'Gift updated');
          Navigator.of(context).pop(true);
        } else if (mounted) {
          AppToast.error(context, provider.error ?? 'Failed to update gift');
        }
        return;
      }

      final gift = await ListingCreationProgress.run<Gift>(
        context: context,
        accentColor: AppTheme.giftColor,
        icon: Icons.volunteer_activism_rounded,
        title: 'Creating your gift',
        task: (report) async {
          report(0.05, 'Preparing your gift…');
          Map<String, dynamic> uploaded = {};
          if (!_mediaDraft.isEmpty) {
            uploaded = await ListingMediaUploadService.uploadDraft(
              draft: _mediaDraft,
              domain: 'gifts',
              onProgress: (p, stage) => report(0.05 + p * 0.65, stage),
            );
          }

          Map<String, dynamic> metadata = {};
          if (_selectedType == GiftType.skill) {
            metadata['skillLevel'] = _skillLevel;
            metadata['sessionDuration'] = _sessionDuration;
          } else if (_selectedType == GiftType.experience) {
            metadata['experienceDate'] = _experienceDate?.toIso8601String();
            metadata['maxParticipants'] = _maxParticipants;
          } else if (_selectedType == GiftType.digital) {
            metadata['digitalUrl'] = _digitalUrlController.text.trim();
            metadata['accessCode'] = _digitalAccessCodeController.text.trim();
          }

          final isSeedingListing = ListingSeedingContext.consumeGiftSeed();
          report(0.82, 'Publishing your gift…');

          final created = await provider.createGift(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            type: _selectedType,
            category: _selectedCategory,
            mediaType: uploaded['mediaType'] as String?,
            mediaKeys: (uploaded['mediaKeys'] as List?)?.cast<String>(),
            videoKey: uploaded['videoKey'] as String?,
            thumbnailKey: uploaded['thumbnailKey'] as String?,
            karmaReward: _karmaReward,
            maxClaims: _maxClaims,
            location: _locationController.text.trim(),
            isLocationRestricted: _isLocationRestricted,
            isChainGift: _isChainGift,
            chainParentId: _chainParentId,
            minimumKarmaLevel: _minimumKarmaLevel,
            tags: _tags.isEmpty ? null : _tags,
            metadata: metadata.isEmpty ? null : metadata,
            latitude: _currentPosition?.latitude,
            longitude: _currentPosition?.longitude,
            expiresAt: _expiresAt,
            isSeedingListing: isSeedingListing,
          );
          if (created == null) {
            throw Exception(provider.error ?? 'Failed to create gift');
          }
          report(0.96, 'Gift created!');
          return created;
        },
      );

      if (gift != null && mounted) {
        if (!_isEdit) {
          await showPublishFinale(
            context,
            line: 'Listed',
            color: AppTheme.giftColor,
            imagePath: _mediaDraft.heroPath,
          );
        }
        if (!mounted) return;
        AppRoutes.replaceWithGiftHub(context, createdGiftId: gift.id);
      } else if (mounted) {
        AppToast.error(context, provider.error ?? 'Failed to create gift');
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'An error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildEditForm(bool isDark, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditFormCard(
          title: 'Your gift',
          subtitle: 'Photos and what you are sharing',
          icon: Icons.card_giftcard_rounded,
          accentColor: accent,
          child: Column(
            children: [
              ValidationHighlightBorder(
                highlight: _showValidationHighlight && !_editMediaState.hasMedia,
                message: 'Add at least one photo or a video',
                isDark: isDark,
                child: EditableListingMediaPicker(
                  accentColor: accent,
                  compact: true,
                  moduleLabel: 'gift',
                  initialExisting: widget.initialGift!.listingMedia,
                  onChanged: (state) => setState(() {
                    _editMediaState = state;
                    _clearValidationHighlight();
                  }),
                ),
              ),
              const EditFormDivider(),
              EnhancedFormField(
                controller: _titleController,
                label: 'Title',
                hint: 'e.g., Photography workshop',
                isRequired: true,
                isDark: isDark,
                minLength: 3,
                showValidationHighlight: _showValidationHighlight,
              ),
              const SizedBox(height: 14),
              ListingEditLockedChipsRow(
                accent: accent,
                isDark: isDark,
                items: [
                  ('Type', _giftTypeLabel(_selectedType), Icons.card_giftcard_rounded),
                  ('Category', _selectedCategory.label, _selectedCategory.icon),
                ],
              ),
              const EditFormDivider(),
              EnhancedFormField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Describe the gift…',
                isRequired: true,
                maxLines: 4,
                isDark: isDark,
                minLength: 10,
                showValidationHighlight: _showValidationHighlight,
              ),
            ],
          ),
        ),
        EditFormCard(
          title: 'Location & rewards',
          subtitle: 'Where to meet and karma settings',
          icon: Icons.place_rounded,
          accentColor: accent,
          child: Column(
            children: [
              OptionalLocationCard(
                controller: _locationController,
                isDark: isDark,
                primaryColor: accent,
                onLocationRequested: _getCurrentLocation,
                onLocationChanged: (_) => _clearValidationHighlight(),
                required: true,
                showValidationHighlight: _showValidationHighlight,
              ),
              const EditFormDivider(),
              EditFormKarmaBlock(
                accent: accent,
                isDark: isDark,
                karmaReward: _karmaReward,
                karmaMin: _giftRewardMin,
                karmaMax: _giftRewardMax,
                maxClaims: _maxClaims,
                onKarmaChanged: (v) => setState(
                  () => _karmaReward = v.clamp(_giftRewardMin, _giftRewardMax),
                ),
                onMaxClaimsChanged: (v) => setState(() => _maxClaims = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isEdit
        ? Theme.of(context).brightness == Brightness.dark
        : false;
    final accent = AppTheme.giftColor;

    if (_isEdit) {
      return EditFormScaffold(
        title: 'Edit Gift',
        subtitle: 'Refresh photos, location, and rewards for your gift.',
        accentColor: accent,
        discardItemLabel: 'gift',
        isLoading: _isLoading,
        isDirty: _isDirty,
        onSave: _submitGift,
        swipeCommitLabel: 'Save Gift',
        onSwipeCommit: _submitGift,
        child: _buildEditForm(isDark, accent),
      );
    }

    return ListingCreateShell(
      title: 'Create Gift',
      accentColor: accent,
      currentStep: _currentStep,
      steps: [
        StepConfig(
          title: 'Gift basics',
          subtitle: 'Title, type, story, and photos',
          icon: Icons.card_giftcard_rounded,
        ),
        StepConfig(
          title: 'Details',
          subtitle: 'Category, extras, and location',
          icon: Icons.tune_rounded,
        ),
        StepConfig(
          title: 'Review',
          subtitle: 'Check everything before posting',
          icon: Icons.check_circle_outline,
        ),
      ],
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: PageView(
          controller: _pageController,
          onPageChanged: (page) => setState(() => _currentStep = page),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildInfoStep(isDark, accent),
            _buildDetailsStep(isDark, accent),
            _buildReviewStep(isDark, accent),
          ],
        ),
      ),
      onBack: _previousStep,
      onPrimary: _currentStep < 2 ? _openReview : _submitGift,
      primaryLabel: _currentStep < 2 ? 'Review' : 'Post Gift',
      chapterCaption: '${_currentStep + 1} of 3 · ${[
        'Gift basics',
        'Details',
        'Review',
      ][_currentStep]}',
      swipeCommitLabel: _currentStep < 2 ? null : 'Post Gift',
      onSwipeCommit: _currentStep < 2 ? null : _submitGift,
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
      accentColor: AppTheme.giftColor,
      title: 'Add photos to your gift',
    );
    if (!mounted || next == null) return;
    setState(() {
      _mediaDraft = next;
      _clearValidationHighlight();
    });
  }

  Widget _buildInfoStep(bool isDark, Color accent) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListingCreateTipCard(
            text: 'Generous gifts with clear photos get claimed faster and build more trust.',
            accentColor: accent,
            isDark: isDark,
            icon: Icons.volunteer_activism_rounded,
          ),
          const SizedBox(height: 18),
          EnhancedFormField(
            controller: _titleController,
            label: 'Gift Title',
            hint: 'e.g., Photography Workshop',
            isRequired: true,
            isDark: isDark,
            minLength: 3,
            helperText: 'Keep it warm and specific',
            showValidationHighlight: _showValidationHighlight,
          ),
          const SizedBox(height: 20),
          SmartTypeSelector<GiftType>(
            selectedValue: _selectedType,
            options: [
              TypeOption(value: GiftType.random, label: 'Random Gift', icon: Icons.card_giftcard_rounded),
              TypeOption(value: GiftType.skill, label: 'Skill', icon: Icons.school_rounded),
              TypeOption(value: GiftType.experience, label: 'Experience', icon: Icons.travel_explore_rounded),
              TypeOption(value: GiftType.digital, label: 'Digital', icon: Icons.cloud_rounded),
              TypeOption(value: GiftType.targeted, label: 'Targeted', icon: Icons.person_rounded),
            ],
            onSelected: (t) => setState(() => _selectedType = t),
            isDark: isDark,
            primaryColor: accent,
            title: 'Gift type',
            subtitle: 'This unlocks the right details next',
            layout: SmartTypeSelectorLayout.chips,
          ),
          const SizedBox(height: 20),
          EnhancedFormField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'What are you giving, and what should people know?',
            isRequired: true,
            maxLines: 4,
            isDark: isDark,
            minLength: 10,
            showValidationHighlight: _showValidationHighlight,
          ),
          const SizedBox(height: 20),
          ValidationHighlightBorder(
            highlight: _showValidationHighlight && _mediaDraft.isEmpty,
            message: 'Add at least one photo or a video',
            isDark: isDark,
            child: ListingMediaPicker(
              accentColor: accent,
              title: 'Add photos to your gift',
              moduleLabel: 'gift',
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
          SmartTypeSelector<GiftCategory>(
            selectedValue: _selectedCategory,
            options: GiftCategory.values
                .map((cat) => TypeOption(value: cat, label: cat.label, icon: cat.icon))
                .toList(),
            onSelected: (cat) => setState(() => _selectedCategory = cat),
            isDark: isDark,
            primaryColor: accent,
            title: 'Category',
            subtitle: 'Helps the right people discover this gift',
            layout: SmartTypeSelectorLayout.chips,
          ),
          const SizedBox(height: 20),
          if (_selectedType == GiftType.skill) ...[
            EnhancedFormField(
              controller: _skillLevelController,
              label: 'Skill Level',
              hint: 'e.g., Beginner',
              isRequired: true,
              isDark: isDark,
              showValidationHighlight: _showValidationHighlight,
              onChanged: () => setState(() => _skillLevel = _skillLevelController.text),
            ),
            const SizedBox(height: 12),
            EnhancedFormField(
              controller: _sessionDurationController,
              label: 'Session Duration (mins)',
              hint: '60',
              keyboardType: TextInputType.number,
              isRequired: true,
              isDark: isDark,
              showValidationHighlight: _showValidationHighlight,
              validator: (value) {
                final n = int.tryParse((value ?? '').trim());
                if (n == null || n <= 0) return 'Enter a valid duration';
                return null;
              },
              onChanged: () => setState(() => _sessionDuration = int.tryParse(_sessionDurationController.text)),
            ),
          ] else if (_selectedType == GiftType.experience) ...[
            GestureDetector(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _experienceDate ?? now.add(const Duration(days: 3)),
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365)),
                );
                if (picked == null || !mounted) return;
                setState(() {
                  _experienceDate = picked;
                  _experienceDateController.text = '${picked.day}/${picked.month}/${picked.year}';
                  _clearValidationHighlight();
                });
              },
              child: AbsorbPointer(
                child: EnhancedFormField(
                  controller: _experienceDateController,
                  label: 'Experience Date',
                  hint: 'Tap to pick a date',
                  isRequired: true,
                  isDark: isDark,
                  showValidationHighlight: _showValidationHighlight,
                ),
              ),
            ),
            const SizedBox(height: 12),
            EnhancedFormField(
              controller: _maxParticipantsController,
              label: 'Max Participants',
              hint: '5',
              keyboardType: TextInputType.number,
              isRequired: true,
              isDark: isDark,
              showValidationHighlight: _showValidationHighlight,
              validator: (value) {
                final n = int.tryParse((value ?? '').trim());
                if (n == null || n <= 0) return 'Enter a valid number';
                return null;
              },
              onChanged: () => setState(() => _maxParticipants = int.tryParse(_maxParticipantsController.text)),
            ),
          ] else if (_selectedType == GiftType.digital) ...[
            EnhancedFormField(
              controller: _digitalUrlController,
              label: 'Gift URL',
              hint: 'https://...',
              isRequired: true,
              isDark: isDark,
              showValidationHighlight: _showValidationHighlight,
            ),
            const SizedBox(height: 12),
            EnhancedFormField(
              controller: _digitalAccessCodeController,
              label: 'Access Code (if any)',
              hint: 'Optional',
              isDark: isDark,
            ),
          ],
          const SizedBox(height: 20),
          Text('Location', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
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

  Widget _buildReviewStep(bool isDark, Color accent) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListingCreateSummaryCard(
            title: 'Gift summary',
            accentColor: accent,
            isDark: isDark,
            rows: [
              ('Title', _titleController.text.trim().isEmpty ? '—' : _titleController.text.trim()),
              ('Type', _giftTypeLabel(_selectedType)),
              ('Category', _selectedCategory.label),
              ('Location', _locationController.text.trim().isEmpty ? '—' : _locationController.text.trim()),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Karma reward', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('$_karmaReward', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: accent)),
                    const SizedBox(width: 8),
                    Text('KARMA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: accent.withValues(alpha: 0.85))),
                    const Spacer(),
                    Icon(Icons.stars_rounded, color: accent, size: 28),
                  ],
                ),
                if (_giftRewardMax > _giftRewardMin)
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(activeTrackColor: accent, thumbColor: accent, inactiveTrackColor: accent.withValues(alpha: 0.2)),
                    child: Slider(
                      value: _karmaReward.toDouble().clamp(_giftRewardMin.toDouble(), _giftRewardMax.toDouble()),
                      min: _giftRewardMin.toDouble(),
                      max: _giftRewardMax.toDouble(),
                      divisions: (_giftRewardMax - _giftRewardMin).clamp(1, 100),
                      onChanged: (v) => setState(() => _karmaReward = v.round()),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Fixed at $_giftRewardMin KARMA per gift claim',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                    ),
                  ),
                Text('Max claims: $_maxClaims', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(activeTrackColor: accent, thumbColor: accent, inactiveTrackColor: accent.withValues(alpha: 0.2)),
                  child: Slider(
                    value: _maxClaims.toDouble().clamp(1, 20),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: '$_maxClaims',
                    onChanged: (v) => setState(() => _maxClaims = v.round()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ListingCreateTipCard(
            text: 'Fair karma rewards encourage good community behavior and help your gift stand out.',
            accentColor: accent,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  String _giftTypeLabel(GiftType type) {
    switch (type) {
      case GiftType.random:
        return 'Random Gift';
      case GiftType.skill:
        return 'Skill';
      case GiftType.experience:
        return 'Experience';
      case GiftType.digital:
        return 'Digital';
      case GiftType.targeted:
        return 'Targeted';
    }
  }
}
