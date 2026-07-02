class DuplicateFilter {
  DuplicateFilter({required this.window});

  final Duration window;
  final _seen = <String, DateTime>{};

  bool isDuplicate(Map<String, dynamic> payload) {
    final key = _duplicateKey(payload);
    final now = DateTime.now();
    _purge(now);

    final previous = _seen[key];
    if (previous != null && now.difference(previous) < window) {
      return true;
    }

    _seen[key] = now;
    return false;
  }

  void _purge(DateTime now) {
    _seen.removeWhere((_, seenAt) => now.difference(seenAt) >= window);
  }

  String _duplicateKey(Map<String, dynamic> payload) {
    final stationId = payload['stationId']?.toString() ?? '';
    final packetType = payload['packetType']?.toString() ?? '';
    final rawAprs = payload['rawAprs']?.toString() ?? '';

    if (packetType == 'weather') {
      return '$stationId|$packetType|${rawAprs.hashCode}';
    }

    if (payload.containsKey('latitude') && payload.containsKey('longitude')) {
      final lat = (payload['latitude'] as num).toDouble();
      final lon = (payload['longitude'] as num).toDouble();
      return '$stationId|$packetType|${lat.toStringAsFixed(4)}|${lon.toStringAsFixed(4)}';
    }

    return '$stationId|$packetType|${rawAprs.hashCode}';
  }
}
