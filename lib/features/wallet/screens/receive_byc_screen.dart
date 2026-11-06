import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bybata/core/widgets/app_toast.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/share_utils.dart';
import '../../../core/widgets/share_sheet.dart';
import '../services/wallet_api.dart';
import 'transfer_byc_screen.dart';
import 'widgets/scan_qr_screen.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

enum _ReceiveView { qr, address }

enum _RequestMode { anyAmount, specificAmount }

class ReceiveBYCScreen extends StatefulWidget {
  const ReceiveBYCScreen({super.key});

  @override
  State<ReceiveBYCScreen> createState() => _ReceiveBYCScreenState();
}

class _ReceiveBYCScreenState extends State<ReceiveBYCScreen>
    with TickerProviderStateMixin {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final GlobalKey _qrRepaintKey = GlobalKey();

  late AnimationController _orbController;
  late Animation<double> _orbAnimation;

  _ReceiveView _view = _ReceiveView.qr;
  _RequestMode _requestMode = _RequestMode.anyAmount;

  double _requestedAmount = 0;
  String _note = '';
  bool _isLoadingProfile = true;
  bool _isLoadingQr = false;

  String _walletAddress = '';
  String? _qrCode;
  String _displayName = '';
  String _email = '';
  String _username = '';

  Timer? _qrDebounce;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _orbAnimation = CurvedAnimation(parent: _orbController, curve: Curves.easeInOut);
    _loadAddress();
  }

  @override
  void dispose() {
    _qrDebounce?.cancel();
    _amountController.dispose();
    _noteController.dispose();
    _orbController.dispose();
    super.dispose();
  }

  bool get _isSpecificRequest => _requestMode == _RequestMode.specificAmount;

  Future<void> _loadAddress() async {
    setState(() => _isLoadingProfile = true);
    try {
      final api = await WalletApi.create();
      final addrRes = await api.getWalletAddress();
      final meRes = await api.getMe();
      final profile = (meRes['profile'] as Map?) ?? {};
      final email = (meRes['email'] as String?) ?? '';
      final name =
          (profile['displayName'] as String?) ?? (email.split('@').first);
      if (!mounted) return;
      setState(() {
        _walletAddress = (addrRes['address'] as String?) ?? '';
        _email = email;
        _displayName = name;
        _username = email.isNotEmpty ? '@${email.split('@').first}' : '';
        _isLoadingProfile = false;
      });
      await _createQr();
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
        AppToast.error(context, 'Failed to load wallet address');
      }
    }
  }

  void _scheduleQrUpdate() {
    _qrDebounce?.cancel();
    _qrDebounce = Timer(const Duration(milliseconds: 450), _createQr);
  }

  Future<void> _createQr() async {
    if (!mounted) return;
    setState(() => _isLoadingQr = true);
    try {
      final api = await WalletApi.create();
      final res = await api.createReceiveQr(
        amount: _isSpecificRequest && _requestedAmount > 0
            ? _requestedAmount
            : null,
        note: _isSpecificRequest && _note.isNotEmpty ? _note : null,
      );
      if (!mounted) return;
      if (res['ok'] == true) {
        setState(() {
          _qrCode = (res['qrCode'] ?? res['uri']) as String?;
          _isLoadingQr = false;
        });
      } else {
        setState(() => _isLoadingQr = false);
        AppToast.error(context, 'Failed to generate QR');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingQr = false);
      AppToast.error(context, _qrErrorMessage(e));
    }
  }

  String _qrErrorMessage(Object e) {
    if (e is DioException && e.response?.statusCode == 429) {
      final retryAfter = e.response?.data is Map
          ? (e.response!.data as Map)['retryAfter'] as int?
          : null;
      if (retryAfter != null && retryAfter > 0) {
        return 'Too many requests. Please wait $retryAfter seconds.';
      }
      return 'Too many requests. Please wait a moment.';
    }
    if (e is DioException) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        return responseData['message'] as String;
      }
      final statusCode = e.response?.statusCode;
      if (statusCode == 401) return 'Session expired. Please log in again.';
      if (statusCode == 400) {
        return 'Invalid request. Please check your input.';
      }
      if (statusCode == 403) return 'Permission denied.';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return 'Request timed out. Check your connection.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Network error. Check your connection.';
      }
    }
    return 'Failed to generate QR';
  }

  String _generateQRData() => _qrCode ?? 'byc:$_walletAddress';

  void _setRequestMode(_RequestMode mode) {
    if (_requestMode == mode) return;
    setState(() {
      _requestMode = mode;
      if (mode == _RequestMode.anyAmount) {
        _requestedAmount = 0;
        _note = '';
        _amountController.clear();
        _noteController.clear();
      }
    });
    _createQr();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FA);
    final orbOpacity = isDark ? 0.25 : 0.12;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: _buildGlassAppBar(isDark),
      body: Stack(
        children: [
          _buildAmbientOrbs(primaryColor, orbOpacity, isDark),
          SafeArea(
            child: Column(
              children: [
                _buildViewSelector(primaryColor, isDark),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _view == _ReceiveView.qr
                        ? _buildQrView(primaryColor, isDark)
                        : _buildAddressView(primaryColor, isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientOrbs(Color primaryColor, double orbOpacity, bool isDark) {
    return Stack(
      children: [
        Positioned(
          top: MediaQuery.of(context).size.height * 0.08,
          right: -100,
          child: AnimatedBuilder(
            animation: _orbAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 30 * _orbAnimation.value),
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(alpha: orbOpacity),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: orbOpacity + 0.05),
                        blurRadius: 120,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.15,
          left: -80,
          child: AnimatedBuilder(
            animation: _orbAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -30 * _orbAnimation.value),
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryMuted.withValues(alpha: orbOpacity - 0.05),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryMuted.withValues(alpha: orbOpacity),
                        blurRadius: 90,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildGlassAppBar(bool isDark) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AppBar(
            backgroundColor: isDark
                ? const Color(0xFF1A1A1A).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.6),
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : Colors.black87,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Receive BYC',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.info_outline_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                  size: 24,
                ),
                onPressed: _showReceiveInfo,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewSelector(Color primaryColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            _viewChip(
              label: 'QR Code',
              icon: Icons.qr_code_2_rounded,
              selected: _view == _ReceiveView.qr,
              primaryColor: primaryColor,
              isDark: isDark,
              onTap: () => setState(() => _view = _ReceiveView.qr),
            ),
            _viewChip(
              label: 'Address',
              icon: Icons.account_balance_wallet_outlined,
              selected: _view == _ReceiveView.address,
              primaryColor: primaryColor,
              isDark: isDark,
              onTap: () => setState(() => _view = _ReceiveView.address),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Color primaryColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? primaryColor : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected && !isDark
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
                color: selected
                    ? (isDark ? Colors.white : primaryColor)
                    : (isDark ? Colors.grey[500] : Colors.grey[600]),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 14,
                  color: selected
                      ? (isDark ? Colors.white : primaryColor)
                      : (isDark ? Colors.grey[500] : Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrView(Color primaryColor, bool isDark) {
    return SingleChildScrollView(
      key: const ValueKey('qr_view'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildUnifiedReceiveCard(primaryColor, isDark),
          const SizedBox(height: 16),
          _buildRequestModeSection(primaryColor, isDark),
          const SizedBox(height: 16),
          _buildQuickActions(primaryColor, isDark),
          const SizedBox(height: 12),
          _buildHowToReceive(isDark),
        ],
      ),
    );
  }

  Widget _buildUnifiedReceiveCard(Color primaryColor, bool isDark) {
    return _glassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildProfileRow(primaryColor, isDark),
          const SizedBox(height: 20),
          _buildQrDisplay(primaryColor, isDark),
          const SizedBox(height: 16),
          if (_isSpecificRequest && _requestedAmount > 0)
            _buildRequestSummary(primaryColor, isDark),
          const SizedBox(height: 8),
          Text(
            'Scan to send BYC instantly',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(Color primaryColor, bool isDark) {
    if (_isLoadingProfile) {
      return Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.grey[200],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 120,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: primaryColor.withValues(alpha: isDark ? 0.25 : 0.12),
          child: Text(
            (_displayName.isNotEmpty ? _displayName[0] : 'U').toUpperCase(),
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _displayName.isNotEmpty ? _displayName : 'Your wallet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                _username.isNotEmpty ? _username : _email,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQrDisplay(Color primaryColor, bool isDark) {
    final qrData = _generateQRData();
    final hasData = qrData.isNotEmpty && _walletAddress.isNotEmpty;

    return RepaintBoundary(
      key: _qrRepaintKey,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (hasData)
              QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              )
            else
              SizedBox(
                width: 200,
                height: 200,
                child: Center(
                  child: Icon(
                    Icons.qr_code_2_rounded,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                ),
              ),
            if (_isLoadingQr)
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestSummary(Color primaryColor, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Requesting',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              Text(
                '${_requestedAmount.toStringAsFixed(2)} BYC',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          if (_note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _note,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestModeSection(Color primaryColor, bool isDark) {
    return _glassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment request',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose how senders should pay you',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _requestModeOption(
                  mode: _RequestMode.anyAmount,
                  title: 'Any amount',
                  subtitle: 'Open receive',
                  icon: Icons.all_inclusive_rounded,
                  primaryColor: primaryColor,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _requestModeOption(
                  mode: _RequestMode.specificAmount,
                  title: 'Set amount',
                  subtitle: 'Request BYC',
                  icon: Icons.payments_outlined,
                  primaryColor: primaryColor,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _isSpecificRequest
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                children: [
                  _inputField(
                    controller: _amountController,
                    label: 'Amount (BYC)',
                    hint: '0.00',
                    icon: Icons.monetization_on_outlined,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    isDark: isDark,
                    primaryColor: primaryColor,
                    onChanged: (value) {
                      setState(() => _requestedAmount = double.tryParse(value) ?? 0);
                      _scheduleQrUpdate();
                    },
                  ),
                  const SizedBox(height: 12),
                  _inputField(
                    controller: _noteController,
                    label: 'Note (optional)',
                    hint: 'What is this for?',
                    icon: Icons.notes_rounded,
                    maxLines: 2,
                    isDark: isDark,
                    primaryColor: primaryColor,
                    onChanged: (value) {
                      setState(() => _note = value);
                      _scheduleQrUpdate();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestModeOption({
    required _RequestMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color primaryColor,
    required bool isDark,
  }) {
    final selected = _requestMode == mode;
    return GestureDetector(
      onTap: () => _setRequestMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? primaryColor.withValues(alpha: isDark ? 0.22 : 0.1)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.grey.withValues(alpha: 0.06)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? primaryColor.withValues(alpha: 0.7)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.withValues(alpha: 0.15)),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? primaryColor
                          : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
                      width: 2,
                    ),
                    color: selected ? primaryColor : Colors.transparent,
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 11, color: Colors.white)
                      : null,
                ),
                const Spacer(),
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? primaryColor
                      : (isDark ? Colors.grey[500] : Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: selected
                    ? (isDark ? Colors.white : primaryColor)
                    : (isDark ? Colors.grey[300] : Colors.black87),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color primaryColor,
    TextInputType? keyboardType,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.12),
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            onChanged: onChanged,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[600] : Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(icon, color: primaryColor, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(Color primaryColor, bool isDark) {
    return _glassCard(
      isDark: isDark,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          _quickAction(
            label: 'Share',
            icon: Icons.ios_share_rounded,
            color: primaryColor,
            isDark: isDark,
            onTap: () => _shareQRCode(context),
          ),
          _quickAction(
            label: 'Copy',
            icon: Icons.link_rounded,
            color: AppColors.primaryMuted,
            isDark: isDark,
            onTap: () => _copyPaymentLink(context),
          ),
          _quickAction(
            label: 'Save',
            icon: Icons.download_rounded,
            color: AppColors.success,
            isDark: isDark,
            onTap: _saveQRCode,
          ),
          _quickAction(
            label: 'Scan',
            icon: Icons.qr_code_scanner_rounded,
            color: isDark ? Colors.white : Colors.black87,
            isDark: isDark,
            onTap: _scanQr,
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: isDark ? Colors.white : color),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressView(Color primaryColor, bool isDark) {
    return SingleChildScrollView(
      key: const ValueKey('address_view'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _glassCard(
            isDark: isDark,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your BYC address',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Permanent · never changes',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.25)
                        : AppColors.primaryTintSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: SelectableText(
                    _walletAddress.isEmpty ? 'Loading…' : _walletAddress,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Monospace',
                      fontSize: 14,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copyAddress,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _shareAddressButton(context),
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('Share'),
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildHowToReceive(isDark),
        ],
      ),
    );
  }

  Widget _buildHowToReceive(bool isDark) {
    return _glassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How it works',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          _stepRow('1', 'Share your QR or address', isDark),
          _stepRow('2', 'Sender confirms the amount', isDark),
          _stepRow('3', 'You get notified instantly', isDark, isLast: true),
        ],
      ),
    );
  }

  Widget _stepRow(String step, String text, bool isDark, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: isDark ? Colors.white : AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    required bool isDark,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1E24).withValues(alpha: 0.72)
                  : Colors.white.withValues(alpha: 0.82),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white,
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  void _shareAddressButton(BuildContext ctx) {
    if (_walletAddress.isEmpty) {
      AppToast.error(ctx, 'Wallet address not ready yet');
      return;
    }
    ShareUtils.shareCustom(
      ctx,
      title: 'BYC Address',
      message: 'Send BYC to: $_walletAddress',
      link: 'byc:$_walletAddress',
      subject: 'BYC Address',
    );
  }

  Future<void> _shareQRCode(BuildContext ctx) async {
    final link = _generateQRData();
    final msg = _isSpecificRequest && _requestedAmount > 0
        ? 'Send $_requestedAmount BYC via: $link'
        : 'Send BYC via: $link';
    try {
      final boundary =
          _qrRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final dir = await getTemporaryDirectory();
          final file = File(
            '${dir.path}/BYC_QR_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          await file.writeAsBytes(byteData.buffer.asUint8List());
          await Share.shareXFiles(
            [XFile(file.path)],
            text: msg,
            subject: 'Payment Request',
          );
          return;
        }
      }
    } catch (_) {}
    if (!ctx.mounted) return;
    ShareSheet.show(
      ctx,
      title: 'Payment Request',
      message: msg,
      link: link,
      subject: 'Payment Request',
    );
  }

  void _copyPaymentLink(BuildContext ctx) {
    Clipboard.setData(ClipboardData(text: _generateQRData()));
    AppToast.success(ctx, 'Payment link copied');
  }

  Future<void> _saveQRCode() async {
    try {
      final boundary =
          _qrRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        AppToast.error(context, 'QR code not ready');
        return;
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        AppToast.error(context, 'Failed to capture QR');
        return;
      }
      final pngBytes = byteData.buffer.asUint8List();
      final result = await ImageGallerySaverPlus.saveImage(
        pngBytes,
        quality: 100,
        name: 'BYC_Receive_QR_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      if (result['isSuccess'] == true) {
        AppToast.success(context, 'QR code saved to gallery');
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File(
          '${dir.path}/BYC_Receive_QR_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(pngBytes);
        AppToast.success(context, 'QR saved to ${file.path}');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to save: ${e.toString()}');
      }
    }
  }

  void _copyAddress() {
    if (_walletAddress.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _walletAddress));
    AppToast.success(context, 'Address copied');
  }

  void _showReceiveInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Receiving BYC',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Your QR code and wallet address are unique to you and stay the same. '
          'Share either one so others can send you BYC instantly.',
          style: TextStyle(
            height: 1.5,
            color: isDark ? Colors.grey[300] : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _scanQr() {
    GuardedNavigator.push(context, 
      MaterialPageRoute(
        builder: (context) => ScanQRScreen(
          onResult: (code) async {
            if (!context.mounted) return;
            try {
              final api = await WalletApi.create();
              Map<String, dynamic> res = await api.validateQr(code: code);
              if (res['ok'] != true) res = await api.scanQRCode(code);
              if (!context.mounted) return;
              if (res['ok'] == true) {
                final recipient = res['recipient'] as Map<String, dynamic>?;
                final email = (recipient?['email'] as String?) ?? '';
                final userId = recipient?['userId'] as String?;
                final displayName = (recipient?['displayName'] as String?) ?? '';
                final amount = (res['amount'] as num?)?.toDouble();
                final memo = (res['note'] ?? res['memo']) as String?;
                if (userId == null || userId.isEmpty) {
                  AppToast.error(context, 'Invalid QR');
                  return;
                }
                if (!context.mounted) return;
                GuardedNavigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransferBYCScreen(
                      recipientEmail: email.isNotEmpty ? email : null,
                      recipientId: userId,
                      recipientName: displayName.isNotEmpty ? displayName : null,
                      initialAmount: amount,
                      initialMemo: memo,
                    ),
                  ),
                );
                AppToast.success(context, 'Recipient prefilled from QR');
              } else {
                AppToast.error(context, res['error'] as String? ?? 'Invalid QR');
              }
            } catch (_) {
              if (context.mounted) AppToast.error(context, 'Scan failed');
            }
          },
        ),
      ),
    );
  }
}
