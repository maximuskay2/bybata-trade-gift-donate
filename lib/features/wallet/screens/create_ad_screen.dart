import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../../../core/widgets/enhanced_form_field.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../storage/repository/storage_repository.dart';
import '../services/wallet_service.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/utils/image_resize_utils.dart';
import '../../../core/utils/permissions_helper.dart';
import '../../../core/widgets/image_source_picker_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/ad_placement_keys.dart';
import '../../../core/utils/destination_url_utils.dart';
import '../utils/promotion_error_handler.dart';
import 'package:uuid/uuid.dart';

class CreateAdScreen extends StatefulWidget {
  const CreateAdScreen({super.key});

  @override
  State<CreateAdScreen> createState() => _CreateAdScreenState();
}

class _CreateAdScreenState extends State<CreateAdScreen> {
  final WalletService _walletService = WalletService();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();

  DateTime _start = DateTime.now().add(const Duration(minutes: 15));
  int _durationDays = 7;
  bool _isUploading = false;
  String? _submitIdempotencyKey;
  String _mediaMode = 'IMAGE';
  final List<String> _mediaPaths = [];
  String? _videoPath;
  List<Map<String, dynamic>> _placements = [];
  final Set<String> _selectedPlacementKeys = {};

  Map<String, double> _adPricing = const {
    'tradeBycPerDay': 2.5,
    'giftBycPerDay': 2,
    'donationBycPerDay': 2,
    'normalBycPerDay': 3,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initWallet());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  double _dailyRateForKey(String key) {
    final k = key.toLowerCase();
    if (k.contains('trade')) return _adPricing['tradeBycPerDay'] ?? 2.5;
    if (k.contains('gift')) return _adPricing['giftBycPerDay'] ?? 2;
    if (k.contains('donation') || k.contains('campaign')) {
      return _adPricing['donationBycPerDay'] ?? 2;
    }
    return _adPricing['normalBycPerDay'] ?? 3;
  }

  double get _computedTotal {
    if (_selectedPlacementKeys.isEmpty) return 0;
    return _selectedPlacementKeys.fold<double>(
      0,
      (sum, key) => sum + _dailyRateForKey(key) * _durationDays,
    );
  }

  Future<void> _initWallet() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.id ?? '';
    if (!_walletService.isInitialized && userId.isNotEmpty) {
      await _walletService.initializeWallet(userId);
    }
    await _loadPlacements();
  }

  Future<void> _loadPlacements() async {
    try {
      final config = await _walletService.fetchBoostConfig();
      final placements = (config?['placements'] as List?) ?? [];
      final pricingRaw = config?['adPricing'];
      if (!mounted) return;
      setState(() {
        _placements = placements.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (pricingRaw is Map) {
          _adPricing = {
            'tradeBycPerDay': _toDouble(pricingRaw['tradeBycPerDay'], 2.5),
            'giftBycPerDay': _toDouble(pricingRaw['giftBycPerDay'], 2),
            'donationBycPerDay': _toDouble(pricingRaw['donationBycPerDay'], 2),
            'normalBycPerDay': _toDouble(pricingRaw['normalBycPerDay'], 3),
          };
        }
      });
    } catch (_) {}
  }

  double _toDouble(dynamic v, double fallback) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? fallback;
  }

  void _togglePlacement(String key) {
    setState(() {
      if (_selectedPlacementKeys.contains(key)) {
        _selectedPlacementKeys.remove(key);
      } else {
        _selectedPlacementKeys.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Create Ad'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshFormData,
          color: AppTheme.primaryColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionHeader('Creative', 'Title, copy, link, and images or video for your campaign'),
              const SizedBox(height: 12),
              ByBataGlassContainer(
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    EnhancedFormField(
                      controller: _titleController,
                      label: 'Ad title',
                      hint: 'What are you promoting?',
                      maxLength: 80,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    EnhancedFormField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Short pitch shown on the card',
                      maxLines: 3,
                      maxLength: 200,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    EnhancedFormField(
                      controller: _linkController,
                      label: 'Destination link',
                      hint: 'https://your-site.com/offer',
                      keyboardType: TextInputType.url,
                      icon: Icons.link_rounded,
                      isRequired: true,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildMediaPicker(),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _sectionHeader('Placements', 'Select one or more feeds — each adds to your total'),
              const SizedBox(height: 12),
              _buildPlacementSelector(scheme),
              const SizedBox(height: 24),
              _sectionHeader('Schedule', 'When your ad runs'),
              const SizedBox(height: 12),
              ByBataGlassContainer(
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildDatePicker('Start', _start, (val) => setState(() => _start = val))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDurationPicker()),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildBudgetSummary(scheme),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isUploading ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isUploading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary),
                      )
                    : Text(
                        'Schedule for ${_computedTotal.toStringAsFixed(1)} BYC',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Future<void> _refreshFormData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.id ?? '';
    if (!_walletService.isInitialized && userId.isNotEmpty) {
      await _walletService.initializeWallet(userId);
    }
    await _walletService.refreshPromotionData();
    await _loadPlacements();
  }

  Widget _sectionHeader(String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPlacementSelector(ColorScheme scheme) {
    if (_placements.isEmpty) {
      return ByBataGlassContainer(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(16),
        child: Text(
          'No placements configured yet. Ask an admin to enable ad surfaces.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _placements.map((placement) {
          final key = placement['key']?.toString() ?? '';
          final name = placement['title']?.toString() ??
              placement['name']?.toString() ??
              key;
          final screen = AdPlacementKeys.screenLabel(key);
          final selected = _selectedPlacementKeys.contains(key);
          final rate = _dailyRateForKey(key);
          final lineCost = rate * _durationDays;

          return FilterChip(
            selected: selected,
            showCheckmark: true,
            label: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                if (screen != null)
                  Text(
                    'Shows on: $screen',
                    style: TextStyle(fontSize: 10, color: scheme.primary, fontWeight: FontWeight.w600),
                  ),
                Text(
                  '${rate.toStringAsFixed(1)} BYC/day · ${lineCost.toStringAsFixed(1)} total',
                  style: TextStyle(fontSize: 10, color: scheme.onSurface.withValues(alpha: 0.65)),
                ),
              ],
            ),
            onSelected: (_) => _togglePlacement(key),
            selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
            checkmarkColor: AppTheme.primaryColor,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBudgetSummary(ColorScheme scheme) {
    final count = _selectedPlacementKeys.length;
    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primaryColor, size: 22),
              const SizedBox(width: 10),
              Text('Budget summary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          if (count == 0)
            Text(
              'Select at least one placement to see pricing.',
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
            )
          else ...[
            ..._selectedPlacementKeys.map((key) {
              final label = _placements
                      .where((p) => p['key']?.toString() == key)
                      .map((p) => p['title']?.toString() ?? key)
                      .firstOrNull ??
                  key;
              final line = _dailyRateForKey(key) * _durationDays;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text('${line.toStringAsFixed(1)} BYC'),
                  ],
                ),
              );
            }),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$count placement${count == 1 ? '' : 's'} × $_durationDays days',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${_computedTotal.toStringAsFixed(1)} BYC',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _setMediaMode(String mode) {
    setState(() {
      _mediaMode = mode;
      if (mode == 'IMAGE') {
        _videoPath = null;
      } else {
        _mediaPaths.clear();
      }
    });
  }

  Widget _buildMediaPicker() {
    final scheme = Theme.of(context).colorScheme;
    final isImage = _mediaMode == 'IMAGE';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _mediaTypeChip('Images', 'IMAGE', isImage, scheme),
            const SizedBox(width: 8),
            _mediaTypeChip('Video', 'VIDEO', !isImage, scheme),
          ],
        ),
        const SizedBox(height: 10),
        if (isImage) ...[
          Row(
            children: [
              Text('Photos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurface)),
              const Spacer(),
              TextButton(onPressed: _showImagePicker, child: const Text('Add')),
            ],
          ),
          if (_mediaPaths.isEmpty)
            Text('Up to 5 images — remove video first to switch', style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.5))),
          if (_mediaPaths.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _mediaPaths.map((path) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(path), width: 72, height: 72, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _mediaPaths.remove(path)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.close, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
        ] else ...[
          Row(
            children: [
              Text('Video ad', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurface)),
              const Spacer(),
              TextButton(onPressed: _pickVideo, child: Text(_videoPath == null ? 'Add video' : 'Replace')),
            ],
          ),
          if (_videoPath == null)
            Text('One MP4 or MOV — remove images first to switch', style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.5))),
          if (_videoPath != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 120,
                    height: 72,
                    color: scheme.surfaceContainerHighest,
                    child: const Icon(Icons.videocam_rounded, size: 36),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: GestureDetector(
                    onTap: () => setState(() => _videoPath = null),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }

  Widget _mediaTypeChip(String label, String mode, bool selected, ColorScheme scheme) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      selected: selected,
      onSelected: (_) => _setMediaMode(mode),
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      checkmarkColor: AppTheme.primaryColor,
    );
  }

  Future<void> _pickVideo() async {
    if (_mediaPaths.isNotEmpty) {
      _showToast('Remove images before adding a video.', type: ToastType.warning);
      return;
    }
    if (!await PermissionsHelper.requestPhotoLibraryWithFallback(context, purpose: 'select a video for your ad')) {
      return;
    }
    final file = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
    if (file == null || !mounted) return;
    setState(() {
      _videoPath = file.path;
      _mediaMode = 'VIDEO';
    });
  }

  void _showImagePicker() async {
    if (_videoPath != null) {
      _showToast('Remove video before adding images.', type: ToastType.warning);
      return;
    }
    const maxMedia = 5;
    if (_mediaPaths.length >= maxMedia) {
      _showToast('Maximum $maxMedia images allowed.', type: ToastType.warning);
      return;
    }
    final source = await ImageSourcePickerSheet.show(
      context,
      title: 'Add photos to your ad',
      accentColor: AppTheme.primaryColor,
      maxImages: maxMedia,
      currentCount: _mediaPaths.length,
    );
    if (source == null || !mounted) return;
    if (source == ImageSource.gallery) {
      if (!await PermissionsHelper.requestPhotoLibraryWithFallback(context, purpose: 'select photos for your ad')) {
        return;
      }
      final files = await _picker.pickMultiImage(imageQuality: 85);
      if (files.isEmpty) return;

      final remaining = maxMedia - _mediaPaths.length;
      final toProcess = files.take(remaining).toList();
      final processedPaths = <String>[];
      for (final f in toProcess) {
        final normalized = await ImageResizeUtils.resizeToSquareFile(File(f.path));
        processedPaths.add(normalized.path);
      }

      if (mounted && processedPaths.isNotEmpty) {
        setState(() => _mediaPaths.addAll(processedPaths));
      }
    } else {
      if (!await PermissionsHelper.requestCameraWithFallback(context, purpose: 'take photos for your ad')) {
        return;
      }
      final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (file == null) return;
      final normalized = await ImageResizeUtils.resizeToSquareFile(File(file.path));
      if (!mounted) return;
      setState(() => _mediaPaths.add(normalized.path));
    }
  }

  Widget _buildDatePicker(String label, DateTime value, ValueChanged<DateTime> onChanged) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date == null || !mounted) return;
        final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(value));
        if (time == null) return;
        onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          '${value.day}/${value.month}/${value.year} ${TimeOfDay.fromDateTime(value).format(context)}',
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildDurationPicker() {
    return DropdownButtonFormField<int>(
      value: _durationDays,
      decoration: InputDecoration(
        labelText: 'Duration',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: const [
        DropdownMenuItem(value: 3, child: Text('3 days')),
        DropdownMenuItem(value: 7, child: Text('7 days')),
        DropdownMenuItem(value: 14, child: Text('14 days')),
        DropdownMenuItem(value: 30, child: Text('30 days')),
      ],
      onChanged: (value) => setState(() => _durationDays = value ?? 7),
    );
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final amount = _computedTotal;

    if (title.isEmpty) {
      _showToast('Add a title for your ad.', type: ToastType.warning);
      return;
    }
    final linkError = DestinationUrlUtils.validationMessage(_linkController.text);
    if (linkError != null) {
      _showToast(linkError, type: ToastType.warning);
      return;
    }
    final destinationUrl = DestinationUrlUtils.normalize(_linkController.text)!;

    if (_selectedPlacementKeys.isEmpty) {
      _showToast('Select at least one placement.', type: ToastType.warning);
      return;
    }
    if (amount <= 0) {
      _showToast('Invalid budget — check placements and duration.', type: ToastType.warning);
      return;
    }
    if (_start.isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
      _showToast('Start time must be in the future.', type: ToastType.warning);
      return;
    }

    if (_mediaMode == 'VIDEO' && (_videoPath == null || _videoPath!.isEmpty)) {
      _showToast('Add a video or switch to images.', type: ToastType.warning);
      return;
    }
    if (_mediaMode == 'IMAGE' && _mediaPaths.isEmpty) {
      _showToast('Add at least one image or switch to video.', type: ToastType.warning);
      return;
    }

    setState(() => _isUploading = true);
    try {
      String? videoKey;
      List<String> mediaKeys = [];
      if (_mediaMode == 'VIDEO') {
        videoKey = await _uploadVideo(_videoPath!);
        if (videoKey == null) {
          _showToast('Video upload failed. Try again.', type: ToastType.error);
          return;
        }
      } else {
        mediaKeys = await _uploadImages();
      }
      final end = _start.add(Duration(days: _durationDays));
      _submitIdempotencyKey ??= const Uuid().v4();
      final ok = await _walletService.scheduleAd(
        title: title,
        description: description.isEmpty ? null : description,
        mediaType: _mediaMode,
        mediaKeys: mediaKeys.isEmpty ? null : mediaKeys,
        videoKey: videoKey,
        placementKeys: _selectedPlacementKeys.toList(),
        scheduledStart: _start,
        scheduledEnd: end,
        amount: amount,
        destinationUrl: destinationUrl,
        idempotencyKey: _submitIdempotencyKey,
      );
      if (!mounted) return;
      if (ok) {
        _submitIdempotencyKey = null;
        _showToast('Ad submitted for review', type: ToastType.success);
        Navigator.maybePop(context);
      } else {
        final msg = PromotionErrorHandler.parseErrorMessage(
          _walletService.error,
        );
        _showToast(msg, type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<String?> _uploadVideo(String path) async {
    final file = File(path);
    if (!file.existsSync()) return null;
    const storage = FlutterSecureStorage();
    final baseUrl = await EnvConfig.getBaseUrl();
    final client = ApiClient(baseUrl, storage);
    final storageRepo = StorageRepository(client.dio);
    try {
      final bytes = await file.readAsBytes();
      final lower = path.toLowerCase();
      final ext = lower.endsWith('.mov') ? 'mov' : 'mp4';
      final contentType = ext == 'mov' ? 'video/quicktime' : 'video/mp4';
      final meta = await storageRepo.createUploadUrl(domain: 'ads', ext: ext, contentType: contentType);
      final uploadUrl = meta['uploadUrl'] as String?;
      final key = meta['key'] as String?;
      if (uploadUrl == null || key == null) return null;
      await storageRepo.uploadToSignedUrl(uploadUrl: uploadUrl, bytes: bytes, contentType: contentType);
      return key;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _uploadImages() async {
    if (_mediaPaths.isEmpty) return [];
    const storage = FlutterSecureStorage();
    final baseUrl = await EnvConfig.getBaseUrl();
    final client = ApiClient(baseUrl, storage);
    final storageRepo = StorageRepository(client.dio);
    final keys = <String>[];
    for (final path in _mediaPaths) {
      try {
        final file = File(path);
        if (!file.existsSync()) continue;
        final bytes = await file.readAsBytes();
        final ext = _inferExt(path);
        final contentType = _contentTypeFromExt(ext);
        final meta = await storageRepo.createUploadUrl(domain: 'ads', ext: ext, contentType: contentType);
        final uploadUrl = meta['uploadUrl'] as String?;
        final key = meta['key'] as String?;
        if (uploadUrl == null || key == null) continue;
        await storageRepo.uploadToSignedUrl(uploadUrl: uploadUrl, bytes: bytes, contentType: contentType);
        keys.add(key);
      } catch (_) {}
    }
    return keys;
  }

  String _inferExt(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.jpeg')) return 'jpeg';
    if (lower.endsWith('.jpg')) return 'jpg';
    if (lower.endsWith('.heic')) return 'heic';
    return 'jpg';
  }

  String _contentTypeFromExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpeg':
      case 'jpg':
        return 'image/jpeg';
      case 'heic':
        return 'image/heic';
      default:
        return 'application/octet-stream';
    }
  }

  void _showToast(String message, {ToastType type = ToastType.info}) {
    AppToast.show(context, message, type: type);
  }
}
