String normalizeImageUrl(String raw, {String? defaultBucket}) {
  var value = _cleanRaw(raw);
  if (value.isEmpty) return '';

  if (value.startsWith('gs://')) {
    final noScheme = value.substring(5);
    final slash = noScheme.indexOf('/');
    if (slash <= 0 || slash >= noScheme.length - 1) return '';
    final bucket = noScheme.substring(0, slash);
    final objectPath = noScheme.substring(slash + 1);
    return _buildStorageMediaUrl(bucket, objectPath);
  }

  if (!value.startsWith('http://') && !value.startsWith('https://')) {
    final bucket = (defaultBucket ?? '').trim();
    if (bucket.isNotEmpty) {
      return _buildStorageMediaUrl(bucket, value);
    }
    return value;
  }

  final uri = Uri.tryParse(value);
  if (uri == null) return value;

  if (uri.host == 'firebasestorage.googleapis.com') {
    final qp = Map<String, String>.from(uri.queryParameters);
    if (!qp.containsKey('alt')) qp['alt'] = 'media';
    return uri.replace(queryParameters: qp).toString();
  }

  return value;
}

List<String> candidateImageUrls(String raw, {String? defaultBucket}) {
  final rawClean = _cleanRaw(raw);
  final normalized = normalizeImageUrl(raw, defaultBucket: defaultBucket);
  if (normalized.isEmpty) return const [];

  final out = <String>[];
  void add(String v) {
    if (v.isNotEmpty && !out.contains(v)) out.add(v);
  }

  if (rawClean.startsWith('http://') || rawClean.startsWith('https://')) {
    add(rawClean);
  }
  add(normalized);

  final uri = Uri.tryParse(normalized);
  final hasToken = (uri?.queryParameters['token'] ?? '').trim().isNotEmpty;
  if (hasToken) return out;

  if (uri != null && uri.host == 'firebasestorage.googleapis.com') {
    final segments = uri.pathSegments;
    if (segments.length >= 4 && segments[0] == 'v0' && segments[1] == 'b' && segments[3] == 'o') {
      final bucket = segments[2];
      final objectPath = Uri.decodeComponent(segments.sublist(4).join('/'));
      if (bucket.endsWith('.firebasestorage.app')) {
        final alt = bucket.replaceFirst('.firebasestorage.app', '.appspot.com');
        add(_buildStorageMediaUrl(alt, objectPath));
      }
      if (bucket.endsWith('.appspot.com')) {
        final alt = bucket.replaceFirst('.appspot.com', '.firebasestorage.app');
        add(_buildStorageMediaUrl(alt, objectPath));
      }
    }
  }

  return out;
}

String _cleanRaw(String raw) {
  var value = raw.trim();
  if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
    value = value.substring(1, value.length - 1).trim();
  }
  if (value.startsWith("'") && value.endsWith("'") && value.length >= 2) {
    value = value.substring(1, value.length - 1).trim();
  }
  value = value.replaceAll(r'\/', '/');
  value = value.replaceAll(r'\"', '"').trim();
  return value;
}

String _buildStorageMediaUrl(String bucket, String objectPath) {
  final encodedPath = Uri.encodeComponent(objectPath);
  return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media';
}
