import 'package:flutter/material.dart';

import '../../styles/colors.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/domain_restricted_webview.dart';

class SitesScreen extends StatelessWidget {
  const SitesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          title: const Text('Content', style: TextStyle(color: Colors.white)),
          flexibleSpace: const AppBarBackground(),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Wizards'),
              Tab(text: 'EDHrec'),
              Tab(text: 'YouTube'),
            ],
          ),
        ),
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(),
          children: [
            _WizardsView(),
            DomainRestrictedWebView(
              initialUrl: 'https://edhrec.com/',
              allowedDomain: 'edhrec.com',
            ),
            DomainRestrictedWebView(
              initialUrl:
                  'https://www.youtube.com/playlist?list=PLaXuMvW4dV6AClU0wQjVZvIzW42th_Vul',
              allowedDomain: 'youtube.com',
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
              physics: NeverScrollableScrollPhysics(),
              children: [
                DomainRestrictedWebView(
                  initialUrl: 'https://magic.wizards.com/en/news/announcements',
                  allowedDomain: 'magic.wizards.com',
                ),
                DomainRestrictedWebView(
                  initialUrl: 'https://magic.wizards.com/en/news/card-preview',
                  allowedDomain: 'magic.wizards.com',
                ),
                DomainRestrictedWebView(
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
