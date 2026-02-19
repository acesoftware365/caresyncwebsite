import 'package:flutter/material.dart';
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

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBFD),
              border: Border(bottom: BorderSide(color: Colors.black.withAlpha(20))),
            ),
            child: SafeArea(
              bottom: false,
              child: compactNav ? _compactNav(context) : _desktopNav(context),
            ),
          ),
          Expanded(child: widget.child),
          const _SiteFooter(),
        ],
      ),
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
  const _SiteFooter();

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
        color: const Color(0xFFFFF3F8),
        border: Border(top: BorderSide(color: Colors.black.withAlpha(18))),
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
            Text('Version 1.0.2', style: textTheme.bodySmall),
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
              'Version 1.0.2',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

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
