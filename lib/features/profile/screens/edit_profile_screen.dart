import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../models/user_profile.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../repository/profile_repository.dart';
import 'package:image_picker/image_picker.dart';
import '../../storage/repository/storage_repository.dart';
import '../../../core/utils/permissions_helper.dart';
import '../../../core/utils/media_utils.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/app_toast.dart';
import '../../auth/screens/forgot_password_screen.dart';
import 'verification_screen.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import '../../../core/utils/network_error_message.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile userProfile;

  const EditProfileScreen({
    super.key,
    required this.userProfile,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with SingleTickerProviderStateMixin {
  Uint8List? _avatarBytes;
  String? _avatarUrl;
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailController = TextEditingController();
  final _userIdController = TextEditingController();

  static const _bioMaxLength = 280;

  bool _isLoading = false;
  bool _isSaving = false;
  TabController? _tabController;
  bool _isInitialized = false;
  late ProfileSettings _settings;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController!.addListener(() {
      if (!_tabController!.indexIsChanging) {
        setState(() => _currentTabIndex = _tabController!.index);
      }
    });
    _initializeFields();
    _avatarUrl = widget.userProfile.avatar;
    _settings = widget.userProfile.settings;
    _phoneController.addListener(() => setState(() {}));
    _isInitialized = true;
  }

  void _initializeFields() {
    _displayNameController.text = widget.userProfile.displayName;
    _phoneController.text = widget.userProfile.phone ?? '';
    _bioController.text = widget.userProfile.bio ?? '';
    _emailController.text = widget.userProfile.email;
    _userIdController.text = widget.userProfile.id;
    _bioController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  // --- 3D UI ENGINE ---
  Widget _build3DContainer({
    required Widget child,
    Color? color,
    double radius = 24,
    EdgeInsets? padding,
  }) {
    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }

  Widget _buildRecessedInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
    bool readOnly = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            maxLength: maxLength,
            readOnly: readOnly,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: icon != null
                  ? Icon(
                      icon,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    )
                  : null,
              suffixIcon: suffix,
              counterText: '',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- LOGIC PRESERVATION ---
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final base = await EnvConfig.getBaseUrl();
      final client = ApiClient(base, const FlutterSecureStorage());
      final profile = ProfileRepository(client.dio);
      await profile.updateMe(
        displayName: _displayNameController.text.trim().isEmpty ? null : _displayNameController.text.trim(),
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        avatarKey: _avatarUrl,
      );
      if (mounted) {
        try { await context.read<AuthProvider>().refreshUserData(); } catch (_) {}
        AppToast.success(context, 'Profile updated successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          NetworkErrorMessage.from(
            e,
            fallback: 'Could not update profile. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _tabController == null) return const Scaffold(body: BybataLoader());
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _build3DAppBar(scheme.primary),
            const SizedBox(height: 20),
            _buildFluidTabSwitcher(scheme.primary),
            Expanded(
              child: TabBarView(
                controller: _tabController!,
                children: [
                  _buildProfileTab(scheme.primary),
                  _buildAccountTab(scheme.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build3DAppBar(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: _build3DContainer(
              radius: 12,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          Text(
            "Edit Profile",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          GestureDetector(
            onTap: _isSaving ? null : _saveProfile,
            child: _build3DContainer(
              radius: 12, 
              color: primaryColor,
              child: Padding(
                padding: const EdgeInsets.all(10), 
                child: _isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        Icons.check,
                        size: 20,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFluidTabSwitcher(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _tabChip(
            label: 'Profile',
            icon: Icons.person_outline_rounded,
            selected: _currentTabIndex == 0,
            primaryColor: primaryColor,
            onTap: () {
              setState(() => _currentTabIndex = 0);
              _tabController!.animateTo(0);
            },
          ),
          _tabChip(
            label: 'Account',
            icon: Icons.settings_outlined,
            selected: _currentTabIndex == 1,
            primaryColor: primaryColor,
            onTap: () {
              setState(() => _currentTabIndex = 1);
              _tabController!.animateTo(1);
            },
          ),
        ],
      ),
    );
  }

  Widget _tabChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: selected ? scheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? primaryColor : scheme.onSurface.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 14,
                  color: selected ? primaryColor : scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab(Color primaryColor) {
    final verification = widget.userProfile.verification;
    final completed = verification.completedVerifications.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildIdentityPedestal(primaryColor),
            const SizedBox(height: 8),
            Text(
              'Tap the camera to update your photo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 24),
            _sectionHeader('Public info', 'What others see on your profile'),
            const SizedBox(height: 12),
            _buildRecessedInput(
              controller: _displayNameController,
              label: 'Display name',
              hint: 'Your public name',
              icon: Icons.badge_outlined,
              validator: (v) => v!.trim().isEmpty ? 'Display name is required' : null,
            ),
            const SizedBox(height: 16),
            _buildRecessedInput(
              controller: _bioController,
              label: 'Bio',
              hint: 'Tell the community about yourself…',
              icon: Icons.notes_rounded,
              maxLines: 4,
              maxLength: _bioMaxLength,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_bioController.text.length}/$_bioMaxLength',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionHeader('Contact', 'Used for security and withdrawals'),
            const SizedBox(height: 12),
            _buildRecessedInput(
              controller: _phoneController,
              label: 'Phone number',
              hint: '+234…',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _buildVerificationStatusCard(primaryColor, verification, completed),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationStatusCard(
    Color primaryColor,
    VerificationStatus verification,
    int completedSteps,
  ) {
    final isVerified = verification.status == VerificationStatusType.verified;
    final scheme = Theme.of(context).colorScheme;
    return ShadowCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 14,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isVerified ? AppTheme.successColor : primaryColor)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isVerified ? Icons.verified_rounded : Icons.verified_user_outlined,
              color: isVerified ? AppTheme.successColor : primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVerified ? 'Account verified' : 'Verification in progress',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  isVerified
                      ? 'You have full access to wallet features'
                      : '$completedSteps steps completed — continue verification',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final updated = await GuardedNavigator.push(context,
                MaterialPageRoute(
                  builder: (_) => VerificationScreen(userProfile: widget.userProfile),
                ),
              );
              if (updated is UserProfile && mounted) {
                Navigator.pop(context, true);
              }
            },
            child: Text(isVerified ? 'View' : 'Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityPedestal(Color primaryColor) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _build3DContainer(
          radius: 100,
          padding: const EdgeInsets.all(8),
          child: FutureBuilder<String?>(
            future: MediaResolver.resolveUrl(_avatarUrl),
            builder: (context, snapshot) {
              final resolved = snapshot.data;
              ImageProvider? provider;
              if (_avatarBytes != null) provider = MemoryImage(_avatarBytes!);
              else if (resolved != null) provider = NetworkImage(resolved);
              
              return CircleAvatar(
                radius: 60,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                backgroundImage: provider,
                child: provider == null
                    ? Text(
                        widget.userProfile.initials,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      )
                    : null,
              );
            },
          ),
        ),
        if (_isLoading) const BybataLoadingIndicator(size: BybataLoadingSize.compact),
        Positioned(
          bottom: 0, right: 0,
          child: GestureDetector(
            onTap: _isLoading ? null : _changeProfilePicture,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 3,
                ),
              ),
              child: Icon(
                Icons.camera_alt,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountTab(Color primaryColor) {
    final emailVerified = widget.userProfile.verification.isStepComplete(VerificationType.email);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader('Sign-in details', 'Email and account identifiers'),
          const SizedBox(height: 12),
          _buildRecessedInput(
            controller: _emailController,
            label: 'Email',
            hint: '',
            icon: Icons.email_outlined,
            readOnly: true,
            suffix: emailVerified
                ? Icon(Icons.verified_rounded, color: AppTheme.successColor, size: 20)
                : null,
          ),
          const SizedBox(height: 16),
          _buildRecessedInput(
            controller: _userIdController,
            label: 'User ID',
            hint: '',
            icon: Icons.fingerprint,
            readOnly: true,
            suffix: IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _userIdController.text));
                AppToast.success(context, 'User ID copied');
              },
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader('Security & privacy', 'Manage access and visibility'),
          const SizedBox(height: 12),
          _build3DActionTile(
            'Change password',
            'Update your login password',
            Icons.lock_outline_rounded,
            primaryColor,
            () {
              GuardedNavigator.push(context,
                MaterialPageRoute(
                  builder: (context) => const ForgotPasswordScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _build3DActionTile(
            'Privacy settings',
            'Control who sees your profile info',
            Icons.privacy_tip_outlined,
            AppTheme.communityColor,
            _showPrivacySettingsDialog,
          ),
          const SizedBox(height: 12),
          _build3DActionTile(
            'Delete account',
            'Permanently remove your account',
            Icons.delete_forever_outlined,
            Theme.of(context).colorScheme.error,
            _showDeleteAccountDialog,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _build3DActionTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: _build3DContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
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
                      color: isDestructive
                          ? color
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  // --- ACTIONS (PRESERVED) ---
  void _schedulePickAfterDismiss(ImageSource source) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _pickAndUpload(source);
      });
    });
  }

  void _pickAfterModalDismiss(BuildContext modalContext, ImageSource source) {
    Navigator.pop(modalContext);
    _schedulePickAfterDismiss(source);
  }

  Future<void> _changeProfilePicture() async {
    final scheme = Theme.of(context).colorScheme;

    // Use same Material bottom sheet on both platforms - pop first, then open picker after delay.
    // useRootNavigator helps iOS present the picker correctly after the sheet dismisses.
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Change profile photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                _buildPhotoOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  subtitle: 'Take a new photo',
                  onTap: () => _pickAfterModalDismiss(ctx, ImageSource.camera),
                ),
                const SizedBox(height: 12),
                _buildPhotoOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  subtitle: 'Choose from library',
                  onTap: () => _pickAfterModalDismiss(ctx, ImageSource.gallery),
                ),
                if (_avatarUrl != null) ...[
                  const SizedBox(height: 12),
                  _buildPhotoOption(
                    icon: Icons.delete_outline_rounded,
                    label: 'Remove photo',
                    subtitle: 'Use default avatar',
                    iconColor: scheme.error,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await Future.delayed(const Duration(milliseconds: 300));
                      if (mounted) _removeAvatar();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final color = iconColor ?? scheme.primary;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurface.withValues(alpha: 0.4),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    if (!Platform.isIOS) {
      final granted = source == ImageSource.camera
          ? await PermissionsHelper.requestCameraWithFallback(
              context,
              purpose: 'take a profile photo',
            )
          : await PermissionsHelper.requestPhotoLibraryWithFallback(
              context,
              purpose: 'choose a profile photo',
            );
      if (!granted) return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
      requestFullMetadata: Platform.isIOS && source == ImageSource.gallery ? false : true,
    );
    if (picked == null) return;
    setState(() => _isLoading = true);
    try {
      final base = await EnvConfig.getBaseUrl();
      final client = ApiClient(base, const FlutterSecureStorage());
      final storage = StorageRepository(client.dio);
      final bytes = await picked.readAsBytes();
      final ext = _inferExt(picked.path);
      final contentType = _inferContentType(ext);
      final signed = await storage.createUploadUrl(
        domain: 'profiles',
        ext: ext,
        contentType: contentType,
      );
      final uploadUrl = signed['uploadUrl'] as String?;
      final key = signed['key'] as String?;
      if (uploadUrl == null || key == null) {
        throw Exception('Upload URL missing from server');
      }
      await storage.uploadToSignedUrl(
        uploadUrl: uploadUrl,
        bytes: bytes,
        contentType: contentType,
      );
      await ProfileRepository(client.dio).updateMe(avatarKey: key);
      if (mounted) {
        setState(() {
          _avatarBytes = bytes;
          _avatarUrl = key;
        });
        await context.read<AuthProvider>().refreshUserData();
        AppToast.success(context, 'Profile photo updated');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          NetworkErrorMessage.from(
            e,
            fallback: 'Could not upload profile photo. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _inferExt(String p) {
    final dot = p.lastIndexOf('.');
    if (dot < 0 || dot >= p.length - 1) return 'jpg';
    final ext = p.substring(dot + 1).toLowerCase();
    if (ext == 'jpeg' || ext == 'heic' || ext == 'heif') return 'jpg';
    if (ext == 'png') return 'png';
    return 'jpg';
  }

  String _inferContentType(String ext) =>
      ext == 'png' ? 'image/png' : 'image/jpeg';

  Future<void> _removeAvatar() async {
    setState(() => _isLoading = true);
    try {
      final base = await EnvConfig.getBaseUrl();
      await ProfileRepository(ApiClient(base, const FlutterSecureStorage()).dio).updateMe(clearAvatar: true);
      if (mounted) {
        setState(() { _avatarBytes = null; _avatarUrl = null; });
        await context.read<AuthProvider>().refreshUserData();
      }
    } catch (_) {} finally { if (mounted) setState(() => _isLoading = false); }
  }

  void _showDeleteAccountDialog() {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Delete Account?"), content: const Text("This cannot be undone."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () {
            Navigator.pop(c);
            _deleteAccount();
          },
          child: const Text("Delete"),
        ),
      ],
    ));
  }

  void _showPrivacySettingsDialog() {
    var settings = _settings;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> savePrivacy() async {
              try {
                final base = await EnvConfig.getBaseUrl();
                final client = ApiClient(base, const FlutterSecureStorage());
                await ProfileRepository(client.dio).updatePrivacySettings(
                  isProfilePublic: settings.isProfilePublic,
                  showEmail: settings.showEmail,
                  showPhone: settings.showPhone,
                  showLocation: settings.showLocation,
                  allowDirectMessages: settings.allowDirectMessages,
                );
                if (mounted) {
                  setState(() => _settings = settings);
                  AppToast.success(context, 'Privacy settings updated');
                }
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  AppToast.error(
                    ctx,
                    NetworkErrorMessage.from(
                      e,
                      fallback: 'Could not update privacy settings. Please try again.',
                    ),
                  );
                }
              }
            }

            Widget toggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
              return SwitchListTile(
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
                value: value,
                onChanged: onChanged,
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Privacy settings',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  toggle(
                    'Public profile',
                    'Allow others to view your profile',
                    settings.isProfilePublic,
                    (v) => setModalState(() => settings = settings.copyWith(isProfilePublic: v)),
                  ),
                  toggle(
                    'Show email',
                    'Display email on your public profile',
                    settings.showEmail,
                    (v) => setModalState(() => settings = settings.copyWith(showEmail: v)),
                  ),
                  toggle(
                    'Show phone',
                    'Display phone on your public profile',
                    settings.showPhone,
                    (v) => setModalState(() => settings = settings.copyWith(showPhone: v)),
                  ),
                  toggle(
                    'Show location',
                    'Display location on your profile',
                    settings.showLocation,
                    (v) => setModalState(() => settings = settings.copyWith(showLocation: v)),
                  ),
                  toggle(
                    'Direct messages',
                    'Let others message you directly',
                    settings.allowDirectMessages,
                    (v) => setModalState(() => settings = settings.copyWith(allowDirectMessages: v)),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: savePrivacy,
                    child: const Text('Save privacy settings'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    setState(() => _isLoading = true);
    try {
      final base = await EnvConfig.getBaseUrl();
      final client = ApiClient(base, const FlutterSecureStorage());
      await ProfileRepository(client.dio).deleteAccount();
      if (mounted) {
        await context.read<AuthProvider>().signOut();
        AppToast.info(context, 'Account deleted');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to delete account: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}