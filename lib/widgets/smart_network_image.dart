import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class SmartNetworkImage extends StatefulWidget {
  const SmartNetworkImage({
    super.key,
    required this.urls,
    required this.fallback,
    this.fit,
    this.placeholder,
  });

  final List<String> urls;
  final BoxFit? fit;
  final Widget fallback;
  final Widget? placeholder;

  @override
  State<SmartNetworkImage> createState() => _SmartNetworkImageState();
}

class _SmartNetworkImageState extends State<SmartNetworkImage> {
  int _index = 0;
  bool _switchQueued = false;

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) return widget.fallback;
    final url = widget.urls[_index];

    return Image.network(
      url,
      fit: widget.fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return widget.placeholder ?? widget.fallback;
      },
      errorBuilder: (context, error, stackTrace) {
        if (_index < widget.urls.length - 1) {
          _queueNextUrl();
          return widget.placeholder ?? widget.fallback;
        }
        if (kDebugMode) {
          debugPrint('SmartNetworkImage failed. Tried URLs: ${widget.urls.join(' | ')}');
          debugPrint('Last error: $error');
        }
        return widget.fallback;
      },
    );
  }

  void _queueNextUrl() {
    if (_switchQueued) return;
    _switchQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _index += 1;
      });
      _switchQueued = false;
    });
  }
}
