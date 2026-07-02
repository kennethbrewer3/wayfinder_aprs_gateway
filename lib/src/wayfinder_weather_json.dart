import 'dart:convert';

/// Builds Wayfinder marker `weatherJson` payloads for the weather station UI.
abstract final class WayfinderWeatherJson {
  static const maxHistoryEntries = 20;

  static String? buildFromPayload(
    Map<String, dynamic> payload, {
    String? existingWeatherJson,
  }) {
    final reading = _readingFromPayload(payload);
    if (reading == null) {
      return null;
    }

    final history = _historyFromExisting(existingWeatherJson);
    final observedAt = reading['observedAt'] as String;
    history.removeWhere((entry) => entry['observedAt'] == observedAt);

    final previousLatest = _latestFromExisting(existingWeatherJson);
    if (previousLatest != null &&
        previousLatest['observedAt'] != observedAt &&
        !history.any(
          (entry) => entry['observedAt'] == previousLatest['observedAt'],
        )) {
      history.insert(0, previousLatest);
    }

    history.sort(
      (a, b) => (b['observedAt'] as String).compareTo(a['observedAt'] as String),
    );

    final snapshot = {
      ...reading,
      if (history.isNotEmpty) 'history': history.take(maxHistoryEntries).toList(),
    };

    return jsonEncode(snapshot);
  }

  static Map<String, dynamic>? _readingFromPayload(Map<String, dynamic> payload) {
    final weather = payload['weather'];
    if (weather is! Map) {
      return null;
    }

    final weatherMap = Map<String, dynamic>.from(weather);
    final observedAt = payload['timestamp']?.toString();
    final parsedObservedAt = observedAt == null
        ? DateTime.now().toUtc()
        : DateTime.tryParse(observedAt)?.toUtc() ?? DateTime.now().toUtc();

    final temperature = _optionalDouble(weatherMap['temperature']);
    final humidity = _optionalInt(weatherMap['humidity']);
    final pressure = _optionalDouble(weatherMap['pressure']);
    final windDirection = _optionalInt(weatherMap['windDirection']);
    final windSpeedMs = _optionalDouble(weatherMap['windSpeed']);
    final precipitationMm = _precipitationMm(weatherMap);
    final inferred = _inferCondition(
      precipitationMm: precipitationMm,
      humidity: humidity,
    );

    final reading = <String, dynamic>{
      'observedAt': parsedObservedAt.toIso8601String(),
      'source': payload['source']?.toString() ?? 'aprs',
      if (temperature != null) ...{
        'temperature': _round(temperature, 1),
        'temperatureUnit': 'C',
      },
      if (humidity != null) 'humidityPercent': humidity,
      if (precipitationMm != null && precipitationMm > 0) ...{
        'precipitation': _round(precipitationMm, 1),
        'precipitationUnit': 'mm',
      },
      if (inferred != null) ...{
        'weatherCode': inferred.code,
        'condition': inferred.condition,
      },
      if (windSpeedMs != null) ...{
        'windSpeed': _round(windSpeedMs * 3.6, 1),
        'windSpeedUnit': 'km/h',
      },
      if (windDirection != null) 'windDirectionDegrees': windDirection,
      if (pressure != null) ...{
        'pressure': _round(pressure, 1),
        'pressureUnit': 'hPa',
      },
    };

    return _hasMeasurements(reading) ? reading : null;
  }

  static List<Map<String, dynamic>> _historyFromExisting(String? raw) {
    final existing = _decodeExisting(raw);
    if (existing == null) {
      return [];
    }

    final historyRaw = existing['history'];
    if (historyRaw is! List) {
      return [];
    }

    return historyRaw
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .where(_hasMeasurements)
        .toList();
  }

  static Map<String, dynamic>? _latestFromExisting(String? raw) {
    final existing = _decodeExisting(raw);
    if (existing == null) {
      return null;
    }

    final latest = Map<String, dynamic>.from(existing)
      ..remove('history');
    return _hasMeasurements(latest) ? latest : null;
  }

  static Map<String, dynamic>? _decodeExisting(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return decoded;
    } catch (_) {
      return null;
    }
  }

  static double? _precipitationMm(Map<String, dynamic> weather) {
    for (final key in ['rain1h', 'rain24h', 'rainSinceMidnight', 'precipitation']) {
      final value = _optionalDouble(weather[key]);
      if (value != null && value > 0) {
        return value;
      }
    }
    return null;
  }

  static _InferredCondition? _inferCondition({
    required double? precipitationMm,
    required int? humidity,
  }) {
    final rain = precipitationMm ?? 0;
    if (rain >= 7.6) {
      return _InferredCondition(code: 65, condition: 'Rain');
    }
    if (rain >= 2.5) {
      return _InferredCondition(code: 63, condition: 'Rain');
    }
    if (rain >= 0.25) {
      return _InferredCondition(code: 80, condition: 'Showers');
    }
    if (rain > 0) {
      return _InferredCondition(code: 51, condition: 'Drizzle');
    }
    if (humidity != null && humidity >= 92) {
      return _InferredCondition(code: 45, condition: 'Fog');
    }
    if (humidity != null && humidity >= 80) {
      return _InferredCondition(code: 3, condition: 'Overcast');
    }
    if (humidity != null && humidity >= 65) {
      return _InferredCondition(code: 2, condition: 'Partly cloudy');
    }
    return _InferredCondition(code: 0, condition: 'Clear');
  }

  static bool _hasMeasurements(Map<String, dynamic> reading) {
    return reading.containsKey('temperature') ||
        reading.containsKey('humidityPercent') ||
        reading.containsKey('precipitation') ||
        reading.containsKey('windSpeed') ||
        reading.containsKey('pressure') ||
        reading.containsKey('weatherCode') ||
        (reading['condition'] is String &&
            (reading['condition'] as String).trim().isNotEmpty);
  }

  static double _round(double value, int fractionDigits) {
    final factor = mathPow10(fractionDigits);
    return (value * factor).roundToDouble() / factor;
  }

  static double mathPow10(int exponent) {
    var value = 1.0;
    for (var i = 0; i < exponent; i++) {
      value *= 10;
    }
    return value;
  }

  static double? _optionalDouble(Object? raw) {
    if (raw is num) {
      return raw.toDouble();
    }
    return null;
  }

  static int? _optionalInt(Object? raw) {
    if (raw is num) {
      return raw.round();
    }
    return null;
  }
}

class _InferredCondition {
  const _InferredCondition({
    required this.code,
    required this.condition,
  });

  final int code;
  final String condition;
}
