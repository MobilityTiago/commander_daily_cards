import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../styles/colors.dart';

class DomainRestrictedWebView extends StatefulWidget {
  final String initialUrl;

  /// If set, navigation to any host outside this domain (or its subdomains)
  /// will be blocked.
  final String? allowedDomain;

  const DomainRestrictedWebView({
    super.key,
    required this.initialUrl,
    this.allowedDomain,
  });

  @override
  State<DomainRestrictedWebView> createState() =>
      _DomainRestrictedWebViewState();
}

class _DomainRestrictedWebViewState extends State<DomainRestrictedWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;

  bool _isAllowed(String url) {
    final domain = widget.allowedDomain;
    if (domain == null) return true;
    final host = Uri.tryParse(url)?.host ?? '';
    return host == domain || host.endsWith('.$domain');
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (!_isAllowed(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() => _isLoading = true);
          },
          onPageFinished: (_) async {
            if (!mounted) return;
            final back = await _controller.canGoBack();
            final forward = await _controller.canGoForward();
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _canGoBack = back;
              _canGoForward = forward;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              WebViewWidget(
                controller: _controller,
                gestureRecognizers: {
                  Factory<OneSequenceGestureRecognizer>(
                    EagerGestureRecognizer.new,
                  ),
                },
              ),
              if (_isLoading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
        Container(
          color: AppColors.black,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: _canGoBack ? Colors.white : Colors.white30,
                  size: 20,
                ),
                onPressed: _canGoBack ? () => _controller.goBack() : null,
                tooltip: 'Back',
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
                onPressed: () => _controller.reload(),
                tooltip: 'Refresh',
              ),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios,
                  color: _canGoForward ? Colors.white : Colors.white30,
                  size: 20,
                ),
                onPressed: _canGoForward ? () => _controller.goForward() : null,
                tooltip: 'Forward',
              ),
            ],
          ),
        ),
      ],
    );
  }
}