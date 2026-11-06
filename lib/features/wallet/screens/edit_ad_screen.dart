import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/constants/ad_placement_keys.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/destination_url_utils.dart';
import '../../../core/utils/image_resize_utils.dart';
import '../../../core/utils/permissions_helper.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../../../core/widgets/cached_media_image.dart';
import '../../../core/widgets/edit_form_scaffold.dart';
import '../../../core/widgets/editable_media_grid.dart';
import '../../../core/widgets/enhanced_form_field.dart';
import '../../../core/widgets/image_source_picker_sheet.dart';
import '../../storage/repository/storage_repository.dart';
import '../services/wallet_service.dart';
import '../utils/promotion_error_handler.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';

/// Edit an existing feed ad. Live ads can update copy/media/link only; schedule
/// and placements require the ad to be paused or not yet running.
class EditAdScreen extends StatefulWidget {
  final Map<String, dynamic> ad;

  const EditAdScreen({super.key, required this.ad});

  @override
  State<EditAdScreen> createState() => _EditAdScreenState();
}

class _EditAdScreenState extends State<EditAdScreen> {
  final WalletService _walletService = WalletService();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _linkController;

  late String _mediaMode;
  List<String> _existingMediaKeys = [];
  String? _existingVideoKey;
  final List<File> _newImageFiles = [];
  String? _newVideoPath;

  late DateTime _start;
  late int _durationDays;
  late final Set<String> _selectedPlacementKeys;
  List<Map<String, dynamic>> _placements = [];

  late final String _initialSnapshot;
  bool _isSaving = false;
  bool _loadingPlacements = true;

  String get _adId => widget.ad['id']?.toString() ?? '';
  String get _status => widget.ad['status']?.toString() ?? '';

  bool get _locksSchedule =>
      _status == 'ACTIVE' || _status == 'PAUSED';

  bool get _needsReReview =>
      _status == 'REJECTED' ||
      _status == 'ACTIVE' ||
      _status == 'PAUSED' ||
      _status == 'SCHEDULED';

  @override
  void initState() {
    super.initState();
    final ad = widget.ad;
    _titleController = TextEditingController(text: ad['title']?.toString() ?? '');
    _descriptionController =
        TextEditingController(text: ad['description']?.toString() ?? '');
    _linkController =
        TextEditingController(text: ad['destinationUrl']?.toString() ?? '');

    _mediaMode = (ad['mediaType']?.toString() ?? 'IMAGE').toUpperCase();
    final keysRaw = ad['mediaKeys'];
    if (keysRaw is List) {
      _existingMediaKeys =
          keysRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    final vk = ad['videoKey']?.toString();
    if (vk != null && vk.isNotEmpty) _existingVideoKey = vk;

    _start = _parseDate(ad['scheduledStart']) ??
        DateTime.now().add(const Duration(hours: 1));
    final end = _parseDate(ad['scheduledEnd']);
    _durationDays = end != null
        ? (end.difference(_start).inDays).clamp(1, 365)
        : 7;

    _selectedPlacementKeys = {};
    final pk = ad['placementKeys'];
    if (pk is List) {
      for (final e in pk) {
        final k = e.toString();
        if (k.isNotEmpty) _selectedPlacementKeys.add(k);
      }
    }
    final single = ad['placementKey']?.toString();
    if (single != null && single.isNotEmpty) {
      _selectedPlacementKeys.add(single);
    }

    _initialSnapshot = _snapshot();
    _titleController.addListener(_onChanged);
    _descriptionController.addListener(_onChanged);
    _linkController.addListener(_onChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _onChanged() => setState(() {});

  Future<void> _init() async {
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
      if (!mounted) return;
      setState(() {
        _placements =
            placements.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loadingPlacements = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPlacements = false);
    }
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  String _snapshot() {
    return [
      _titleController.text.trim(),
      _descriptionController.text.trim(),
      _linkController.text.trim(),
      _mediaMode,
      _existingMediaKeys.join('|'),
      _existingVideoKey ?? '',
      _newImageFiles.length,
      _newVideoPath ?? '',
      _start.toIso8601String(),
      _durationDays,
      _selectedPlacementKeys.join(','),
    ].join('::');
  }

  bool get _isDirty => _snapshot() != _initialSnapshot;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return EditFormScaffold(
      title: 'Edit ad',
      discardItemLabel: 'ad',
      isLoading: _isSaving,
      isDirty: _isDirty,
      onSave: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_needsReReview)
            _infoBanner(
              isDark,
              'Saving will send this ad back for admin review before it can run again.',
              Icons.fact_check_outlined,
              Colors.amber,
            ),
          if (_locksSchedule)
            _infoBanner(
              isDark,
              'This ad is live or paused — you can edit title, description, link, and media. Pause it first to change schedule or placements.',
              Icons.info_outline_rounded,
              AppTheme.primaryColor,
            ),
          if (_status == 'REJECTED')
            _infoBanner(
              isDark,
              'This ad was rejected. Update the creative and resubmit for review.',
              Icons.error_outline_rounded,
              Colors.red,
            ),
          const SizedBox(height: 16),
          EditFormSection(
            title: 'Creative',
            subtitle: 'Title, description, destination link, and media',
            child: ByBataGlassContainer(
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
                    hint: 'Short pitch on the card',
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
                  const SizedBox(height: 16),
                  _buildMediaSection(scheme, isDark),
                ],
              ),
            ),
          ),
          if (!_locksSchedule) ...[
            const SizedBox(height: 20),
            EditFormSection(
              title: 'Placements',
              subtitle: 'Feeds where this ad appears',
              child: _loadingPlacements
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: const BybataLoader(),
                    )
                  : _buildPlacementSelector(scheme),
            ),
            const SizedBox(height: 20),
            EditFormSection(
              title: 'Schedule',
              subtitle: 'When your ad runs',
              child: ByBataGlassContainer(
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildDatePicker(
                        'Start',
                        _start,
                        (val) => setState(() => _start = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDurationPicker()),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoBanner(
    bool isDark,
    String text,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection(ColorScheme scheme, bool isDark) {
    final isImage = _mediaMode == 'IMAGE';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _mediaChip('Images', 'IMAGE', isImage, scheme),
            const SizedBox(width: 8),
            _mediaChip('Video', 'VIDEO', !isImage, scheme),
          ],
        ),
        const SizedBox(height: 12),
        if (isImage)
          EditableMediaGrid(
            existingKeys: _existingMediaKeys,
            newFiles: _newImageFiles,
            onAdd: _addImages,
            onRemoveExisting: (i) =>
                setState(() => _existingMediaKeys.removeAt(i)),
            onRemoveNew: (i) => setState(() => _newImageFiles.removeAt(i)),
          )
        else
          _buildVideoEditor(isDark),
      ],
    );
  }

  Widget _buildVideoEditor(bool isDark) {
    final hasExisting =
        _existingVideoKey != null && _existingVideoKey!.isNotEmpty;
    final hasNew = _newVideoPath != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Video',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _pickVideo,
              child: Text(hasExisting || hasNew ? 'Replace' : 'Add video'),
            ),
          ],
        ),
        if (hasExisting && !hasNew)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 120,
                  height: 72,
                  child: CachedMediaImage(
                    mediaKey: _existingVideoKey,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.videocam_rounded, size: 36),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: GestureDetector(
                  onTap: () => setState(() => _existingVideoKey = null),
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
        if (hasNew)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 120,
                  height: 72,
                  color: Colors.grey[700],
                  child: const Icon(Icons.videocam_rounded, size: 36),
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: GestureDetector(
                  onTap: () => setState(() => _newVideoPath = null),
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
        if (!hasExisting && !hasNew)
          Text(
            'Add one video (MP4 or MOV)',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
      ],
    );
  }

  Widget _mediaChip(
    String label,
    String mode,
    bool selected,
    ColorScheme scheme,
  ) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _mediaMode = mode;
          if (mode == 'IMAGE') {
            _newVideoPath = null;
            _existingVideoKey = null;
          } else {
            _newImageFiles.clear();
            _existingMediaKeys = [];
          }
        });
      },
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      checkmarkColor: AppTheme.primaryColor,
    );
  }

  Widget _buildPlacementSelector(ColorScheme scheme) {
    if (_placements.isEmpty) {
      return Text(
        'Placements unavailable.',
        style: Theme.of(context).textTheme.bodyMedium,
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
          final name = placement['title']?.toString() ?? key;
          final screen = AdPlacementKeys.screenLabel(key);
          final selected = _selectedPlacementKeys.contains(key);
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
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            onSelected: (_) {
              setState(() {
                if (selected) {
                  _selectedPlacementKeys.remove(key);
                } else {
                  _selectedPlacementKeys.add(key);
                }
              });
            },
            selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
            checkmarkColor: AppTheme.primaryColor,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime value,
    ValueChanged<DateTime> onChanged,
  ) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date == null || !mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value),
        );
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
      onChanged: (v) => setState(() => _durationDays = v ?? 7),
    );
  }

  Future<void> _addImages() async {
    if (_newVideoPath != null || (_existingVideoKey?.isNotEmpty ?? false)) {
      _toast('Remove video before adding images.', ToastType.warning);
      return;
    }
    const max = 5;
    final total = _existingMediaKeys.length + _newImageFiles.length;
    if (total >= max) {
      _toast('Maximum $max images.', ToastType.warning);
      return;
    }
    final source = await ImageSourcePickerSheet.show(
      context,
      title: 'Add photos',
      accentColor: AppTheme.primaryColor,
      maxImages: max,
      currentCount: total,
    );
    if (source == null || !mounted) return;
    if (source == ImageSource.gallery) {
      if (!await PermissionsHelper.requestPhotoLibraryWithFallback(
        context,
        purpose: 'select photos for your ad',
      )) {
        return;
      }
      final files = await _picker.pickMultiImage(imageQuality: 85);
      final remaining = max - total;
      for (final f in files.take(remaining)) {
        final normalized =
            await ImageResizeUtils.resizeToSquareFile(File(f.path));
        if (mounted) setState(() => _newImageFiles.add(normalized));
      }
    } else {
      if (!await PermissionsHelper.requestCameraWithFallback(
        context,
        purpose: 'take a photo for your ad',
      )) {
        return;
      }
      final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (file == null) return;
      final normalized =
          await ImageResizeUtils.resizeToSquareFile(File(file.path));
      if (mounted) setState(() => _newImageFiles.add(normalized));
    }
  }

  Future<void> _pickVideo() async {
    if (_existingMediaKeys.isNotEmpty || _newImageFiles.isNotEmpty) {
      _toast('Remove images before adding video.', ToastType.warning);
      return;
    }
    if (!await PermissionsHelper.requestPhotoLibraryWithFallback(
      context,
      purpose: 'select a video for your ad',
    )) {
      return;
    }
    final file = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );
    if (file == null || !mounted) return;
    setState(() {
      _newVideoPath = file.path;
      _mediaMode = 'VIDEO';
      _existingVideoKey = null;
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _toast('Add a title.', ToastType.warning);
      return;
    }
    final linkError = DestinationUrlUtils.validationMessage(_linkController.text);
    if (linkError != null) {
      _toast(linkError, ToastType.warning);
      return;
    }
    final destinationUrl = DestinationUrlUtils.normalize(_linkController.text)!;

    if (!_locksSchedule && _selectedPlacementKeys.isEmpty) {
      _toast('Select at least one placement.', ToastType.warning);
      return;
    }

    if (_mediaMode == 'IMAGE') {
      final total = _existingMediaKeys.length + _newImageFiles.length;
      if (total == 0) {
        _toast('Add at least one image.', ToastType.warning);
        return;
      }
    } else {
      final hasVideo =
          _newVideoPath != null ||
          (_existingVideoKey != null && _existingVideoKey!.isNotEmpty);
      if (!hasVideo) {
        _toast('Add a video or switch to images.', ToastType.warning);
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      String? videoKey = _existingVideoKey;
      List<String>? mediaKeys;

      if (_mediaMode == 'VIDEO') {
        if (_newVideoPath != null) {
          videoKey = await _uploadVideo(_newVideoPath!);
          if (videoKey == null) {
            _toast('Video upload failed.', ToastType.error);
            return;
          }
        }
        mediaKeys = [];
      } else {
        videoKey = null;
        final uploaded = await _uploadImages(_newImageFiles);
        mediaKeys = [..._existingMediaKeys, ...uploaded];
        if (mediaKeys.isEmpty) {
          _toast('Image upload failed.', ToastType.error);
          return;
        }
      }

      final description = _descriptionController.text.trim();
      DateTime? scheduledEnd;
      if (!_locksSchedule) {
        scheduledEnd = _start.add(Duration(days: _durationDays));
      }

      final ok = await _walletService.updateAd(
        adScheduleId: _adId,
        title: title,
        description: description.isEmpty ? null : description,
        mediaType: _mediaMode,
        mediaKeys: mediaKeys,
        videoKey: videoKey,
        placementKeys: _locksSchedule ? null : _selectedPlacementKeys.toList(),
        scheduledStart: _locksSchedule ? null : _start,
        scheduledEnd: _locksSchedule ? null : scheduledEnd,
        destinationUrl: destinationUrl,
      );

      if (!mounted) return;
      if (ok) {
        _toast(
          _needsReReview
              ? 'Ad updated — sent for review'
              : 'Ad updated',
          ToastType.success,
        );
        Navigator.pop(context, true);
      } else {
        _toast(
          PromotionErrorHandler.parseErrorMessage(_walletService.error),
          ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String?> _uploadVideo(String path) async {
    const storage = FlutterSecureStorage();
    final baseUrl = await EnvConfig.getBaseUrl();
    final client = ApiClient(baseUrl, storage);
    final storageRepo = StorageRepository(client.dio);
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final lower = path.toLowerCase();
      final ext = lower.endsWith('.mov') ? 'mov' : 'mp4';
      final contentType = ext == 'mov' ? 'video/quicktime' : 'video/mp4';
      final meta = await storageRepo.createUploadUrl(
        domain: 'ads',
        ext: ext,
        contentType: contentType,
      );
      final uploadUrl = meta['uploadUrl'] as String?;
      final key = meta['key'] as String?;
      if (uploadUrl == null || key == null) return null;
      await storageRepo.uploadToSignedUrl(
        uploadUrl: uploadUrl,
        bytes: bytes,
        contentType: contentType,
      );
      return key;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _uploadImages(List<File> files) async {
    if (files.isEmpty) return [];
    const storage = FlutterSecureStorage();
    final baseUrl = await EnvConfig.getBaseUrl();
    final client = ApiClient(baseUrl, storage);
    final storageRepo = StorageRepository(client.dio);
    final keys = <String>[];
    for (final file in files) {
      try {
        if (!file.existsSync()) continue;
        final bytes = await file.readAsBytes();
        final path = file.path.toLowerCase();
        final ext = path.endsWith('.png')
            ? 'png'
            : path.endsWith('.jpeg')
                ? 'jpeg'
                : 'jpg';
        final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
        final meta = await storageRepo.createUploadUrl(
          domain: 'ads',
          ext: ext,
          contentType: contentType,
        );
        final uploadUrl = meta['uploadUrl'] as String?;
        final key = meta['key'] as String?;
        if (uploadUrl == null || key == null) continue;
        await storageRepo.uploadToSignedUrl(
          uploadUrl: uploadUrl,
          bytes: bytes,
          contentType: contentType,
        );
        keys.add(key);
      } catch (_) {}
    }
    return keys;
  }

  void _toast(String message, ToastType type) {
    AppToast.show(context, message, type: type);
  }
}
