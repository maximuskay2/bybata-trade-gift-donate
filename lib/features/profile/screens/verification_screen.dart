import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../models/user_profile.dart';
import '../services/verification_api.dart';
import '../services/verification_progress_store.dart';
import 'edit_profile_screen.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';
import 'package:bybata/core/utils/network_error_message.dart';

/// Step-by-step identity verification — contact first, then documents.
class VerificationScreen extends StatefulWidget {
  final UserProfile userProfile;

  const VerificationScreen({super.key, required this.userProfile});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isBootstrapping = true;
  String? _errorMessage;
  VerificationStatus? _verificationOverride;
  late UserProfile _profile;
  bool _emailVerified = false;
  bool _phoneVerified = false;
  final Map<VerificationType, DocumentUpload?> _uploads = {};
  VerificationApi? _verificationApi;
  final ImagePicker _picker = ImagePicker();
  final _emailCodeController = TextEditingController();
  final _phoneCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _profile = widget.userProfile;
    for (final t in VerificationType.values) {
      _uploads[t] = null;
    }
    _bootstrapVerification();
  }

  Future<void> _bootstrapVerification() async {
    _verificationApi = await VerificationApi.create();
    await _loadVerificationState();
  }

  Future<void> _loadVerificationState() async {
    setState(() => _isBootstrapping = true);
    try {
      final api = _verificationApi ?? await VerificationApi.create();
      _verificationApi = api;
      VerificationStatus status;
      try {
        status = await api.getVerificationStatus();
      } catch (_) {
        status = await api.refreshFromMe();
      }
      final docs = await api.getVerificationDocuments();
      _applyVerificationState(status, docs);
      await VerificationProgressStore.save(userId: _profile.id, status: status);
    } catch (_) {
      final cached = await VerificationProgressStore.load(_profile.id);
      if (cached != null) {
        _applyVerificationState(cached, const []);
      } else {
        _applyVerificationState(_profile.verification, const []);
      }
    } finally {
      if (mounted) setState(() => _isBootstrapping = false);
    }
  }

  void _applyVerificationState(
    VerificationStatus status,
    List<Map<String, dynamic>> docs,
  ) {
    _verificationOverride = status;
    _emailVerified = status.isStepComplete(VerificationType.email);
    _phoneVerified = status.isStepComplete(VerificationType.phone);
    for (final doc in docs) {
      final type = _parseVerificationType(doc['type']);
      if (type == null) continue;
      final uploadedAtRaw = doc['uploadedAt'] ?? doc['createdAt'];
      _uploads[type] = DocumentUpload(
        fileName: doc['fileName'] as String? ?? 'Uploaded document',
        uploadedAt: uploadedAtRaw != null
            ? DateTime.tryParse(uploadedAtRaw.toString()) ?? DateTime.now()
            : DateTime.now(),
        status: UploadStatus.uploaded,
        documentKey: doc['documentKey'] as String?,
      );
    }
  }

  VerificationType? _parseVerificationType(dynamic raw) {
    final value = raw?.toString() ?? '';
    if (value.isEmpty) return null;
    final normalized = value.contains('.') ? value.split('.').last : value;
    for (final type in VerificationType.values) {
      if (type.toString().split('.').last == normalized) return type;
    }
    return null;
  }

  @override
  void dispose() {
    _emailCodeController.dispose();
    _phoneCodeController.dispose();
    super.dispose();
  }

  VerificationStatus get _verification =>
      _verificationOverride ?? _profile.verification;

  VerificationStatusType get _status => _verification.status;

  bool get _isVerified => _status == VerificationStatusType.verified;
  bool get _isPending => _status == VerificationStatusType.pending;
  bool get _isRejected => _status == VerificationStatusType.rejected;

  bool get _emailOk =>
      _verification.isStepComplete(VerificationType.email) || _emailVerified;

  bool get _phoneOk =>
      _verification.isStepComplete(VerificationType.phone) || _phoneVerified;

  bool get _hasPhone => _profile.phone?.isNotEmpty == true;

  bool get _idUploaded =>
      _uploads[VerificationType.identity]?.status == UploadStatus.uploaded ||
      _verification.isStepComplete(VerificationType.identity);

  bool get _canSubmit =>
      !_isVerified &&
      !_isPending &&
      !_isSubmitting &&
      !_isLoading &&
      _emailOk &&
      (!_hasPhone || _phoneOk) &&
      _idUploaded;

  int get _completedSteps {
    var n = 0;
    if (_emailOk) n++;
    if (!_hasPhone || _phoneOk) n++;
    if (_idUploaded) n++;
    return n;
  }

  // --- API actions (unchanged logic) ---

  Future<void> _startVerification() async {
    setState(() => _errorMessage = null);
    if (!_emailOk) {
      _showSnack('Verify your email first', isError: true);
      return;
    }
    if (_hasPhone && !_phoneOk) {
      _showSnack('Verify your phone number first', isError: true);
      return;
    }
    final uploaded = _uploads.entries
        .where((e) => e.value?.status == UploadStatus.uploaded)
        .toList();
    if (uploaded.isEmpty) {
      _showSnack('Upload your government ID to continue', isError: true);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final keys = <VerificationType, String>{};
      for (final e in uploaded) {
        keys[e.key] = e.value!.documentKey!;
      }
      final api = _verificationApi!;
      final status = await api.submitVerificationDocuments(
        userId: _profile.id,
        documentKeys: keys,
      );
      final pendingStatus = status.status == VerificationStatusType.pending
          ? status
          : VerificationStatus(
              status: VerificationStatusType.pending,
              completedVerifications: [
                if (_emailOk) VerificationType.email,
                if (_phoneOk) VerificationType.phone,
                ...keys.keys,
              ],
            );
      final updatedProfile = _profile.copyWith(verification: pendingStatus);

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = null;
        _verificationOverride = pendingStatus;
        _profile = updatedProfile;
      });
      await VerificationProgressStore.save(
        userId: _profile.id,
        status: pendingStatus,
      );

      await _showSubmittedDialog();
      if (!mounted) return;
      Navigator.pop(context, updatedProfile);
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = _formatError(e);
      });
      _showSnack(_errorMessage!, isError: true);
    }
  }

  Future<void> _showSubmittedDialog() async {
    final scheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.hourglass_top_rounded, color: AppTheme.karmaColor, size: 40),
        title: const Text('Submitted for review'),
        content: const Text(
          'Your documents were received. Our team typically reviews submissions within 1–2 business days. You will get an email when your verification status changes.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('Got it'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: scheme.surface,
      ),
    );
  }

  Future<void> _uploadDocument(VerificationType type) async {
    final scheme = Theme.of(context).colorScheme;
    final isId = type == VerificationType.identity;
    final title = isId ? 'Government ID' : 'Proof of address';
    final tip = isId
        ? 'Lay your passport or license flat. Capture the full page — no glare, no crop.'
        : 'Photograph a utility bill or bank statement that shows your name and address.';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withValues(alpha: 0.75),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.photo_camera_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Take a live photo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tip,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 20,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Camera only — gallery uploads are blocked for security.',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                              color: scheme.onSurface.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _pickAndUpload(type, ImageSource.camera);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.photo_camera_rounded, size: 22),
                      label: const Text(
                        'Open camera',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Not now',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUpload(VerificationType type, ImageSource source) async {
    // Identity docs must be captured live — never accept gallery images.
    if (source != ImageSource.camera) {
      _showSnack(
        'Use the camera to take a live photo. Gallery uploads are not allowed.',
        isError: true,
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null) {
        setState(() => _isLoading = false);
        return;
      }
      final api = _verificationApi!;
      final key = await api.uploadVerificationDocument(
        file.path,
        type,
      );
      await api.registerVerificationDocument(
        type: type,
        documentKey: key,
        fileName: file.name,
      );
      await _loadVerificationState();
      if (!mounted) return;
      _showSnack('Document uploaded');
    } catch (e) {
      setState(() {
        _errorMessage = _formatError(e);
      });
      _showSnack(_errorMessage!, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestEmailCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final api = _verificationApi!;
      await api.requestEmailVerification(_profile.email);
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Code sent to ${_profile.email}');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _formatError(e);
      });
      _showSnack(_errorMessage!, isError: true);
    }
  }

  Future<void> _confirmEmailCode() async {
    if (_emailCodeController.text.trim().isEmpty) {
      _showSnack('Enter the code from your email', isError: true);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final api = _verificationApi!;
      await api.confirmEmailVerification(
        _emailCodeController.text.trim(),
      );
      await _loadVerificationState();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _emailCodeController.clear();
      });
      _showSnack('Email verified');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _formatError(e);
      });
      _showSnack(_errorMessage!, isError: true);
    }
  }

  Future<void> _requestPhoneCode() async {
    if (!_hasPhone) {
      _showSnack('Add your phone in Edit Profile first', isError: true);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final api = _verificationApi!;
      final result = await api.requestPhoneVerification(_profile.phone!);
      if (!mounted) return;
      setState(() => _isLoading = false);
      final channels = (result['channelsSent'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      final via = channels.isEmpty
          ? 'your phone'
          : channels
              .map((c) => c == 'whatsapp' ? 'WhatsApp' : 'SMS')
              .join(' & ');
      _showSnack('Code sent via $via');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _formatError(e);
      });
      _showSnack(_errorMessage!, isError: true);
    }
  }

  Future<void> _confirmPhoneCode() async {
    if (_phoneCodeController.text.trim().isEmpty) {
      _showSnack('Enter the code from your phone', isError: true);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final api = _verificationApi!;
      await api.confirmPhoneVerification(
        _phoneCodeController.text.trim(),
      );
      await _loadVerificationState();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _phoneCodeController.clear();
      });
      _showSnack('Phone verified');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _formatError(e);
      });
      _showSnack(_errorMessage!, isError: true);
    }
  }

  String _formatError(Object error) {
    return NetworkErrorMessage.from(error);
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AppToast.error(context, msg);
    } else {
      AppToast.success(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Verify identity'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _buildStatusBanner(scheme),
                    const SizedBox(height: 20),
                    _buildProgressStrip(scheme),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _buildErrorBanner(scheme),
                    ],
                    const SizedBox(height: 24),
                    _sectionTitle(scheme, 'Step 1', 'Confirm contact'),
                    const SizedBox(height: 12),
                    _buildEmailStep(scheme),
                    const SizedBox(height: 12),
                    _buildPhoneStep(scheme),
                    const SizedBox(height: 24),
                    _sectionTitle(scheme, 'Step 2', 'Upload ID'),
                    const SizedBox(height: 8),
                    Text(
                      'Use your camera to capture a clear photo. Gallery uploads are not allowed.',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDocumentTile(
                      scheme,
                      type: VerificationType.identity,
                      title: 'Government ID',
                      subtitle: 'Tap to open camera · Required',
                    ),
                    const SizedBox(height: 10),
                    _buildDocumentTile(
                      scheme,
                      type: VerificationType.address,
                      title: 'Proof of address',
                      subtitle: 'Tap to open camera · Optional',
                    ),
                    const SizedBox(height: 24),
                    _buildWhyVerify(scheme),
                  ],
                ),
              ),
              if (!_isVerified && !_isPending) _buildBottomBar(scheme),
            ],
          ),
          if (_isBootstrapping)
            Container(
              color: scheme.surface.withValues(alpha: 0.7),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(ColorScheme scheme) {
    final (title, subtitle, icon, color) = switch (_status) {
      VerificationStatusType.verified => (
          'You\'re verified',
          'Full access to trading and withdrawals.',
          Icons.verified_rounded,
          AppTheme.successColor,
        ),
      VerificationStatusType.pending => (
          'Under review',
          'We\'ll notify you when your documents are approved.',
          Icons.hourglass_top_rounded,
          AppTheme.karmaColor,
        ),
      VerificationStatusType.rejected => (
          'Verification declined',
          _verification.rejectionReason ??
              'Please upload clearer photos and try again.',
          Icons.info_outline_rounded,
          scheme.error,
        ),
      _ => (
          'Get verified',
          'Takes about 5 minutes. Unlock higher limits and a trusted badge.',
          Icons.shield_outlined,
          AppTheme.primaryColor,
        ),
    };

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStrip(ColorScheme scheme) {
    return Row(
      children: [
        _stepDot(scheme, 1, _emailOk),
        Expanded(child: _stepLine(scheme, _emailOk)),
        _stepDot(scheme, 2, !_hasPhone || _phoneOk),
        Expanded(child: _stepLine(scheme, _idUploaded)),
        _stepDot(scheme, 3, _idUploaded),
        const SizedBox(width: 8),
        Text(
          '$_completedSteps/3',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _stepDot(ColorScheme scheme, int n, bool done) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done
            ? AppTheme.successColor
            : scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: done
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : Text(
              '$n',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
    );
  }

  Widget _stepLine(ColorScheme scheme, bool done) {
    return Container(
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: done
            ? AppTheme.successColor.withValues(alpha: 0.5)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _sectionTitle(ColorScheme scheme, String step, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            step,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailStep(ColorScheme scheme) {
    if (_emailOk) return _doneTile(scheme, 'Email verified', _profile.email);

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _profile.email,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCodeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '6-digit code',
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _requestEmailCode,
                    child: const Text('Send code'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _isLoading ? null : _confirmEmailCode,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                    child: const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneStep(ColorScheme scheme) {
    if (!_hasPhone) {
      return ByBataGlassContainer(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phone number',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add a phone number for account security and withdrawals.',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final updated = await GuardedNavigator.push(context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EditProfileScreen(userProfile: _profile),
                      ),
                    );
                    if (updated == true && mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Add phone in profile'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_phoneOk) {
      return _doneTile(scheme, 'Phone verified', _profile.phone!);
    }

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _profile.phone!,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCodeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '6-digit code',
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _requestPhoneCode,
                    child: const Text('Send code'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _isLoading ? null : _confirmPhoneCode,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                    child: const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _doneTile(ColorScheme scheme, String title, String value) {
    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.successColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentTile(
    ColorScheme scheme, {
    required VerificationType type,
    required String title,
    required String subtitle,
  }) {
    final upload = _uploads[type];
    final done = upload?.status == UploadStatus.uploaded ||
        _verification.isStepComplete(type);
    final locked = _isVerified || _isPending;
    final canCapture = !locked && !_isLoading && !done;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: locked || _isLoading ? null : () => _uploadDocument(type),
        borderRadius: BorderRadius.circular(18),
        child: ByBataGlassContainer(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: canCapture
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  )
                : null,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: done
                        ? AppTheme.successColor.withValues(alpha: 0.12)
                        : AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : Icons.photo_camera_rounded,
                    color: done
                        ? AppTheme.successColor
                        : AppTheme.primaryColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        done
                            ? (upload?.fileName ?? 'Uploaded')
                            : subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: done
                              ? AppTheme.successColor
                              : AppTheme.primaryColor.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading && !done)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (!done && !locked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_camera_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Capture',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (done && !locked)
                  IconButton(
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                    onPressed: () => _uploadDocument(type),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWhyVerify(ColorScheme scheme) {
    const perks = [
      (Icons.verified_rounded, 'Trusted badge on your profile'),
      (Icons.trending_up_rounded, 'Higher trading limits'),
      (Icons.account_balance_wallet_outlined, 'Withdrawals & wallet features'),
      (Icons.auto_awesome_rounded, 'Bonus KARMA when approved'),
    ];

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Why verify?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            ...perks.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(p.$1, size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        p.$2,
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurface.withValues(alpha: 0.85),
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
    );
  }

  Widget _buildErrorBanner(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: scheme.error, fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: scheme.error),
            onPressed: () => setState(() => _errorMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ColorScheme scheme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outline.withValues(alpha: 0.15)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_canSubmit)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _submitHint(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canSubmit ? _startVerification : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                disabledBackgroundColor: scheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isRejected ? 'Resubmit for review' : 'Submit for review',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _submitHint() {
    if (!_emailOk) return 'Complete email verification to continue';
    if (_hasPhone && !_phoneOk) return 'Complete phone verification to continue';
    if (!_idUploaded) return 'Upload your government ID to submit';
    return '';
  }
}

class DocumentUpload {
  final String fileName;
  final DateTime uploadedAt;
  final UploadStatus status;
  final String? documentKey;

  DocumentUpload({
    required this.fileName,
    required this.uploadedAt,
    required this.status,
    this.documentKey,
  });
}

enum UploadStatus { uploading, uploaded, rejected }
