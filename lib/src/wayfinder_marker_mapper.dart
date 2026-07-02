import 'weather_notes_formatter.dart';

/// Converts parsed APRS payloads into Wayfinder `/api/markers` bodies.
abstract final class WayfinderMarkerMapper {
  static const defaultColor = '#2563eb';

  static Map<String, dynamic> createBody(Map<String, dynamic> payload) {
    final stationId = payload['stationId'];
    final latitude = payload['latitude'];
    final longitude = payload['longitude'];

    if (stationId is! String || stationId.isEmpty) {
      throw FormatException('APRS payload is missing stationId');
    }
    if (latitude is! num || longitude is! num) {
      throw FormatException('APRS payload is missing latitude/longitude');
    }

    final notes = WeatherNotesFormatter.notesForPayload(payload);

    return {
      'name': stationId,
      'latitude': latitude.toDouble(),
      'longitude': longitude.toDouble(),
      'color': defaultColor,
      'icon': iconForPayload(payload),
      'visible': true,
      if (payload['isTracking'] == true) 'isTracking': true,
      if (payload['layerId'] != null) 'layerId': payload['layerId'],
      if (payload['altitude'] is num)
        'elevation': (payload['altitude'] as num).toDouble(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
  }

  static Map<String, dynamic> updateBody(Map<String, dynamic> payload) {
    final body = <String, dynamic>{};

    if (payload['latitude'] is num && payload['longitude'] is num) {
      body['latitude'] = (payload['latitude'] as num).toDouble();
      body['longitude'] = (payload['longitude'] as num).toDouble();
    }
    if (payload['isTracking'] == true) {
      body['isTracking'] = true;
    }
    if (payload['layerId'] != null) {
      body['layerId'] = payload['layerId'];
    }
    if (payload['altitude'] is num) {
      body['elevation'] = (payload['altitude'] as num).toDouble();
    }

    final notes = WeatherNotesFormatter.notesForPayload(payload);
    if (notes != null && notes.isNotEmpty) {
      body['notes'] = notes;
    }

    return body;
  }

  static String iconForPayload(Map<String, dynamic> payload) {
    return switch (payload['transportationMode']) {
      'onFoot' => 'hiking',
      'bike' => 'directions_bike',
      'landVehicle' => 'directions_car',
      'watercraft' => 'boat',
      'aircraft' => 'flight',
      _ => switch (payload['packetType']) {
          'weather' => 'info',
          'repeater' => 'radio_repeater',
          _ => 'my_location',
        },
    };
  }
}
