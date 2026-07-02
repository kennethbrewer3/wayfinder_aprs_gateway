import 'package:test/test.dart';
import 'package:wayfinder_aprs_gateway/src/weather_notes_formatter.dart';

void main() {
  group('WeatherNotesFormatter', () {
    test('formats all weather fields and station comment', () {
      final notes = WeatherNotesFormatter.notesForPayload({
        'packetType': 'weather',
        'comment': 'Backyard WX',
        'weather': {
          'windDirection': 225,
          'windSpeed': 12 * 0.514444,
          'windGust': 18 * 0.514444,
          'temperature': 22.2,
          'humidity': 55,
          'pressure': 1013.8,
          'rain1h': 0.254,
        },
      });

      expect(notes, contains('Wind: 225° at 12 kt, gust 18 kt'));
      expect(notes, contains('Temp: 72°F (22.2°C)'));
      expect(notes, contains('Humidity: 55%'));
      expect(notes, contains('Pressure: 1013.8 mb'));
      expect(notes, contains('Rain (1h): 0.01 in'));
      expect(notes, contains('Backyard WX'));
    });

    test('returns comment only when weather map is absent', () {
      expect(
        WeatherNotesFormatter.notesForPayload({'comment': 'Repeater site'}),
        'Repeater site',
      );
    });
  });
}
