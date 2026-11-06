import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:provider/provider.dart';
import 'package:bybata/core/api/api_client.dart';
import 'package:bybata/core/auth/auth_provider.dart';
import 'transfer_byc_screen.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Screen for scanning QR codes to receive BYC transfers
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _controller;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      _controller = controller;
    });

    controller.scannedDataStream.listen((scanData) {
      if (!_isProcessing && scanData.code != null) {
        _processQRCode(scanData.code!);
      }
    });
  }

  Future<void> _processQRCode(String qrCode) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiClient = ApiClient();

      // Validate QR code
      final response = await apiClient.post(
        '/v1/wallet/qr/scan',
        data: {'qrCode': qrCode},
        token: authProvider.accessToken,
      );

      if (mounted) {
        if (response['ok'] == true) {
          final recipient = response['recipient'];
          final amount = response['amount'];
          final memo = response['memo'];

          // Navigate to transfer screen with pre-filled data
          GuardedNavigator.pushReplacement(context, 
            MaterialPageRoute(
              builder: (context) => TransferBYCScreen(
                recipientId: recipient['userId'] as String?,
                recipientEmail: recipient['email'] as String?,
                recipientName: recipient['displayName'] as String?,
                initialAmount: amount != null ? double.tryParse(amount.toString()) : null,
                initialMemo: memo as String?,
              ),
            ),
          );
        } else {
          setState(() {
            _errorMessage = response['error'] ?? 'Invalid QR code';
            _isProcessing = false;
          });
          // Resume scanning after 2 seconds
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _errorMessage = null;
              });
              _controller?.resumeCamera();
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to process QR code: ${e.toString()}';
          _isProcessing = false;
        });
        // Resume scanning after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _errorMessage = null;
            });
            _controller?.resumeCamera();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () {
              _controller?.toggleFlash();
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () {
              _controller?.flipCamera();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          QRView(
            key: _qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Theme.of(context).primaryColor,
              borderRadius: 16,
              borderLength: 30,
              borderWidth: 8,
              cutOutSize: 250,
            ),
          ),
          
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Processing QR code...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          
          if (_errorMessage != null)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          
          // Instructions overlay
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Position the QR code within the frame',
                style: TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

