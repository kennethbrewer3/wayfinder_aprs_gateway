/// Builds human-readable marker notes from APRS weather telemetry.
abstract final class WeatherNotesFormatter {
  static String? notesForPayload(Map<String, dynamic> payload) {
    final weather = payload['weather'];
    final comment = payload['comment']?.toString().trim();

    if (weather is! Map) {
      return comment == null || comment.isEmpty ? null : comment;
    }

    final lines = <String>[];
    final weatherMap = Map<String, dynamic>.from(weather);

    _appendWind(lines, weatherMap);
    _appendTemperature(lines, weatherMap);
    _appendHumidity(lines, weatherMap);
    _appendPressure(lines, weatherMap);
    _appendRain(lines, weatherMap);
    _appendOther(lines, weatherMap);

    if (comment != null && comment.isNotEmpty) {
      lines.add(comment);
    }

    return lines.isEmpty ? null : lines.join('\n');
  }

  static void _appendWind(List<String> lines, Map<String, dynamic> weather) {
    final direction = weather['windDirection'];
    final speedMs = weather['windSpeed'];
    final gustMs = weather['windGust'];

    if (direction is! num && speedMs is! num && gustMs is! num) {
      return;
    }

    final buffer = StringBuffer('Wind:');
    if (direction is num) {
      buffer.write(' ${direction.round()}°');
    }
    if (speedMs is num) {
      buffer.write(' at ${_knots(speedMs)} kt');
    }
    if (gustMs is num && gustMs > 0) {
      buffer.write(', gust ${_knots(gustMs)} kt');
    }

    lines.add(buffer.toString());
  }

  static void _appendTemperature(List<String> lines, Map<String, dynamic> weather) {
    final celsius = weather['temperature'];
    if (celsius is! num) return;

    final fahrenheit = celsius * 9 / 5 + 32;
    lines.add(
      'Temp: ${fahrenheit.round()}°F (${celsius.toStringAsFixed(1)}°C)',
    );
  }

  static void _appendHumidity(List<String> lines, Map<String, dynamic> weather) {
    final humidity = weather['humidity'];
    if (humidity is! num) return;
    lines.add('Humidity: ${humidity.round()}%');
  }

  static void _appendPressure(List<String> lines, Map<String, dynamic> weather) {
    final pressure = weather['pressure'];
    if (pressure is! num) return;
    lines.add('Pressure: ${pressure.toStringAsFixed(1)} mb');
  }

  static void _appendRain(List<String> lines, Map<String, dynamic> weather) {
    _appendRainField(lines, weather, 'rain1h', 'Rain (1h)');
    _appendRainField(lines, weather, 'rain24h', 'Rain (24h)');
    _appendRainField(
      lines,
      weather,
      'rainSinceMidnight',
      'Rain since midnight',
    );
    _appendRainField(lines, weather, 'snow', 'Snow', isSnow: true);
  }

  static void _appendRainField(
    List<String> lines,
    Map<String, dynamic> weather,
    String key,
    String label, {
    bool isSnow = false,
  }) {
    final value = weather[key];
    if (value is! num || value <= 0) return;

    final inches = value / 25.4;
    lines.add(
      '$label: ${inches.toStringAsFixed(2)} in (${value.toStringAsFixed(1)} mm)',
    );
  }

  static void _appendOther(List<String> lines, Map<String, dynamic> weather) {
    final luminosity = weather['luminosity'];
    if (luminosity is num) {
      lines.add('Luminosity: ${luminosity.round()} W/m²');
    }

    final rawTimestamp = weather['rawTimestamp'];
    if (rawTimestamp != null) {
      lines.add('Report time: $rawTimestamp');
    }
  }

  static String _knots(num metersPerSecond) {
    return (metersPerSecond * 1.94384).round().toString();
  }
}
