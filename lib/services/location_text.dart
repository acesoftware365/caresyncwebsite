String normalizeCity(String value) {
  final input = value.trim();
  if (input.isEmpty) return '';
  final words = input.split(RegExp(r'\s+'));
  return words
      .map((w) {
        if (w.isEmpty) return w;
        final lower = w.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

String normalizeStateCode(String value) {
  return value.trim().toUpperCase();
}
