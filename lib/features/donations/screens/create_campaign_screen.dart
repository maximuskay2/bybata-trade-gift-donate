import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../models/donation_models.dart';
import '../providers/campaign_provider.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/enhanced_form_field.dart';
import '../../../core/widgets/enhanced_stepper.dart';
import '../../../core/widgets/optional_location_card.dart';
import '../../../core/widgets/smart_type_selector.dart';
import '../../../core/widgets/preference_radio_group.dart';
import '../../../core/utils/image_resize_utils.dart';
import '../../../core/utils/permissions_helper.dart';
import '../../../core/services/location_service.dart';
import '../../../core/widgets/listing_media_picker.dart';
import '../../../core/models/listing_media.dart';
import '../../../core/services/listing_media_upload_service.dart';
import '../../../core/widgets/listing_creation_progress.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../karma/providers/karma_provider.dart';
import '../../storage/repository/storage_repository.dart';
import '../../../core/config/env_config.dart';
import '../../../core/api/api_client.dart';
import '../widgets/campaign_verification_dialog.dart';
import '../../../core/navigation/app_routes.dart';
import 'donations_screen.dart';
import '../../../core/widgets/edit_form_scaffold.dart';
import '../../../core/widgets/editable_listing_media_picker.dart';
import '../../../core/utils/listing_form_validation.dart';
import '../../../core/widgets/validation_highlight_border.dart';
import '../../../core/widgets/listing_create_shell.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CreateCampaignScreen extends StatefulWidget {
  const CreateCampaignScreen({super.key});

  @override
  State<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends State<CreateCampaignScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  Campaign? _existingCampaign;
  bool _isEdit = false;
  bool _isLoading = false;
  bool _showValidationHighlight = false;
  bool _isLocationLoading = false;
  Position? _listingPosition;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _storyController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _minDonationController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _beneficiaryController = TextEditingController();

  CampaignCategory? _selectedCategory;
  DateTime? _selectedDeadline;
  List<String> _selectedTags = [];
  List<String> _uploadedImages = [];
  ListingMediaDraft _mediaDraft = const ListingMediaDraft();
  List<String> _existingMediaKeys = [];
  final List<File> _newLocalImages = [];
  late EditableListingMediaState _editMediaState;
  String? _initialSnapshot;
  String? _videoUrl;
  List<RewardTier> _rewardTiers = [];
  bool _isUrgent = false;
  double? _minimumDonation;
  bool _agreedToCampaignTerms = false;

  final ImagePicker _picker = ImagePicker();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();
    _titleController.addListener(_onFormFieldChanged);
    _storyController.addListener(_onFormFieldChanged);
    _goalController.addListener(_onFormFieldChanged);
    _locationController.addListener(_onFormFieldChanged);
    _beneficiaryController.addListener(_onFormFieldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isEdit) _fillLocationFromDevice();
    });
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

  bool _isStepValid(int step) {
    switch (step) {
      case 0:
        return _titleController.text.trim().isNotEmpty &&
            _locationController.text.trim().isNotEmpty &&
            _selectedCategory != null;
      case 1:
        final story = _storyController.text.trim();
        final goalVal = double.tryParse(_goalController.text.trim());
        return story.isNotEmpty &&
            story.length >= 20 &&
            goalVal != null &&
            goalVal > 0 &&
            _selectedDeadline != null &&
            _selectedCategory != null &&
            !_mediaDraft.isEmpty;
      case 2:
        return _agreedToCampaignTerms;
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
    final story = _storyController.text.trim();
    final goalVal = double.tryParse(_goalController.text.trim());
    return _titleController.text.trim().isNotEmpty &&
        _locationController.text.trim().isNotEmpty &&
        story.isNotEmpty &&
        story.length >= 20 &&
        goalVal != null &&
        goalVal > 0 &&
        _selectedDeadline != null &&
        _selectedCategory != null &&
        _editMediaState.hasMedia;
  }

  void _markDirty() {
    if (mounted) setState(() {});
  }

  String _snapshot() {
    return [
      _titleController.text.trim(),
      _storyController.text.trim(),
      _goalController.text.trim(),
      _locationController.text.trim(),
      _beneficiaryController.text.trim(),
      _selectedCategory?.name ?? '',
      _selectedDeadline?.toIso8601String() ?? '',
      _existingMediaKeys.join('|'),
      _newLocalImages.length,
      _uploadedImages.length,
      _selectedTags.join('|'),
      _isUrgent,
    ].join('::');
  }

  bool get _isDirty =>
      _isEdit && _initialSnapshot != null && _snapshot() != _initialSnapshot;

  bool get _hasPhotos => _isEdit
      ? (_existingMediaKeys.isNotEmpty || _newLocalImages.isNotEmpty)
      : _uploadedImages.isNotEmpty;

  Future<void> _fillLocationFromDevice() async {
    try {
      final status = await LocationService.instance.ensureForFunction(context);
      final granted = status == LocationPermission.always || status == LocationPermission.whileInUse;
      if (!granted) return;
      final position = await LocationService.instance.getCurrentPosition(forceRefresh: true);
      if (position == null || !mounted) return;
      setState(() => _listingPosition = position);
      try {
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;
          final locationName = [place.locality, place.administrativeArea].where((e) => e != null && e.isNotEmpty).join(', ');
          setState(() => _locationController.text = locationName.isNotEmpty ? locationName : 'Current Location');
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Location fetch error: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (_existingCampaign == null && args is Campaign) {
      _existingCampaign = args;
      _isEdit = true;
      _titleController.text = args.title;
      _storyController.text = args.story;
      _goalController.text = args.goalAmount.toStringAsFixed(0);
      _locationController.text = args.location;
      _beneficiaryController.text = args.beneficiaryInfo ?? '';
      _selectedCategory = args.category;
      _selectedDeadline = args.deadline;
      _selectedTags = List<String>.from(args.tags);
      _existingMediaKeys = args.images
          .where((k) => k.isNotEmpty && !_looksLikeLocalDevicePath(k))
          .toList();
      _editMediaState = EditableListingMediaState.fromExisting(args.listingMedia);
      _isUrgent = args.isUrgent;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _initialSnapshot = _snapshot());
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _storyController.dispose();
    _goalController.dispose();
    _minDonationController.dispose();
    _locationController.dispose();
    _beneficiaryController.dispose();
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  bool _validateStep(int step) => _isStepValid(step);

  void _nextStep() {
    if (_validateCurrentStep() && _currentStep < 2) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDeadline = picked;
        _clearValidationHighlight();
      });
    }
  }

  Future<void> _captureCampaignPhoto(void Function(String path) onPath) async {
    if (!await PermissionsHelper.requestCameraWithFallback(context, purpose: 'take photos')) {
      return;
    }
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (file == null || !mounted) return;
    final auth = context.read<AuthProvider>();
    final handle = _watermarkHandle(auth);
    final resized = await ImageResizeUtils.resizeAndWatermark(File(file.path), handle);
    onPath(resized.path);
  }

  void _addImage() async {
    if (_uploadedImages.length >= 5) return;
    await _captureCampaignPhoto((path) {
      if (mounted) setState(() => _uploadedImages.add(path));
    });
  }

  void _removeImage(int index) {
    setState(() => _uploadedImages.removeAt(index));
  }

  int get _imageCount => _isEdit
      ? _existingMediaKeys.length + _newLocalImages.length
      : _uploadedImages.length;

  Future<void> _addImageForEdit() async {
    if (_imageCount >= 5) return;
    await _captureCampaignPhoto((path) {
      _newLocalImages.add(File(path));
      if (mounted) setState(() {});
    });
  }

  String _watermarkHandle(AuthProvider auth) {
    final displayName = auth.currentUser?.displayName;
    final baseName = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : 'bybata';
    return '@${baseName.replaceAll(' ', '').toLowerCase()}';
  }

  Future<List<String>> _prepareMediaKeysForSubmit() async {
    final client = ApiClient(EnvConfig.defaultBaseUrl, const FlutterSecureStorage());
    final storageRepo = StorageRepository(client.dio);
    final keys = <String>[..._existingMediaKeys];

    final pathsToUpload = _isEdit
        ? _newLocalImages.map((f) => f.path).toList()
        : _uploadedImages;

    if (pathsToUpload.isEmpty && keys.isEmpty) return keys;

    for (final path in pathsToUpload) {
      final file = File(path);
      if (!file.existsSync()) {
        if (!_looksLikeLocalDevicePath(path)) {
          keys.add(path);
        }
        continue;
      }

      try {
        final bytes = await file.readAsBytes();
        final lower = path.toLowerCase();
        final isPng = lower.endsWith('.png');
        final isJpg = lower.endsWith('.jpg') || lower.endsWith('.jpeg');
        final ext = isPng ? 'png' : isJpg ? 'jpg' : 'bin';
        final contentType =
            isPng ? 'image/png' : isJpg ? 'image/jpeg' : 'application/octet-stream';

        final meta = await storageRepo.createUploadUrl(
          domain: 'donations',
          ext: ext,
          contentType: contentType,
        );
        final uploadUrl = (meta['uploadUrl'] ?? meta['url'] ?? '') as String;
        final key = (meta['key'] ?? meta['objectKey'] ?? meta['path'] ?? '') as String;

        if (uploadUrl.isNotEmpty && key.isNotEmpty) {
          await storageRepo.uploadToSignedUrl(
            uploadUrl: uploadUrl,
            bytes: bytes,
            contentType: contentType,
          );
          keys.add(key);
        }
      } catch (_) {
        // Try next image; caller validates non-empty result when images were picked.
      }
    }
    return keys;
  }

  Future<void> _saveCampaign() async {
    if (!_isEditFormValid()) {
      _failValidation();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final campaignProvider = Provider.of<CampaignProvider>(context, listen: false);
      final mediaPayload = await ListingMediaUploadService.resolveEditMediaForApi(
        state: _editMediaState,
        domain: 'donations',
      );

      final campaign = await campaignProvider.updateCampaign(
        _existingCampaign!.id,
        title: _titleController.text.trim(),
        description: _storyController.text.trim(),
        shortDescription: _titleController.text.trim().length > 100
            ? '${_titleController.text.trim().substring(0, 100)}...'
            : _titleController.text.trim(),
        category: _selectedCategory,
        goalAmount: double.parse(_goalController.text),
        mediaType: mediaPayload['mediaType'] as String?,
        mediaKeys: (mediaPayload['mediaKeys'] as List?)?.cast<String>(),
        videoKey: mediaPayload['videoKey'] as String?,
        thumbnailKey: mediaPayload['thumbnailKey'] as String?,
        tags: _selectedTags,
        location: _locationController.text.trim(),
        isUrgent: _isUrgent,
        minimumDonation: _minimumDonation,
        endsAt: _selectedDeadline,
        metadata: {
          'beneficiaryInfo': _beneficiaryController.text.trim(),
          if (_videoUrl != null) 'videoUrl': _videoUrl,
        },
      );

      if (!mounted) return;
      if (campaign != null) {
        AppToast.success(context, 'Donation updated');
        Navigator.of(context).pop(true);
      } else {
        AppToast.error(context, campaignProvider.error ?? 'Failed to update campaign');
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _looksLikeLocalDevicePath(String path) {
    if (path.startsWith('file://')) return true;
    if (path.startsWith('/') &&
        (path.contains('/tmp/') ||
            path.contains('image_picker') ||
            path.contains('/Containers/Data/Application'))) {
      return true;
    }
    return false;
  }

  Future<void> _launchCampaign() async {
    for (var step = 0; step <= 2; step++) {
      if (!_isStepValid(step)) {
        await _goToStep(step);
        _failValidation();
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final campaignProvider = Provider.of<CampaignProvider>(context, listen: false);
      final karmaProvider = Provider.of<KarmaProvider>(context, listen: false);

      final campaign = await ListingCreationProgress.run<Campaign>(
        context: context,
        accentColor: AppTheme.donationColor,
        icon: Icons.favorite_rounded,
        title: 'Launching your campaign',
        task: (report) async {
          report(0.05, 'Preparing your campaign…');
          Map<String, dynamic> uploaded = {};
          if (!_mediaDraft.isEmpty) {
            uploaded = await ListingMediaUploadService.uploadDraft(
              draft: _mediaDraft,
              domain: 'donations',
              onProgress: (p, stage) => report(0.05 + p * 0.6, stage),
            );
          }
          final mediaKeys =
              (uploaded['mediaKeys'] as List?)?.cast<String>() ?? <String>[];
          final videoKey = uploaded['videoKey'] as String?;
          if (_mediaDraft.isEmpty ||
              (mediaKeys.isEmpty && (videoKey == null || videoKey.isEmpty))) {
            throw Exception('Failed to upload media. Please try again.');
          }

          final thumbnailKey = uploaded['thumbnailKey'] as String? ??
              (mediaKeys.isNotEmpty ? mediaKeys.first : null);

          report(0.78, 'Publishing your campaign…');
          final created = await campaignProvider.createCampaign(
            title: _titleController.text,
            description: _storyController.text,
            shortDescription: _titleController.text.length > 100
                ? '${_titleController.text.substring(0, 100)}...'
                : _titleController.text,
            category: _selectedCategory!,
            goalAmount: double.parse(_goalController.text),
            currency: 'BYC',
            mediaType: uploaded['mediaType'] as String?,
            mediaKeys: mediaKeys.isEmpty ? null : mediaKeys,
            videoKey: videoKey,
            thumbnailKey: thumbnailKey,
            tags: _selectedTags,
            location: _locationController.text.trim(),
            isUrgent: _isUrgent,
            minimumDonation: _minimumDonation,
            endsAt: _selectedDeadline,
            metadata: {
              'beneficiaryInfo': _beneficiaryController.text,
              'videoUrl': _videoUrl,
              'termsAccepted': _agreedToCampaignTerms,
              'termsAcceptedAt': DateTime.now().toIso8601String(),
              'termsVersion': 'campaign_fee_disclaimer_v1',
            },
            latitude: _listingPosition?.latitude,
            longitude: _listingPosition?.longitude,
          );
          if (created == null) {
            throw Exception(
              campaignProvider.error ?? 'Failed to create campaign',
            );
          }
          report(0.92, 'Finalizing…');
          await karmaProvider.addTransaction(
            75,
            'donation_create',
            'Created donation: ${_titleController.text}',
          );
          await campaignProvider.loadMyCampaigns(force: true);
          report(0.98, 'Campaign launched!');
          return created;
        },
      );

      if (campaign == null) {
        if (!mounted) return;
        AppToast.error(
          context,
          campaignProvider.error ?? 'Failed to create campaign',
        );
        return;
      }

      if (!mounted) return;

      final action = await CampaignVerificationDialog.show(
        context,
        campaignTitle: campaign.title,
      );
      if (!mounted) return;
      if (action == CampaignVerificationAction.openDonationsHub) {
        AppRoutes.replaceWithDonationsHub(context, tabIndex: 1);
      } else {
        AppRoutes.replaceWithDonationsHub(context);
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildEditForm(bool isDark, Color accent) {
    final deadlineBorder = _selectedDeadline == null
        ? (_showValidationHighlight
            ? Colors.red
            : (isDark
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.12)))
        : accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditFormCard(
          title: 'Campaign',
          subtitle: 'Title, place, and cause',
          icon: Icons.volunteer_activism_rounded,
          accentColor: accent,
          child: Column(
            children: [
              EnhancedFormField(
                controller: _titleController,
                label: 'Title',
                hint: 'e.g., Help rebuild after flood',
                isRequired: true,
                isDark: isDark,
                minLength: 5,
                showValidationHighlight: _showValidationHighlight,
              ),
              const SizedBox(height: 16),
              OptionalLocationCard(
                controller: _locationController,
                isDark: isDark,
                primaryColor: accent,
                onLocationRequested: _fillLocationFromDevice,
                onLocationChanged: (_) => _clearValidationHighlight(),
                required: true,
                showValidationHighlight: _showValidationHighlight,
              ),
              const SizedBox(height: 16),
              ValidationHighlightBorder(
                highlight: _showValidationHighlight && _selectedCategory == null,
                message: 'Select a category',
                isDark: isDark,
                child: SmartTypeSelector<CampaignCategory>(
                  selectedValue: _selectedCategory,
                  options: CampaignCategory.values
                      .map((cat) => TypeOption(
                            value: cat,
                            label: _campaignCategoryLabel(cat),
                            icon: _campaignCategoryIcon(cat),
                          ))
                      .toList(),
                  onSelected: (cat) => setState(() {
                    _selectedCategory = cat;
                    _clearValidationHighlight();
                  }),
                  isDark: isDark,
                  primaryColor: accent,
                  title: 'Category',
                  layout: SmartTypeSelectorLayout.chips,
                ),
              ),
              const EditFormDivider(),
              EnhancedFormField(
                controller: _storyController,
                label: 'Story',
                hint: 'Explain the need and impact…',
                isRequired: true,
                maxLines: 5,
                isDark: isDark,
                minLength: 20,
                showValidationHighlight: _showValidationHighlight,
              ),
            ],
          ),
        ),
        EditFormCard(
          title: 'Funding & media',
          subtitle: 'Goal, deadline, and photos',
          icon: Icons.savings_rounded,
          accentColor: accent,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: EnhancedFormField(
                      controller: _goalController,
                      label: 'Goal (BYC)',
                      hint: '1000',
                      keyboardType: TextInputType.number,
                      isRequired: true,
                      isDark: isDark,
                      showValidationHighlight: _showValidationHighlight,
                      validator: (value) {
                        final v = double.tryParse((value ?? '').trim());
                        if (v == null || v <= 0) {
                          return 'Enter a valid goal amount';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ValidationHighlightBorder(
                      highlight:
                          _showValidationHighlight && _selectedDeadline == null,
                      message: 'Select a deadline',
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deadline',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _selectEndDate,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E1E24)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: deadlineBorder,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.event_rounded, size: 18, color: accent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedDeadline == null
                                          ? 'Pick date'
                                          : '${_selectedDeadline!.day}/${_selectedDeadline!.month}/${_selectedDeadline!.year}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const EditFormDivider(),
              ValidationHighlightBorder(
                highlight: _showValidationHighlight && !_editMediaState.hasMedia,
                message: 'Add at least one photo or a video',
                isDark: isDark,
                child: EditableListingMediaPicker(
                  accentColor: accent,
                  compact: true,
                  moduleLabel: 'donation',
                  initialExisting: _existingCampaign!.listingMedia,
                  onChanged: (state) => setState(() {
                    _editMediaState = state;
                    _clearValidationHighlight();
                  }),
                ),
              ),
              const EditFormDivider(),
              EnhancedFormField(
                controller: _beneficiaryController,
                label: 'Beneficiary',
                hint: 'Who receives the donations?',
                maxLines: 3,
                isDark: isDark,
              ),
              const EditFormDivider(),
              ListingEditToggleCard(
                isDark: isDark,
                accent: accent,
                embedded: true,
                icon: Icons.priority_high_rounded,
                title: 'Mark as urgent',
                subtitle: 'Show urgency to donors',
                value: _isUrgent,
                onChanged: (v) => setState(() => _isUrgent = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppTheme.donationColor;

    if (_isEdit) {
      return EditFormScaffold(
        title: 'Edit Donation',
        subtitle: 'Update your story, goal, and campaign photos.',
        accentColor: accent,
        discardItemLabel: 'donation',
        isLoading: _isLoading,
        isDirty: _isDirty,
        onSave: _saveCampaign,
        child: _buildEditForm(isDark, accent),
      );
    }

    return PopScope(
      canPop: Navigator.canPop(context),
      child: ListingCreateShell(
        title: 'Create Campaign',
        accentColor: accent,
        currentStep: _currentStep,
        steps: [
          StepConfig(
            title: 'Basics',
            subtitle: 'Title, place, and category',
            icon: Icons.favorite_outline_rounded,
          ),
          StepConfig(
            title: 'Story & goal',
            subtitle: 'Tell the need, set goal and photos',
            icon: Icons.menu_book_rounded,
          ),
          StepConfig(
            title: 'Launch',
            subtitle: 'Review and agree to terms',
            icon: Icons.rocket_launch_rounded,
          ),
        ],
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: PageView(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _currentStep = page),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildBasicsStep(isDark, accent),
              _buildDetailsStep(isDark, accent),
              _buildReviewStep(isDark, accent),
            ],
          ),
        ),
        onBack: _previousStep,
        onPrimary: _currentStep < 2 ? _nextStep : _launchCampaign,
        primaryLabel: _currentStep < 2 ? 'Continue' : 'Launch Campaign',
        isLoading: _isLoading,
      ),
    );
  }

  String _campaignCategoryLabel(CampaignCategory cat) {
    switch (cat) {
      case CampaignCategory.education:
        return 'Education';
      case CampaignCategory.healthcare:
        return 'Healthcare';
      case CampaignCategory.environment:
        return 'Environment';
      case CampaignCategory.emergency:
        return 'Emergency';
      case CampaignCategory.community:
        return 'Community';
      case CampaignCategory.animal:
        return 'Animals';
      case CampaignCategory.technology:
        return 'Technology';
      case CampaignCategory.art:
        return 'Art';
      case CampaignCategory.sports:
        return 'Sports';
      case CampaignCategory.other:
        return 'Other';
    }
  }

  IconData _campaignCategoryIcon(CampaignCategory cat) {
    switch (cat) {
      case CampaignCategory.education:
        return Icons.school_rounded;
      case CampaignCategory.healthcare:
        return Icons.local_hospital_rounded;
      case CampaignCategory.environment:
        return Icons.eco_rounded;
      case CampaignCategory.emergency:
        return Icons.warning_amber_rounded;
      case CampaignCategory.community:
        return Icons.groups_rounded;
      case CampaignCategory.animal:
        return Icons.pets_rounded;
      case CampaignCategory.technology:
        return Icons.memory_rounded;
      case CampaignCategory.art:
        return Icons.palette_rounded;
      case CampaignCategory.sports:
        return Icons.sports_soccer_rounded;
      case CampaignCategory.other:
        return Icons.category_rounded;
    }
  }

  Widget _buildBasicsStep(bool isDark, Color accent) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListingCreateTipCard(
            text: 'Clear titles and local context help donors trust your campaign faster.',
            accentColor: accent,
            isDark: isDark,
            icon: Icons.volunteer_activism_rounded,
          ),
          const SizedBox(height: 18),
          EnhancedFormField(
            controller: _titleController,
            label: 'Campaign Title',
            hint: 'e.g., Help rebuild after flood',
            isRequired: true,
            isDark: isDark,
            minLength: 5,
            helperText: 'Make it clear and compelling',
            showValidationHighlight: _showValidationHighlight,
          ),
          const SizedBox(height: 20),
          Text('Location', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          OptionalLocationCard(
            controller: _locationController,
            isDark: isDark,
            primaryColor: accent,
            onLocationRequested: _fillLocationFromDevice,
            onLocationChanged: (_) => _clearValidationHighlight(),
            required: true,
            showValidationHighlight: _showValidationHighlight,
          ),
          const SizedBox(height: 20),
          ValidationHighlightBorder(
            highlight: _showValidationHighlight && _selectedCategory == null,
            message: 'Select a category',
            isDark: isDark,
            child: SmartTypeSelector<CampaignCategory>(
              selectedValue: _selectedCategory,
              options: CampaignCategory.values
                  .map((cat) => TypeOption(value: cat, label: _campaignCategoryLabel(cat), icon: _campaignCategoryIcon(cat)))
                  .toList(),
              onSelected: (cat) => setState(() {
                _selectedCategory = cat;
                _clearValidationHighlight();
              }),
              isDark: isDark,
              primaryColor: accent,
              title: 'Category',
              subtitle: 'Choose the closest cause',
              layout: SmartTypeSelectorLayout.chips,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep(bool isDark, Color accent) {
    final deadlineBorder = _selectedDeadline == null
        ? (_showValidationHighlight
            ? Colors.red
            : (isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.12)))
        : accent;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EnhancedFormField(
            controller: _storyController,
            label: 'Campaign Story',
            hint: 'Explain the need and the impact donations will make…',
            isRequired: true,
            maxLines: 5,
            isDark: isDark,
            minLength: 20,
            helperText: 'Honest detail builds donor confidence',
            showValidationHighlight: _showValidationHighlight,
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: EnhancedFormField(
                  controller: _goalController,
                  label: 'Goal (BYC)',
                  hint: '1000',
                  keyboardType: TextInputType.number,
                  isRequired: true,
                  isDark: isDark,
                  helperText: 'Target amount',
                  showValidationHighlight: _showValidationHighlight,
                  validator: (value) {
                    final v = double.tryParse((value ?? '').trim());
                    if (v == null || v <= 0) return 'Enter a valid goal amount';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ValidationHighlightBorder(
                  highlight: _showValidationHighlight && _selectedDeadline == null,
                  message: 'Select a deadline',
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Deadline', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _selectEndDate,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: deadlineBorder, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.event_rounded, size: 18, color: accent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedDeadline == null
                                      ? 'Pick end date'
                                      : '${_selectedDeadline!.day}/${_selectedDeadline!.month}/${_selectedDeadline!.year}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ValidationHighlightBorder(
            highlight: _showValidationHighlight && _mediaDraft.isEmpty,
            message: 'Add at least one photo or a video',
            isDark: isDark,
            child: ListingMediaPicker(
              accentColor: accent,
              title: 'Add photos to your campaign',
              moduleLabel: 'donation',
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

  Widget _buildReviewStep(bool isDark, Color accent) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListingCreateSummaryCard(
            title: 'Launch summary',
            accentColor: accent,
            isDark: isDark,
            rows: [
              ('Title', _titleController.text.trim().isEmpty ? '—' : _titleController.text.trim()),
              ('Category', _selectedCategory == null ? '—' : _campaignCategoryLabel(_selectedCategory!)),
              ('Goal', _goalController.text.trim().isEmpty ? '—' : '${_goalController.text.trim()} BYC'),
              (
                'Deadline',
                _selectedDeadline == null
                    ? '—'
                    : '${_selectedDeadline!.day}/${_selectedDeadline!.month}/${_selectedDeadline!.year}',
              ),
              ('Location', _locationController.text.trim().isEmpty ? '—' : _locationController.text.trim()),
            ],
          ),
          const SizedBox(height: 16),
          EnhancedFormField(
            controller: _beneficiaryController,
            label: 'Beneficiary Info',
            hint: 'Who will receive the donations?',
            maxLines: 3,
            isDark: isDark,
            helperText: 'Optional but recommended',
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.priority_high_rounded, color: accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mark as urgent', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                      Text('Get priority visibility for critical needs', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600])),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _isUrgent,
                  onChanged: (value) => setState(() => _isUrgent = value),
                  activeColor: accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ListingCreateTipCard(
            text: 'You’ll earn +75 KARMA for creating this campaign.',
            accentColor: accent,
            isDark: isDark,
            icon: Icons.stars_rounded,
          ),
          const SizedBox(height: 16),
          ValidationHighlightBorder(
            highlight: _showValidationHighlight && !_agreedToCampaignTerms,
            message: 'Please agree to the campaign terms',
            isDark: isDark,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _agreedToCampaignTerms
                      ? accent.withValues(alpha: 0.35)
                      : (_showValidationHighlight ? Colors.red : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08))),
                  width: _showValidationHighlight && !_agreedToCampaignTerms ? 2 : 1.2,
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.gavel_rounded, color: accent, size: 20),
                      const SizedBox(width: 8),
                      Text('Campaign terms', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "A 15% platform fee supports Bybata operations. Donations are made in goodwill with no guaranteed outcomes.",
                    style: TextStyle(fontSize: 12.5, height: 1.45, color: isDark ? Colors.grey[300] : Colors.grey[800]),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => setState(() {
                      _agreedToCampaignTerms = !_agreedToCampaignTerms;
                      _clearValidationHighlight();
                    }),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _agreedToCampaignTerms,
                          activeColor: accent,
                          onChanged: (value) => setState(() {
                            _agreedToCampaignTerms = value ?? false;
                            _clearValidationHighlight();
                          }),
                        ),
                        Expanded(
                          child: Text(
                            'I agree to the campaign terms',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
