import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class ScanQRScreen extends StatefulWidget {
  final Future<void> Function(String code) onResult;
  const ScanQRScreen({super.key, required this.onResult});

  @override
  State<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  bool _handled = false;
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR')),
      body: QRView(
        key: _qrKey,
        onQRViewCreated: (ctrl) {
          _controller = ctrl;
          ctrl.scannedDataStream.listen((scanData) async {
            if (_handled) return;
            final raw = scanData.code;
            if (raw == null) return;
            _handled = true;
            try {
              await widget.onResult(_extractCode(raw));
              if (!mounted) return;
              Navigator.of(context).pop();
            } catch (_) {
              AppToast.error(context, 'Failed to process QR');
              _handled = false;
            }
          });
        },
      ),
    );
  }

  String _extractCode(String raw) {
    final trimmed = raw.trim();
    // Handle bybata://app/trade?qr=base64 or similar URI format
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.queryParameters.containsKey('qr')) {
      return uri.queryParameters['qr']!.trim();
    }
    return trimmed;
  }

  @override
  void dispose() {
    _controller?.dispose();
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
