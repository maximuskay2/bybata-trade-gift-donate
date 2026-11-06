import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/theme/app_theme.dart';
import '../models/support_ticket.dart';
import '../services/support_api.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';

/// Branded intro before opening the emergency ticket form.
class EmergencySupportIntroSheet extends StatelessWidget {
  final VoidCallback onContinue;

  const EmergencySupportIntroSheet({super.key, required this.onContinue});

  static Future<void> show(BuildContext context, {required VoidCallback onContinue}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EmergencySupportIntroSheet(onContinue: onContinue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFFEF4444);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.2),
              blurRadius: 28,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: isDark ? 0.28 : 0.14),
                      accent.withValues(alpha: isDark ? 0.08 : 0.04),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: accent.withValues(alpha: 0.35)),
                      ),
                      child: const Icon(Icons.emergency_rounded, color: accent, size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Emergency Support',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'For urgent security, fraud, or safety issues. Our team prioritises these requests.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  children: const [
                    _EmergencyTopicRow(
                      icon: Icons.security_rounded,
                      text: 'Account security breaches',
                    ),
                    _EmergencyTopicRow(
                      icon: Icons.warning_amber_rounded,
                      text: 'Safety concerns',
                    ),
                    _EmergencyTopicRow(
                      icon: Icons.gpp_bad_rounded,
                      text: 'Fraudulent activity',
                    ),
                    _EmergencyTopicRow(
                      icon: Icons.build_circle_outlined,
                      text: 'Critical technical emergencies',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Not now'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onContinue();
                        },
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('Continue'),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyTopicRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmergencyTopicRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFEF4444)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CreateSupportTicketSheet extends StatefulWidget {
  final bool isBugReport;
  final bool isEmergency;
  final VoidCallback? onCreated;

  const CreateSupportTicketSheet({
    super.key,
    this.isBugReport = false,
    this.isEmergency = false,
    this.onCreated,
  });

  /// Bottom-anchored sheet — keyboard lifts the sheet smoothly without jumping fields.
  static Future<void> show(
    BuildContext context, {
    bool isBugReport = false,
    bool isEmergency = false,
    VoidCallback? onCreated,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: !isEmergency,
      enableDrag: !isEmergency,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateSupportTicketSheet(
        isBugReport: isBugReport,
        isEmergency: isEmergency,
        onCreated: onCreated,
      ),
    );
  }

  @override
  State<CreateSupportTicketSheet> createState() => _CreateSupportTicketSheetState();
}

class _CreateSupportTicketSheetState extends State<CreateSupportTicketSheet> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subjectFocus = FocusNode();
  final _descriptionFocus = FocusNode();
  String _category = 'General';
  String _priority = 'MEDIUM';
  bool _submitting = false;

  static const _categories = [
    ('General', Icons.help_outline_rounded),
    ('Account', Icons.person_outline_rounded),
    ('Trading', Icons.swap_horiz_rounded),
    ('Gifts', Icons.card_giftcard_rounded),
    ('Donations', Icons.favorite_outline_rounded),
    ('Wallet', Icons.account_balance_wallet_outlined),
    ('Technical', Icons.build_outlined),
    ('Security', Icons.security_rounded),
  ];

  static const _priorities = [
    ('LOW', 'Low', Color(0xFF10B981)),
    ('MEDIUM', 'Medium', AppColors.primary),
    ('HIGH', 'High', Color(0xFFF59E0B)),
    ('URGENT', 'Urgent', Color(0xFFEF4444)),
  ];

  Color get _accent {
    if (widget.isEmergency) return const Color(0xFFEF4444);
    if (widget.isBugReport) return const Color(0xFFF97316);
    return AppTheme.primaryColor;
  }

  String get _title {
    if (widget.isBugReport) return 'Report a bug';
    if (widget.isEmergency) return 'Emergency support';
    return 'Create ticket';
  }

  String get _subtitle {
    if (widget.isBugReport) {
      return 'Tell us what broke — we\'ll investigate and fix it.';
    }
    if (widget.isEmergency) {
      return 'Security, fraud, or urgent account issues. We prioritize these.';
    }
    return 'Describe your issue and our team will get back to you.';
  }

  IconData get _headerIcon {
    if (widget.isBugReport) return Icons.bug_report_rounded;
    if (widget.isEmergency) return Icons.emergency_rounded;
    return Icons.confirmation_number_outlined;
  }

  @override
  void initState() {
    super.initState();
    _subjectFocus.addListener(() => _ensureFieldVisible(_subjectFocus));
    _descriptionFocus.addListener(() => _ensureFieldVisible(_descriptionFocus));
  }

  void _ensureFieldVisible(FocusNode node) {
    if (!node.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted || !node.hasFocus) return;
      final ctx = node.context;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.25,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    _subjectFocus.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      const storage = FlutterSecureStorage();
      final api = SupportApi(ApiClient(await EnvConfig.getBaseUrl(), storage));
      if (widget.isBugReport) {
        await api.createBugReport(
          subject: _subjectController.text.trim(),
          description: _descriptionController.text.trim(),
          metadata: {'platform': Theme.of(context).platform.name},
        );
      } else {
        await api.createTicket(
          subject: _subjectController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _category,
          type: widget.isEmergency ? 'EMERGENCY' : 'SUPPORT',
          priority: widget.isEmergency ? 'URGENT' : _priority,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated?.call();
      AppToast.show(context, widget.isBugReport
                ? 'Bug report submitted — thank you!'
                : 'Ticket created — we\'ll be in touch soon',);
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Could not submit: $e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: maxLines > 1,
      prefixIcon: maxLines == 1
          ? Icon(icon, size: 20, color: _accent.withValues(alpha: 0.85))
          : null,
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _accent, width: 1.6),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: maxLines > 1 ? 16 : 14,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: sheetHeight,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: isDark ? 0.18 : 0.1),
              blurRadius: 32,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            children: [
              if (!widget.isEmergency) ...[
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
              _buildHeader(scheme, isDark),
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.isEmergency) _buildEmergencyBanner(),
                          TextFormField(
                            controller: _subjectController,
                            focusNode: _subjectFocus,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                FocusScope.of(context).requestFocus(_descriptionFocus),
                            decoration: _fieldDecoration(
                              label: 'Subject',
                              hint: 'Short summary of your issue',
                              icon: Icons.title_rounded,
                            ),
                            validator: (v) =>
                                (v == null || v.trim().length < 3) ? 'Add a brief subject' : null,
                          ),
                          const SizedBox(height: 16),
                          if (!widget.isBugReport) ...[
                            _sectionLabel('Category'),
                            const SizedBox(height: 10),
                            _buildCategoryGrid(),
                            const SizedBox(height: 18),
                            if (!widget.isEmergency) ...[
                              _sectionLabel('Priority'),
                              const SizedBox(height: 10),
                              _buildPriorityRow(),
                              const SizedBox(height: 18),
                            ],
                          ],
                          TextFormField(
                            controller: _descriptionController,
                            focusNode: _descriptionFocus,
                            maxLines: 5,
                            minLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.newline,
                            decoration: _fieldDecoration(
                              label: widget.isBugReport ? 'What happened?' : 'Details',
                              hint: widget.isBugReport
                                  ? 'Steps to reproduce, expected vs actual behaviour…'
                                  : 'Share as much detail as you can — screenshots help too.',
                              icon: Icons.notes_rounded,
                              maxLines: 5,
                            ),
                            validator: (v) => (v == null || v.trim().length < 10)
                                ? 'Please add a bit more detail (10+ characters)'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Typical response within a few hours on business days.',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _buildFooter(scheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme scheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent.withValues(alpha: isDark ? 0.22 : 0.12),
            _accent.withValues(alpha: isDark ? 0.06 : 0.03),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_headerIcon, color: _accent, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: scheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _submitting ? null : () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded, color: scheme.onSurface.withValues(alpha: 0.55)),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
      ),
      child: const Row(
        children: [
          Icon(Icons.priority_high_rounded, color: Color(0xFFEF4444), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Marked urgent — our team is notified immediately.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((entry) {
        final (label, icon) = entry;
        final selected = _category == label;
        return FilterChip(
          selected: selected,
          showCheckmark: false,
          avatar: Icon(
            icon,
            size: 16,
            color: selected ? _accent : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          label: Text(label),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? _accent : null,
          ),
          selectedColor: _accent.withValues(alpha: 0.14),
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          side: BorderSide(
            color: selected ? _accent.withValues(alpha: 0.5) : Colors.transparent,
          ),
          onSelected: (_) => setState(() => _category = label),
        );
      }).toList(),
    );
  }

  Widget _buildPriorityRow() {
    return Row(
      children: _priorities.map((entry) {
        final (value, label, color) = entry;
        final selected = _priority == value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: value != 'URGENT' ? 8 : 0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _priority = value),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withValues(alpha: 0.14)
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? color
                          : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35),
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected
                              ? color
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooter(ColorScheme scheme) {
    final submitLabel = widget.isBugReport
        ? 'Submit report'
        : widget.isEmergency
            ? 'Send urgent request'
            : 'Create ticket';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [_accent, _accent.withValues(alpha: 0.82)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        submitLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;

  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  SupportTicket? _ticket;
  bool _loading = true;
  final _replyController = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      const storage = FlutterSecureStorage();
      final api = SupportApi(ApiClient(await EnvConfig.getBaseUrl(), storage));
      final ticket = await api.fetchTicket(widget.ticketId);
      if (mounted) setState(() => _ticket = ticket);
    } catch (e) {
      if (mounted) {
        AppToast.show(context, '$e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      const storage = FlutterSecureStorage();
      final api = SupportApi(ApiClient(await EnvConfig.getBaseUrl(), storage));
      await api.addTicketMessage(widget.ticketId, text);
      _replyController.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        AppToast.show(context, '$e');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_ticket?.subject ?? 'Ticket')),
      body: _loading
          ? const BybataLoader()
          : _ticket == null
              ? const Center(child: Text('Ticket not found'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(_ticket!.subject, style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(
                            '${_ticket!.category} · ${_ticket!.status.displayName} · ${_ticket!.priority.displayName}',
                          ),
                          const SizedBox(height: 16),
                          ..._ticket!.messages.map(
                            (m) => Align(
                              alignment:
                                  m.isFromUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: m.isFromUser
                                      ? Theme.of(context).colorScheme.primaryContainer
                                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(m.content),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_ticket!.isActive)
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _replyController,
                                  decoration: const InputDecoration(
                                    hintText: 'Add a reply…',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _sending ? null : _sendReply,
                                icon: const Icon(Icons.send),
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
