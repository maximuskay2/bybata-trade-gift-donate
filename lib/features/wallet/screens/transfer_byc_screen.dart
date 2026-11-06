import 'dart:ui'; // For BackdropFilter
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/shadow_styles.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'widgets/scan_qr_screen.dart';
import '../services/wallet_api.dart';
import '../services/wallet_transaction_auth.dart';
import '../widgets/wallet_identity_gate.dart';
import '../../profile/services/verification_check_service.dart';
import 'package:provider/provider.dart';
import '../services/wallet_service.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class TransferBYCScreen extends StatefulWidget {
  final String? recipientId;
  final String? recipientEmail;
  final String? recipientName;
  final double? initialAmount;
  final String? initialMemo;
  
  const TransferBYCScreen({
    super.key,
    this.recipientId,
    this.recipientEmail,
    this.recipientName,
    this.initialAmount,
    this.initialMemo,
  });

  @override
  State<TransferBYCScreen> createState() => _TransferBYCScreenState();
}

class _TransferBYCScreenState extends State<TransferBYCScreen> with TickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _listFocus = FocusNode();

  // Animations
  late AnimationController _orbController;
  late Animation<double> _orbAnimation;

  double _transferAmount = 0.0;
  String _selectedRecipient = '';
  String? _recipientUserId; // Set from QR scan for reliable transfer
  bool _isProcessing = false;
  bool _isSearching = false;
  String? _searchError;
  List<Map<String, dynamic>> _results = [];
  int _focusedIndex = -1;
  Map<String, List<Map<String, dynamic>>> _cache = {};
  Timer? _debounce;
  bool _isCheckingSecurity = true;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    
    // Ambient Orb Animation
    _orbController = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 8)
    )..repeat(reverse: true);
    _orbAnimation = CurvedAnimation(parent: _orbController, curve: Curves.easeInOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSecurityAndPrefill();
    });
  }

  Future<void> _checkSecurityAndPrefill() async {
    final verified = await VerificationCheckService.isUserVerified();

    if (widget.recipientEmail != null && widget.recipientEmail!.isNotEmpty) {
      setState(() {
        _recipientController.text = widget.recipientEmail!;
        _selectedRecipient = widget.recipientEmail!;
        _recipientUserId = widget.recipientId;
      });
    } else if (widget.recipientId != null && widget.recipientId!.isNotEmpty) {
      setState(() {
        _recipientUserId = widget.recipientId;
        final label = widget.recipientName?.trim().isNotEmpty == true
            ? widget.recipientName!
            : 'BYC user';
        _recipientController.text = label;
        _selectedRecipient = label;
      });
    } else {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['email'] is String && _recipientController.text.isEmpty) {
        setState(() {
          _recipientController.text = args['email'] as String;
          _selectedRecipient = args['email'] as String;
        });
      } else if (args is Map && args['recipientEmail'] is String && _recipientController.text.isEmpty) {
        setState(() {
          _recipientController.text = args['recipientEmail'] as String;
          _selectedRecipient = args['recipientEmail'] as String;
        });
      }
    }

    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _amountController.text = widget.initialAmount!.toStringAsFixed(2);
      _transferAmount = widget.initialAmount!;
    }
    if (widget.initialMemo != null && widget.initialMemo!.trim().isNotEmpty) {
      _messageController.text = widget.initialMemo!.trim();
    }

    if (mounted) {
      setState(() {
        _isVerified = verified;
        _isCheckingSecurity = false;
      });
    }
  }

  Future<void> _refreshVerification() async {
    setState(() => _isCheckingSecurity = true);
    final verified = await VerificationCheckService.isUserVerified();
    if (mounted) {
      setState(() {
        _isVerified = verified;
        _isCheckingSecurity = false;
      });
    }
  }

  @override
  void dispose() {
    _orbController.dispose();
    _amountController.dispose();
    _recipientController.dispose();
    _messageController.dispose();
    _debounce?.cancel();
    _searchFocus.dispose();
    _listFocus.dispose();
    super.dispose();
  }

  // --- LOGIC PRESERVATION ---
  void _onSearchChanged(String value) async {
    setState(() {
      _selectedRecipient = value;
      _recipientUserId = null; 
      _searchError = null;
    });
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
        _focusedIndex = -1;
      });
      return;
    }
    final key = value.toLowerCase();
    if (_cache.containsKey(key)) {
      setState(() {
        _results = _cache[key]!;
        _focusedIndex = _results.isNotEmpty ? 0 : -1;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() {
        _isSearching = true;
      });
      try {
        final api = await WalletApi.create();
        final res = await api.searchUsers(q: value, page: 1, size: 10);
        final items = (res['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _cache[key] = items;
        setState(() {
          _results = items;
          _focusedIndex = items.isNotEmpty ? 0 : -1;
        });
      } catch (e) {
        setState(() {
          _searchError = 'Search failed';
        });
      } finally {
        setState(() {
          _isSearching = false;
        });
      }
    });
  }

  void _applySelection(String email) {
    setState(() {
      _recipientController.text = email;
      _selectedRecipient = email;
      _recipientUserId = null; 
      _results = [];
      _focusedIndex = -1;
    });
  }

  void _scanQR() {
    GuardedNavigator.push(context, 
      MaterialPageRoute(
        builder: (ctx) => ScanQRScreen(
          onResult: (code) async {
            try {
              final api = await WalletApi.create();
              Map<String, dynamic> res = await api.validateQr(code: code);
              if (res['ok'] != true) {
                res = await api.scanQRCode(code);
              }
              if (res['ok'] == true) {
                final recipient = res['recipient'] as Map<String, dynamic>?;
                final email = (recipient?['email'] as String?) ?? '';
                final userId = recipient?['userId'] as String?;
                final displayName = (recipient?['displayName'] as String?) ?? '';
                final amount = (res['amount'] as num?)?.toDouble();
                final note = (res['note'] ?? res['memo']) as String?;
                if (!mounted) return;
                setState(() {
                  _recipientUserId = userId;
                  if (email.isNotEmpty) {
                    _recipientController.text = email;
                    _selectedRecipient = email;
                  } else if (displayName.isNotEmpty) {
                    _recipientController.text = displayName;
                    _selectedRecipient = displayName;
                  } else if (userId != null) {
                    _recipientController.text = 'BYC user';
                    _selectedRecipient = 'BYC user';
                  }
                  if (amount != null && amount > 0) {
                    _amountController.text = amount.toStringAsFixed(2);
                    _transferAmount = amount;
                  }
                  if (note != null && note.isNotEmpty) {
                    _messageController.text = note;
                  }
                });
                AppToast.info(context, 'Recipient prefilled from QR');
              } else {
                AppToast.error(context, res['error'] as String? ?? 'Invalid QR');
              }
            } catch (e) {
              AppToast.error(context, 'QR validation failed');
            }
          },
        ),
      ),
    );
  }

  Future<void> _handleSend() async {
    if (_isProcessing) return;

    if (!_isVerified) {
      AppToast.warning(context, 'Complete identity verification to send BYC');
      return;
    }

    final toEmail = _recipientController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final hasRecipient = (_recipientUserId != null && _recipientUserId!.isNotEmpty) ||
        toEmail.isNotEmpty;
    if (!hasRecipient || amount <= 0) {
      AppToast.warning(context, 'Please enter recipient and amount');
      return;
    }

    try {
      final auth = await WalletTransactionAuth.request(
        context,
        biometricReason: 'Authenticate to send BYC',
      );
      if (auth == null) {
        if (mounted) AppToast.warning(context, 'Authentication cancelled');
        return;
      }

      if (!mounted) return;
      setState(() => _isProcessing = true);

      try {
        final api = await WalletApi.create();
        final idem = 'transfer-${DateTime.now().millisecondsSinceEpoch}';
        final skipAuth = WalletTransactionAuth.isSkipped(auth);
        await api.transfer(
          toUserId: _recipientUserId,
          toEmail: _recipientUserId == null ? toEmail : null,
          amountByc: amount,
          memo: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
          idempotencyKey: idem,
          verificationMethod: skipAuth ? null : auth.method,
          verificationCredential: skipAuth ? null : auth.credential,
        );
        try {
          await WalletService().refreshFromServer();
        } catch (_) {}
        if (mounted) {
          AppToast.success(context, 'Transfer sent successfully');
          Navigator.of(context).maybePop();
        }
      } catch (e) {
        if (mounted) {
          String msg = 'Transfer failed';
          if (e is DioException && e.response?.data != null) {
            final data = e.response!.data;
            if (data is Map) {
              final m = data['message'];
              if (m is String && m.isNotEmpty) {
                msg = m;
              } else if (m is List && m.isNotEmpty) {
                msg = m.first.toString();
              }
            }
          } else {
            final s = e.toString();
            if (s.contains('Identity verification') ||
                s.contains('Recipient not found') ||
                s.contains('Invalid PIN') ||
                s.contains('Session expired')) {
              msg = s.replaceFirst(RegExp(r'^.*?Exception:?\s*'), '').split('\n').first.trim();
            } else if (s.length <= 80) {
              msg = s;
            }
          }
          AppToast.error(context, msg);
        }
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Something went wrong');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showTransferInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Transfer Info', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Transfers are instant and free', style: TextStyle(height: 1.5, color: isDark ? Colors.grey[300] : Colors.black87)),
            Text('• You can send BYC to any bYbata user', style: TextStyle(height: 1.5, color: isDark ? Colors.grey[300] : Colors.black87)),
            Text('• Transfers cannot be reversed once sent', style: TextStyle(height: 1.5, color: isDark ? Colors.grey[300] : Colors.black87)),
            Text('• Recipients will be notified immediately', style: TextStyle(height: 1.5, color: isDark ? Colors.grey[300] : Colors.black87)),
            Text('• Include a message to personalize your transfer', style: TextStyle(height: 1.5, color: isDark ? Colors.grey[300] : Colors.black87)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  // --- 3D GLASS UI COMPONENTS ---

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding, required bool isDark}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding ?? const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24).withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.7),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.9), width: 1.5),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _build3DInput({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    Widget? suffix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, color: isDark ? Colors.grey[400] : Colors.grey[600]) : null,
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400], fontWeight: FontWeight.normal),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildGlassAppBar(bool isDark) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AppBar(
            backgroundColor: isDark ? const Color(0xFF1A1A1A).withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.6),
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Send BYC',
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.info_outline_rounded, color: isDark ? Colors.white : Colors.black87, size: 24),
                onPressed: _showTransferInfo,
              ),
            ],
          ),
        ),
      ),
    );
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
          // Ambient Background Orbs
          Positioned(
            top: MediaQuery.of(context).size.height * 0.1, right: -100,
            child: AnimatedBuilder(
              animation: _orbAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * _orbAnimation.value),
                  child: Container(
                    width: 350, height: 350,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withValues(alpha: orbOpacity),
                      boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: orbOpacity + 0.05), blurRadius: 120)],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.2, left: -80,
            child: AnimatedBuilder(
              animation: _orbAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -30 * _orbAnimation.value),
                  child: Container(
                    width: 250, height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: orbOpacity - 0.05),
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: orbOpacity), blurRadius: 90)],
                    ),
                  ),
                );
              },
            ),
          ),

          // Main Content
          _isCheckingSecurity
              ? Center(child: BybataLoadingIndicator(color: primaryColor))
              : !_isVerified
                  ? WalletIdentityGate(
                      title: 'Verification Required',
                      message:
                          'Complete identity verification before sending BYC to other users. You can still receive BYC and fund your wallet.',
                      primaryColor: primaryColor,
                      isDark: isDark,
                      onVerificationChanged: _refreshVerification,
                    )
                  : SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildBalanceHeader(primaryColor, isDark),
                        const SizedBox(height: 24),
                        _buildTransferForm(primaryColor, isDark),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildBalanceHeader(Color primaryColor, bool isDark) {
    return _buildGlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primaryColor.withValues(alpha: 0.3), primaryColor.withValues(alpha: 0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white, width: 2),
            ),
            child: Icon(Icons.account_balance_wallet_rounded, color: primaryColor, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Available Balance', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(
                  '${(WalletService().currentBalance?.availableBalance ?? 0.0).toStringAsFixed(2)} BYC',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: -1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferForm(Color primaryColor, bool isDark) {
    return _buildGlassCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Recipient", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          _build3DInput(
            isDark: isDark,
            controller: _recipientController,
            focusNode: _searchFocus,
            hint: "Username or Email",
            icon: Icons.person_search_rounded,
            onChanged: _onSearchChanged,
            onSubmitted: (value) {
              if (_focusedIndex >= 0 && _focusedIndex < _results.length) {
                _applySelection(_results[_focusedIndex]['email'] as String? ?? '');
              } else {
                _applySelection(value);
              }
            },
            suffix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSearching) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                IconButton(icon: Icon(Icons.qr_code_scanner_rounded, color: primaryColor), onPressed: _scanQR),
                if (_recipientController.text.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.clear_rounded, color: isDark ? Colors.grey[400] : Colors.grey[500]), 
                    onPressed: () {
                      setState(() { _recipientController.clear(); _selectedRecipient = ''; _recipientUserId = null; _results = []; _searchError = null; _focusedIndex = -1; });
                    }
                  ),
              ],
            ),
          ),
          
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 4),
              child: Text(_searchError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
            ),

          if (_results.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E24).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.9), 
                borderRadius: BorderRadius.circular(16), 
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white, width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              constraints: const BoxConstraints(maxHeight: 220),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: RawKeyboardListener(
                  focusNode: _listFocus,
                  onKey: (event) {
                    if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) setState(() => _focusedIndex = (_focusedIndex + 1).clamp(0, _results.length - 1));
                    else if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) setState(() => _focusedIndex = (_focusedIndex - 1).clamp(0, _results.length - 1));
                    else if (event.isKeyPressed(LogicalKeyboardKey.enter)) { if (_focusedIndex >= 0 && _focusedIndex < _results.length) _applySelection(_results[_focusedIndex]['email'] as String? ?? ''); }
                  },
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.2)),
                    itemBuilder: (context, index) {
                      final u = _results[index];
                      final isSelected = index == _focusedIndex;
                      return Container(
                        color: isSelected ? primaryColor.withValues(alpha: isDark ? 0.2 : 0.1) : Colors.transparent,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: CircleAvatar(backgroundColor: primaryColor.withValues(alpha: 0.15), child: Icon(Icons.person, color: primaryColor, size: 20)),
                          title: Text(u['displayName']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                          subtitle: Text(u['email']?.toString() ?? '', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
                          onTap: () => _applySelection(u['email'] as String? ?? ''),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            
          const SizedBox(height: 24),
          Text("Amount", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          _build3DInput(
            isDark: isDark,
            controller: _amountController,
            hint: "0.00",
            icon: Icons.attach_money_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          ),
          
          const SizedBox(height: 24),
          Text("Message (Optional)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          _build3DInput(
            isDark: isDark,
            controller: _messageController,
            hint: "What's this for?",
            icon: Icons.notes_rounded,
          ),

          const SizedBox(height: 32),
          
          // Action Button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primaryColor, primaryColor.withValues(alpha: 0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _handleSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isProcessing 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Send BYC", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      SizedBox(width: 8),
                      Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}