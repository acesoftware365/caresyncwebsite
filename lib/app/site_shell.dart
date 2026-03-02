import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class SiteShell extends StatefulWidget {
  const SiteShell({super.key, required this.child});
  final Widget child;

  @override
  State<SiteShell> createState() => _SiteShellState();
}

class _SiteShellState extends State<SiteShell> {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compactNav = width < 900;

    final cfgStream =
        FirebaseFirestore.instance.doc('system/daycarefinder_config').snapshots();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: cfgStream,
      builder: (context, snap) {
        final paletteId = (snap.data?.data()?['palette'] ?? 'blush')
            .toString()
            .trim();
        final palette = _shellPalettes[paletteId] ?? _shellPalettes['blush']!;

        return Scaffold(
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: palette.sixty.withAlpha(210),
                  border: Border(
                    bottom: BorderSide(color: palette.thirty.withAlpha(180)),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: compactNav ? _compactNav(context) : _desktopNav(context),
                ),
              ),
              Expanded(child: widget.child),
              _SiteFooter(palette: palette),
            ],
          ),
        );
      },
    );
  }

  Widget _desktopNav(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => context.go('/'),
          child: Text(
            'DaycareFinder.com',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        const Spacer(),
        TextButton(onPressed: () {}, child: const Text('For Parents')),
        TextButton(onPressed: () {}, child: const Text('For Providers')),
      ],
    );
  }

  Widget _compactNav(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => context.go('/'),
            child: Text(
              'DaycareFinder.com',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Menu',
          onSelected: (value) {},
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'parents', child: Text('For Parents')),
            PopupMenuItem(value: 'providers', child: Text('For Providers')),
          ],
          icon: const Icon(Icons.menu),
        ),
      ],
    );
  }
}

class _SiteFooter extends StatelessWidget {
  const _SiteFooter({required this.palette});
  final _ShellPalette palette;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 640;
    return Container(
      width: double.infinity,
      padding: compact
          ? const EdgeInsets.fromLTRB(14, 12, 14, 10)
          : const EdgeInsets.fromLTRB(20, 22, 20, 14),
      decoration: BoxDecoration(
        color: palette.sixty.withAlpha(185),
        border: Border(top: BorderSide(color: palette.thirty.withAlpha(180))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: compact ? _compactFooter(textTheme) : _desktopFooter(textTheme),
        ),
      ),
    );
  }

  Widget _compactFooter(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            Text('For Parents', style: textTheme.bodySmall),
            Text('For Providers', style: textTheme.bodySmall),
            Text('Terms & Privacy', style: textTheme.bodySmall),
            Text('Contact', style: textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Text('Powered by Liisgo Daycare System', style: textTheme.bodySmall),
            Text('Version 1.0.26+33', style: textTheme.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget _desktopFooter(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Wrap(
          spacing: 28,
          runSpacing: 18,
          children: [
            _FooterCol(
              compact: false,
              title: 'For Parents',
              items: [
                'Find a Daycare Near You',
                'Find Childcare by City',
                'Parent Articles & Resources',
                'Parent Dashboard',
              ],
            ),
            _FooterCol(
              compact: false,
              title: 'For Providers',
              items: [
                'List Your Business',
                'Provider Articles & Resources',
                'Provider Dashboard',
                'Help Center',
              ],
            ),
            _FooterCol(
              compact: false,
              title: 'Daycare.com',
              items: [
                'About Daycare.com',
                'Terms of Use & Privacy',
                'Contact Us',
                'Instagram',
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Powered by Liisgo Daycare System',
              style: textTheme.bodySmall,
            ),
            Text(
              '© 2026 Daycare.com. All rights reserved.',
              style: textTheme.bodySmall,
            ),
            Text(
              'Version 1.0.26+33',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _ShellPalette {
  const _ShellPalette({
    required this.sixty,
    required this.thirty,
  });

  final Color sixty;
  final Color thirty;
}

const Map<String, _ShellPalette> _shellPalettes = {
  'blush': _ShellPalette(
    sixty: Color(0xFFFFF0F5),
    thirty: Color(0xFFF8C7D8),
  ),
  'coastal': _ShellPalette(
    sixty: Color(0xFFEAF4F8),
    thirty: Color(0xFFBBD6E3),
  ),
  'sunset': _ShellPalette(
    sixty: Color(0xFFF9EFE5),
    thirty: Color(0xFFD9BBA0),
  ),
  'garden': _ShellPalette(
    sixty: Color(0xFFEEF5EC),
    thirty: Color(0xFFC4D9B8),
  ),
  'lavender': _ShellPalette(
    sixty: Color(0xFFF3F0FF),
    thirty: Color(0xFFD7CCFF),
  ),
  'sunflower': _ShellPalette(
    sixty: Color(0xFFFFF8E8),
    thirty: Color(0xFFFDE2A4),
  ),
  'slate': _ShellPalette(
    sixty: Color(0xFFF1F5F9),
    thirty: Color(0xFFCBD5E1),
  ),
  'american_flag': _ShellPalette(
    sixty: Color(0xFFF5F8FF),
    thirty: Color(0xFFE3EAFB),
  ),
  'christmas': _ShellPalette(
    sixty: Color(0xFFF4FBF5),
    thirty: Color(0xFFD4EED6),
  ),
  'saint_valentine': _ShellPalette(
    sixty: Color(0xFFFFF1F6),
    thirty: Color(0xFFFBCADD),
  ),
  'saint_patrick': _ShellPalette(
    sixty: Color(0xFFF2FAF3),
    thirty: Color(0xFFCBECCF),
  ),
};

class _FooterCol extends StatelessWidget {
  const _FooterCol({required this.title, required this.items, required this.compact});
  final String title;
  final List<String> items;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 180 : 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...items.map((x) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(x, style: Theme.of(context).textTheme.bodyMedium),
              )),
        ],
      ),
    );
  }
}
