import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/helloasso_service.dart';

class PayInvoiceScreen extends StatefulWidget {
  final String invoiceId;
  const PayInvoiceScreen({super.key, required this.invoiceId});

  @override
  State<PayInvoiceScreen> createState() => _PayInvoiceScreenState();
}

class _PayInvoiceScreenState extends State<PayInvoiceScreen> {
  static const _blue = Color(0xFF2D5478);

  // États possibles de l'écran
  _ScreenState _state = _ScreenState.loading;
  String? _error;
  WebViewController? _webController;
  bool _webViewLoading = true;

  @override
  void initState() {
    super.initState();
    _generateCheckout();
  }

  Future<void> _generateCheckout() async {
    setState(() {
      _state = _ScreenState.loading;
      _error = null;
    });

    try {
      final url = await HelloAssoService()
          .generateInvoiceCheckout(widget.invoiceId);
      _initWebView(url);
      setState(() => _state = _ScreenState.webview);
    } catch (e) {
      setState(() {
        _state = _ScreenState.error;
        _error = e.toString();
      });
    }
  }

void _initWebView(String url) {
  debugPrint('🔗 URL HelloAsso: $url');

  _webController = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setUserAgent(
      // User-agent mobile standard — HelloAsso bloque parfois les WebViews détectées
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    )
    ..setNavigationDelegate(NavigationDelegate(
      onPageStarted: (url) {
        debugPrint('📄 Page started: $url');
        setState(() => _webViewLoading = true);
      },
      onPageFinished: (url) {
        debugPrint('✅ Page finished: $url');
        setState(() => _webViewLoading = false);
      },
      onWebResourceError: (error) {
        debugPrint('❌ WebView error: ${error.description} (${error.errorCode})');
      },
      onNavigationRequest: (request) {
        debugPrint('🔀 Navigation: ${request.url}');
        if (request.url.contains('cve-bar.web.app/pay/return') ||
        request.url.contains('cve://pay/return')) {
          _onPaymentSuccess();
          return NavigationDecision.prevent;
        }

        if (request.url.contains('cve-bar.web.app/pay/back') ||
            request.url.contains('cve-bar.web.app/pay/error') ||
            request.url.contains('cve://pay/back') ||
            request.url.contains('cve://pay/error')) {
          _onPaymentCanceled();
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      },
    ))
    ..loadRequest(
      Uri.parse(url),
      // Headers supplémentaires pour simuler un navigateur standard
      headers: {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'fr-FR,fr;q=0.9',
      },
    );
}
  void _onPaymentSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Paiement effectué !',
              style: TextStyle(
                color: _blue,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Votre facture a bien été réglée.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // ferme le dialog
              Navigator.of(context).pop(); // ferme PayInvoiceScreen
            },
            child: const Text('Retour', style: TextStyle(color: _blue)),
          ),
        ],
      ),
    );
  }

  void _onPaymentCanceled() {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paiement annulé.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F7FB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: _blue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Paiement',
          style: TextStyle(color: _blue, fontWeight: FontWeight.bold),
        ),
        // Indicateur de chargement WebView dans l'AppBar
        bottom: _state == _ScreenState.webview && _webViewLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(
                  backgroundColor: Color(0xFFDDEDF5),
                  valueColor: AlwaysStoppedAnimation<Color>(_blue),
                ),
              )
            : null,
      ),
      body: switch (_state) {
        // ── Chargement initial (génération du checkout) ──────────
        _ScreenState.loading => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: _blue),
                SizedBox(height: 20),
                Text(
                  'Préparation du paiement…',
                  style: TextStyle(color: _blue, fontSize: 15),
                ),
              ],
            ),
          ),

        // ── WebView HelloAsso ─────────────────────────────────────
        _ScreenState.webview => _webController != null
            ? WebViewWidget(controller: _webController!)
            : const SizedBox.shrink(),

        // ── Erreur ───────────────────────────────────────────────
        _ScreenState.error => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error ?? 'Une erreur est survenue',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _blue),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _generateCheckout,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      },
    );
  }
}

enum _ScreenState { loading, webview, error }