import 'package:flutter/material.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Generic payment WebView for all payment gateways (Paystack, Stripe, PayPal, Flutterwave)
class PaymentWebViewScreen extends StatefulWidget {
  final String authorizationUrl;
  final String provider;
  final String callbackPattern;
  
  const PaymentWebViewScreen({
    Key? key,
    required this.authorizationUrl,
    required this.provider,
    String? callbackPattern,
  }) : callbackPattern = callbackPattern ?? '/callback',
       super(key: key);

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Color get _providerColor {
    switch (widget.provider.toLowerCase()) {
      case 'paystack':
        return const Color(0xFF00C3F7);
      case 'stripe':
        return const Color(0xFF635BFF);
      case 'paypal':
        return const Color(0xFF003087);
      case 'flutterwave':
        return const Color(0xFFF5A623);
      default:
        return const Color(0xFF00C3F7);
    }
  }

  String get _providerName {
    return widget.provider[0].toUpperCase() + widget.provider.substring(1);
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() { 
              _isLoading = true;
              _error = null;
            });
            print('[$_providerName WebView] Page started: $url');
          },
          onPageFinished: (String url) {
            setState(() { _isLoading = false; });
            print('[$_providerName WebView] Page finished: $url');
          },
          onWebResourceError: (WebResourceError error) {
            print('[$_providerName WebView] Error: ${error.description}');
            setState(() {
              _error = error.description;
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            print('[$_providerName WebView] Navigation to: ${request.url}');
            
            // Check if we've reached the callback URL endpoint
            if (request.url.contains('/${widget.provider.toLowerCase()}/callback') ||
                request.url.contains(widget.callbackPattern)) {
              print('[$_providerName WebView] Callback detected!');
              
              try {
                final uri = Uri.parse(request.url);
                
                // Extract reference based on provider from the HTTP callback URL
                // The status will be determined by backend verification, not from URL
                String? reference;
                switch (widget.provider.toLowerCase()) {
                  case 'paystack':
                    // Paystack uses 'reference' or 'trxref' in the callback URL
                    reference = uri.queryParameters['reference'] ?? uri.queryParameters['trxref'];
                    break;
                  case 'stripe':
                    reference = uri.queryParameters['session_id'];
                    break;
                  case 'paypal':
                    reference = uri.queryParameters['token'] ?? uri.queryParameters['order_id'];
                    break;
                  case 'flutterwave':
                    reference = uri.queryParameters['transaction_id'] ?? uri.queryParameters['tx_ref'];
                    break;
                }
                
                print('[$_providerName WebView] Payment reference extracted: $reference');
                
                // Pop with result - the reference will be verified with the backend
                // Status will be determined by backend verification
                if (reference != null) {
                  Navigator.of(context).pop({
                    'status': 'pending',  // Pending verification
                    'reference': reference,
                    'provider': widget.provider.toLowerCase(),
                    'url': request.url,
                  });
                } else {
                  Navigator.of(context).pop({
                    'status': 'error',
                    'error': 'Could not extract payment reference',
                  });
                }
                
                return NavigationDecision.prevent;
              } catch (e) {
                print('[$_providerName WebView] Error parsing callback: $e');
                Navigator.of(context).pop({
                  'status': 'error',
                  'error': 'Failed to parse callback URL',
                });
                return NavigationDecision.prevent;
              }
            }
            
            // Check for cancellation keywords (do NOT treat about:blank as cancel -
            // WebView often starts with about:blank before loading the payment URL)
            if (request.url.contains('cancelled') || 
                request.url.contains('cancel') ||
                request.url.contains('status=cancelled')) {
              print('[$_providerName WebView] Payment cancelled');
              Navigator.of(context).pop({'status': 'cancelled'});
              return NavigationDecision.prevent;
            }
            
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final shouldClose = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancel Payment?'),
            content: const Text('Are you sure you want to cancel this payment?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No, Continue'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes, Cancel'),
              ),
            ],
          ),
        );
        
        if (shouldClose == true) {
          Navigator.of(context).pop({'status': 'cancelled'});
        }
        
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: _providerColor,
          title: Text(
            'Complete Payment - $_providerName',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () async {
              final shouldClose = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cancel Payment?'),
                  content: const Text('Are you sure you want to cancel this payment?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('No'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Yes'),
                    ),
                  ],
                ),
              );
              
              if (shouldClose == true && mounted) {
                Navigator.of(context).pop({'status': 'cancelled'});
              }
            },
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            
            // Loading indicator
            if (_isLoading && _error == null)
              Container(
                color: Colors.white,
                child: BybataLoader(
                  message: 'Loading $_providerName payment...',
                  color: _providerColor,
                ),
              ),
            
            // Error state
            if (_error != null)
              Container(
                color: Colors.white,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Failed to load payment page',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop({'status': 'error'});
                              },
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _error = null;
                                  _isLoading = true;
                                });
                                _initializeWebView();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _providerColor,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Legacy alias for backward compatibility
typedef PaystackWebViewScreen = PaymentWebViewScreen;
