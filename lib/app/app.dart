import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

    final cfgStream =
        FirebaseFirestore.instance.doc('system/daycarefinder_config').snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: cfgStream,
      builder: (context, snap) {
        final paletteId = (snap.data?.data()?['palette'] ?? 'blush')
            .toString()
            .trim();
        final palette = _themePalettes[paletteId] ?? _themePalettes['blush']!;

        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Daycare Finder',
          theme: buildPublicTheme(
            seed: palette.seed,
            scaffold: palette.scaffold,
          ),
          routerConfig: router,
        );
      },
    );
  }
}

class _ThemePalette {
  const _ThemePalette({
    required this.seed,
    required this.scaffold,
  });

  final Color seed;
  final Color scaffold;
}

const Map<String, _ThemePalette> _themePalettes = {
  'blush': _ThemePalette(
    seed: Color(0xFFD94F82),
    scaffold: Color(0xFFFFF7FA),
  ),
  'coastal': _ThemePalette(
    seed: Color(0xFF1E6F8C),
    scaffold: Color(0xFFF3FAFD),
  ),
  'sunset': _ThemePalette(
    seed: Color(0xFFB4542D),
    scaffold: Color(0xFFFFF8F2),
  ),
  'garden': _ThemePalette(
    seed: Color(0xFF3F7F4A),
    scaffold: Color(0xFFF5FBF4),
  ),
  'lavender': _ThemePalette(
    seed: Color(0xFF6C4BC8),
    scaffold: Color(0xFFF8F5FF),
  ),
  'sunflower': _ThemePalette(
    seed: Color(0xFFC27A00),
    scaffold: Color(0xFFFFFBF0),
  ),
  'slate': _ThemePalette(
    seed: Color(0xFF334155),
    scaffold: Color(0xFFF7FAFC),
  ),
  'american_flag': _ThemePalette(
    seed: Color(0xFFB22234),
    scaffold: Color(0xFFF7F9FF),
  ),
  'christmas': _ThemePalette(
    seed: Color(0xFFC62828),
    scaffold: Color(0xFFF5FBF6),
  ),
  'saint_valentine': _ThemePalette(
    seed: Color(0xFFE11D48),
    scaffold: Color(0xFFFFF5F8),
  ),
  'saint_patrick': _ThemePalette(
    seed: Color(0xFF0F8A3B),
    scaffold: Color(0xFFF3FCF5),
  ),
};
