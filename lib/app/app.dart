import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'site_shell.dart';
import '../theme/app_theme.dart';
import '../features/directory/pages/home_page.dart';
import '../features/directory/pages/search_page.dart';
import '../features/daycare/pages/daycare_public_page.dart';

class DaycareWebsitesApp extends StatelessWidget {
  const DaycareWebsitesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        ShellRoute(
          builder: (_, state, child) => SiteShell(child: child),
          routes: [
            GoRoute(path: '/', builder: (context, state) => const DirectoryHomePage()),
            GoRoute(
              path: '/search',
              builder: (_, state) => DirectorySearchPage(query: state.uri.queryParameters),
            ),
            GoRoute(
              path: '/daycare/:slug',
              builder: (_, state) => DaycarePublicPage(slug: state.pathParameters['slug'] ?? ''),
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Daycare Finder',
      theme: buildPublicTheme(),
      routerConfig: router,
    );
  }
}
