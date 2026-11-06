import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import 'package:bybata/core/widgets/app_toast.dart';

const _reportReasons = [
  ('SCAM', 'Scam or fraud'),
  ('SUSPICIOUS_ACTIVITY', 'Suspicious activity'),
  ('HARASSMENT', 'Harassment or bullying'),
  ('INAPPROPRIATE_CONTENT', 'Inappropriate content'),
  ('SPAM', 'Spam'),
  ('VIOLENCE', 'Violence or threats'),
  ('OTHER', 'Other'),
];

class ReportUserSheet extends StatefulWidget {
  final String reportedUserId;
  final String reportedUserName;

  const ReportUserSheet({
    super.key,
    required this.reportedUserId,
    required this.reportedUserName,
  });

  @override
  State<ReportUserSheet> createState() => _ReportUserSheetState();
}

class _ReportUserSheetState extends State<ReportUserSheet> {
  String? _selectedReason;
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) {
      AppToast.show(context, 'Please select a reason');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final storage = const FlutterSecureStorage();
      final api = ApiClient(baseUrl, storage);
      await api.post(
        '/v1/users/${widget.reportedUserId}/report',
        data: {
          'reason': _selectedReason,
          if (_detailsController.text.trim().isNotEmpty) 'details': _detailsController.text.trim(),
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      AppToast.show(context, 'Report submitted. Our team will review it.');
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Failed to submit: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Report ${widget.reportedUserName}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Help us understand what\'s wrong. False reports may result in action against your account.',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          ..._reportReasons.map((r) => _buildReasonTile(r.$1, r.$2)),
          const SizedBox(height: 16),
          TextField(
            controller: _detailsController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Additional details (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Submit Report'),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonTile(String value, String label) {
    final isSelected = _selectedReason == value;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedReason = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? scheme.primary.withValues(alpha: 0.1) : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSelected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.5),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
