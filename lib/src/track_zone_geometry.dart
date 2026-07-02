import 'dart:convert';

/// Helpers for Wayfinder track zone `geometryJson` payloads.
abstract final class TrackZoneGeometry {
  static String? updatedTransportationMode(
    String geometryJson,
    String transportationMode,
  ) {
    final decoded = jsonDecode(geometryJson);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    if (decoded['transportationMode'] == transportationMode) {
      return null;
    }

    decoded['transportationMode'] = transportationMode;
    return jsonEncode(decoded);
  }
}
