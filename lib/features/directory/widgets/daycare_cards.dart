import 'package:flutter/material.dart';
import '../models/daycare_public.dart';
import '../../../services/image_url.dart';
import '../../../widgets/smart_network_image.dart';

class DaycareCard extends StatelessWidget {
  const DaycareCard({super.key, required this.item, this.onTap});
  final DaycarePublic item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _Logo(url: item.logoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${item.city}${item.city.isNotEmpty && item.state.isNotEmpty ? ', ' : ''}${item.state}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (item.capacity > 0) _Chip(text: 'Capacity: ${item.capacity}'),
                        if (item.licenseNumber.trim().isNotEmpty) _Chip(text: 'License: ${item.licenseNumber}'),
                        if (item.languages.isNotEmpty) _Chip(text: item.languages.take(2).join(' • ')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class FeaturedTile extends StatelessWidget {
  const FeaturedTile({super.key, required this.item, this.onTap});
  final DaycarePublic item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hero = item.heroUrl;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Card(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 120,
                width: double.infinity,
                child: hero.isEmpty
                    ? Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Center(child: Icon(Icons.photo, size: 28)),
                      )
                    : SmartNetworkImage(
                        urls: candidateImageUrls(hero),
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                        ),
                        fallback: Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Center(child: Icon(Icons.broken_image_outlined, size: 28)),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${item.city}${item.city.isNotEmpty && item.state.isNotEmpty ? ', ' : ''}${item.state}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StateTile extends StatelessWidget {
  const StateTile({super.key, required this.state2, required this.onTap});
  final String state2;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.map_outlined),
              const SizedBox(width: 10),
              Expanded(child: Text(state2, style: Theme.of(context).textTheme.titleMedium)),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: 44,
        height: 44,
        child: url.isEmpty
            ? Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.school_rounded),
              )
            : SmartNetworkImage(
                urls: candidateImageUrls(url),
                fit: BoxFit.cover,
                placeholder: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
                ),
                fallback: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.school_rounded),
                ),
              ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withAlpha(20)),
        color: Colors.white,
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}
