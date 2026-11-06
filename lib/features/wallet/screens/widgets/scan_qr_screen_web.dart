import 'package:flutter/material.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class ScanQRScreen extends StatefulWidget {
  final Future<void> Function(String code) onResult;
  const ScanQRScreen({super.key, required this.onResult});

  @override
  State<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paste QR Code')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('QR scanning is not available on web. Paste the code:'),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste QR content or deep link',
              ),
              minLines: 1,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _processing
                    ? null
                    : () async {
                        final text = _controller.text.trim();
                        if (text.isEmpty) return;
                        setState(() => _processing = true);
                        try {
                          await widget.onResult(_extractCode(text));
                          if (!mounted) return;
                          Navigator.of(context).pop();
                        } finally {
                          if (mounted) setState(() => _processing = false);
                        }
                      },
                child: Text(_processing ? 'Processing...' : 'Process'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _extractCode(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.queryParameters.containsKey('qr')) {
      return uri.queryParameters['qr']!;
    }
    return raw;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class TransferBYCScreenInitialPrefill extends StatelessWidget {
  final String email;
  const TransferBYCScreenInitialPrefill({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    Future.microtask(() {
      GuardedNavigator.pushReplacementNamed(context, 
        '/wallet/send',
        arguments: {'email': email},
      );
    });
    return const Scaffold(body: BybataLoader());
  }
}
