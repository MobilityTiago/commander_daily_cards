import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../styles/colors.dart';
import '../../widgets/app_bar.dart';

class SitesScreen extends StatelessWidget {
  const SitesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          title: const Text('Sites', style: TextStyle(color: Colors.white)),
          flexibleSpace: const AppBarBackground(),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Wizards'),
              Tab(text: 'EDHrec'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _WizardsView(),
            _SiteWebView(
              initialUrl: 'https://edhrec.com/',
              allowedDomain: 'edhrec.com',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Wizards nested tab view ─────────────────────────────────────────────────

class _WizardsView extends StatelessWidget {
  const _WizardsView();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: AppColors.black,
            child: const TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: TextStyle(fontSize: 12),
              tabs: [
                Tab(text: 'Announcements'),
                Tab(text: 'Preview'),
                Tab(text: 'Making Magic'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _SiteWebView(
                  initialUrl: 'https://magic.wizards.com/en/news/announcements',
                  allowedDomain: 'magic.wizards.com',
                ),
                _SiteWebView(
                  initialUrl: 'https://magic.wizards.com/en/news/card-preview',
                  allowedDomain: 'magic.wizards.com',
                ),
                _SiteWebView(
                  initialUrl: 'https://magic.wizards.com/en/news/making-magic',
                  allowedDomain: 'magic.wizards.com',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable WebView with nav bar and optional domain restriction ────────────

class _SiteWebView extends StatefulWidget {
  final String initialUrl;

  /// If set, navigation to any host outside this domain (or its subdomains)
  /// will be blocked.
  final String? allowedDomain;

  const _SiteWebView({required this.initialUrl, this.allowedDomain});

  @override
  State<_SiteWebView> createState() => _SiteWebViewState();
}

class _SiteWebViewState extends State<_SiteWebView> {
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
              WebViewWidget(controller: _controller),
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
