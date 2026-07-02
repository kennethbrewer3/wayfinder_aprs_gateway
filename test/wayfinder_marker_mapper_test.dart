import 'dart:convert';

import 'package:test/test.dart';
import 'package:wayfinder_aprs_gateway/src/wayfinder_marker_mapper.dart';
import 'package:wayfinder_aprs_gateway/src/wayfinder_weather_json.dart';

void main() {
  group('WayfinderWeatherJson', () {
    test('builds weatherJson for the Wayfinder weather station UI', () {
      final weatherJson = WayfinderWeatherJson.buildFromPayload({
        'source': 'aprs',
        'timestamp': '2026-06-29T15:00:00.000Z',
        'weather': {
          'windDirection': 225,
          'windSpeed': 3.333,
          'temperature': 22.4,
          'humidity': 58,
          'pressure': 1015.0,
          'rain1h': 0.0,
        },
      });

      expect(weatherJson, isNotNull);
      final decoded = jsonDecode(weatherJson!) as Map<String, dynamic>;
      expect(decoded['source'], 'aprs');
      expect(decoded['temperature'], 22.4);
      expect(decoded['humidityPercent'], 58);
      expect(decoded['windDirectionDegrees'], 225);
      expect(decoded['windSpeedUnit'], 'km/h');
      expect(decoded['pressureUnit'], 'hPa');
      expect(decoded['condition'], isNotNull);
    });

    test('preserves prior readings in history', () {
      const existing = '''
{
  "observedAt": "2026-06-29T14:00:00.000Z",
  "temperature": 21.0,
  "condition": "Cloudy"
}
''';

      final weatherJson = WayfinderWeatherJson.buildFromPayload(
        {
          'timestamp': '2026-06-29T15:00:00.000Z',
          'weather': {
            'temperature': 22.0,
            'humidity': 60,
          },
        },
        existingWeatherJson: existing,
      );

      final decoded = jsonDecode(weatherJson!) as Map<String, dynamic>;
      expect(decoded['temperature'], 22.0);
      expect(decoded['history'], isA<List>());
      expect((decoded['history'] as List).first['temperature'], 21.0);
    });
  });

  group('WayfinderMarkerMapper', () {
    test('builds create body from APRS payload', () {
      final body = WayfinderMarkerMapper.createBody({
        'stationId': 'N0CALL-1',
        'latitude': 38.9,
        'longitude': -77.1,
        'comment': 'Test',
        'isTracking': true,
        'layerId': 'layer-123',
        'transportationMode': 'landVehicle',
      });

      expect(body['name'], 'N0CALL-1');
      expect(body['icon'], 'directions_car');
      expect(body['isTracking'], true);
      expect(body['notes'], 'Test');
    });

    test('builds weather station marker bodies with weatherJson', () {
      final body = WayfinderMarkerMapper.createBody({
        'stationId': 'WX0ABC',
        'packetType': 'weather',
        'latitude': 38.8765,
        'longitude': -77.1233,
        'comment': 'Backyard WX',
        'weather': {
          'windDirection': 225,
          'windSpeed': 6.17328,
          'temperature': 22.2,
          'humidity': 55,
          'pressure': 1013.8,
        },
      });

      expect(body['icon'], 'weather_station');
      expect(body['isTracking'], false);
      expect(body['notes'], 'Backyard WX');
      expect(body['weatherJson'], isA<String>());

      final decoded = jsonDecode(body['weatherJson'] as String) as Map;
      expect(decoded['temperature'], 22.2);
      expect(decoded['humidityPercent'], 55);
    });

    test('builds update body with changed coordinates', () {
      final body = WayfinderMarkerMapper.updateBody({
        'latitude': 39.0,
        'longitude': -77.2,
        'comment': 'Updated',
      });

      expect(body['latitude'], 39.0);
      expect(body['longitude'], -77.2);
      expect(body['notes'], 'Updated');
    });
  });
}
