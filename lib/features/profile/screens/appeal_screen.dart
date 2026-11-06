import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import 'package:bybata/core/widgets/app_toast.dart';

class AppealScreen extends StatefulWidget {
  const AppealScreen({super.key});

  @override
  State<AppealScreen> createState() => _AppealScreenState();
}

class _AppealScreenState extends State<AppealScreen> {
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      AppToast.show(context, 'Please explain why you believe the suspension was unjustified');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final storage = const FlutterSecureStorage();
      final api = ApiClient(baseUrl, storage);
      await api.post(
        '/v1/users/me/appeal',
        data: {'reason': reason},
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      AppToast.show(context, 'Appeal submitted. We will review it shortly.');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Appeal'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.gavel,
              size: 64,
              color: scheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 24),
            Text(
              'Account Restriction Appeal',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'If you believe your account was restricted in error, please explain your situation below. Our team will review your appeal and respond within a few business days.',
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _reasonController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Explain why you believe your suspension was unjustified...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                alignLabelWithHint: true,
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
                  : const Text('Submit Appeal'),
            ),
          ],
        ),
      ),
    );
  }
}
