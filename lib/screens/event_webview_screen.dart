import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class EventWebViewScreen extends StatefulWidget {
  final String eventUrl;
  final String eventTitle;

  const EventWebViewScreen({
    super.key,
    required this.eventUrl,
    required this.eventTitle,
  });

  @override
  State<EventWebViewScreen> createState() => _EventWebViewScreenState();
}

class _EventWebViewScreenState extends State<EventWebViewScreen> {
  static const _blue = Color(0xFF2D5478);
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
        'Mobile/15E148 Safari/604.1',
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onWebResourceError: (error) {
          debugPrint('❌ WebView error: ${error.description}');
        },
        onNavigationRequest: (request) {
          // Laisser naviguer librement sur helloasso.com
          // Bloquer les redirections externes non souhaitées
          final uri = Uri.tryParse(request.url);
          if (uri != null &&
              !uri.host.contains('helloasso.com') &&
              !uri.host.contains('helloasso-static.com') &&
              !uri.host.contains('stripe.com') &&
              !uri.host.contains('payplug.com')) {
            debugPrint('🚫 Bloqué: ${request.url}');
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(
        Uri.parse(widget.eventUrl),
        headers: {
          'Accept-Language': 'fr-FR,fr;q=0.9',
        },
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
        title: Text(
          widget.eventTitle,
          style: const TextStyle(
            color: _blue,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        // Bouton retour arrière dans la WebView
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: _blue, size: 18),
            onPressed: () async {
              if (await _controller.canGoBack()) {
                _controller.goBack();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: _blue, size: 20),
            onPressed: () => _controller.reload(),
          ),
        ],
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(
                  backgroundColor: Color(0xFFDDEDF5),
                  valueColor: AlwaysStoppedAnimation<Color>(_blue),
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}