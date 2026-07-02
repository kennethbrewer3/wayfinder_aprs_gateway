import 'wayfinder_weather_json.dart';

/// Converts parsed APRS payloads into Wayfinder `/api/markers` bodies.
abstract final class WayfinderMarkerMapper {
  static const defaultColor = '#2563eb';
  static const weatherStationIcon = 'weather_station';

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

    if (_isWeatherPayload(payload)) {
      return _weatherBody(payload, latitude, longitude);
    }

    final comment = payload['comment']?.toString().trim();

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
      if (comment != null && comment.isNotEmpty) 'notes': comment,
    };
  }

  static Map<String, dynamic> updateBody(
    Map<String, dynamic> payload, {
    String? existingWeatherJson,
  }) {
    if (_isWeatherPayload(payload)) {
      return _weatherUpdateBody(
        payload,
        existingWeatherJson: existingWeatherJson,
      );
    }

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

    final comment = payload['comment']?.toString().trim();
    if (comment != null && comment.isNotEmpty) {
      body['notes'] = comment;
    }

    return body;
  }

  static Map<String, dynamic> _weatherBody(
    Map<String, dynamic> payload,
    num latitude,
    num longitude,
  ) {
    final weatherJson = WayfinderWeatherJson.buildFromPayload(payload);
    if (weatherJson == null) {
      throw FormatException('APRS weather payload is missing measurements');
    }

    final comment = payload['comment']?.toString().trim();

    return {
      'name': payload['stationId'],
      'latitude': latitude.toDouble(),
      'longitude': longitude.toDouble(),
      'color': defaultColor,
      'icon': weatherStationIcon,
      'visible': true,
      'isTracking': false,
      if (payload['layerId'] != null) 'layerId': payload['layerId'],
      if (comment != null && comment.isNotEmpty) 'notes': comment,
      'weatherJson': weatherJson,
    };
  }

  static Map<String, dynamic> _weatherUpdateBody(
    Map<String, dynamic> payload, {
    String? existingWeatherJson,
  }) {
    final body = <String, dynamic>{
      'icon': weatherStationIcon,
      'isTracking': false,
    };

    if (payload['latitude'] is num && payload['longitude'] is num) {
      body['latitude'] = (payload['latitude'] as num).toDouble();
      body['longitude'] = (payload['longitude'] as num).toDouble();
    }
    if (payload['layerId'] != null) {
      body['layerId'] = payload['layerId'];
    }

    final comment = payload['comment']?.toString().trim();
    if (comment != null && comment.isNotEmpty) {
      body['notes'] = comment;
    }

    final weatherJson = WayfinderWeatherJson.buildFromPayload(
      payload,
      existingWeatherJson: existingWeatherJson,
    );
    if (weatherJson != null) {
      body['weatherJson'] = weatherJson;
    }

    return body;
  }

  static bool _isWeatherPayload(Map<String, dynamic> payload) {
    return payload['packetType']?.toString() == 'weather';
  }

  static String iconForPayload(Map<String, dynamic> payload) {
    if (_isWeatherPayload(payload)) {
      return weatherStationIcon;
    }

    return switch (payload['transportationMode']) {
      'onFoot' => 'hiking',
      'bike' => 'directions_bike',
      'landVehicle' => 'directions_car',
      'watercraft' => 'boat',
      'aircraft' => 'flight',
      _ => switch (payload['packetType']) {
          'repeater' => 'radio_repeater',
          _ => 'my_location',
        },
    };
  }
}
