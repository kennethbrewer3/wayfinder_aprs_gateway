import 'dart:convert';

import 'package:test/test.dart';
import 'package:wayfinder_aprs_gateway/src/aprs_parser.dart';
import 'package:wayfinder_aprs_gateway/src/ax25.dart';
import 'package:wayfinder_aprs_gateway/src/wayfinder_weather_json.dart';

void main() {
  group('WayfinderWeatherJson extended fields', () {
    test('maps extended weather measurements into weatherJson', () {
      final weatherJson = WayfinderWeatherJson.buildFromPayload({
        'source': 'aprs',
        'timestamp': '2026-06-29T15:00:00.000Z',
        'weather': {
          'temperature': 22.4,
          'humidity': 58,
          'luminosity': 850,
          'solarRadiation': 18.5,
          'uvIndex': 6,
          'snowfall': 2.5,
          'waterLevel': 1.42,
          'soilTemperature': 14.2,
          'soilMoisture': 38,
          'leafWetness': 12,
          'indoorTemperature': 21.0,
          'indoorHumidityPercent': 45,
          'batteryVoltage': 13.2,
          'windRun': 48.5,
          'stationStatus': 'OK',
          'sensorHealth': 'All sensors reporting',
        },
      });

      expect(weatherJson, isNotNull);
      final decoded = jsonDecode(weatherJson!) as Map<String, dynamic>;
      expect(decoded['luminosity'], 850);
      expect(decoded['luminosityUnit'], 'W/m²');
      expect(decoded['solarRadiation'], 18.5);
      expect(decoded['uvIndex'], 6);
      expect(decoded['snowfall'], 2.5);
      expect(decoded['waterLevel'], 1.42);
      expect(decoded['soilTemperature'], 14.2);
      expect(decoded['soilMoisture'], 38);
      expect(decoded['leafWetness'], 12);
      expect(decoded['indoorTemperature'], 21.0);
      expect(decoded['indoorHumidityPercent'], 45);
      expect(decoded['batteryVoltage'], 13.2);
      expect(decoded['windRun'], 48.5);
      expect(decoded['stationStatus'], 'OK');
      expect(decoded['sensorHealth'], 'All sensors reporting');
    });

    test('derives dew point when not transmitted', () {
      final weatherJson = WayfinderWeatherJson.buildFromPayload({
        'timestamp': '2026-06-29T15:00:00.000Z',
        'weather': {
          'temperature': 22.0,
          'humidity': 60,
        },
      });

      final decoded = jsonDecode(weatherJson!) as Map<String, dynamic>;
      expect(decoded['dewPoint'], isA<num>());
      expect(decoded['dewPointUnit'], 'C');
    });

    test('preserves explicit dew point over derived value', () {
      final weatherJson = WayfinderWeatherJson.buildFromPayload({
        'timestamp': '2026-06-29T15:00:00.000Z',
        'weather': {
          'temperature': 22.0,
          'humidity': 60,
          'dewPoint': 12.3,
        },
      });

      final decoded = jsonDecode(weatherJson!) as Map<String, dynamic>;
      expect(decoded['dewPoint'], 12.3);
    });

    test('maps APRS luminosity and snow parser fields', () {
      final frame = Ax25Frame(
        destination: 'APRS',
        source: 'WX0ABC',
        path: const [],
        info: '=3852.59N/07707.40W_c180s004g008t068r000h62b10142L850s.10 Backyard WX',
      );

      final message = AprsParser.parse(frame);
      expect(message, isNotNull);
      expect(message!.weather!['luminosity'], 850);
      expect(message.weather!['snow'], closeTo(2.54, 0.01));

      final weatherJson = WayfinderWeatherJson.buildFromPayload(
        message.toPayload(
          stationId: 'WX0ABC',
          destination: 'APRS',
          path: const [],
          rawAprs: frame.info,
        ),
      );

      final decoded = jsonDecode(weatherJson!) as Map<String, dynamic>;
      expect(decoded['luminosity'], 850);
      expect(decoded['snowfall'], closeTo(2.5, 0.1));
    });
  });
}
