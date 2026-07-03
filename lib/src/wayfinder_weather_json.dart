import 'dart:convert';
import 'dart:math' as math;

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

    const temperatureUnit = 'C';
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
        'temperatureUnit': temperatureUnit,
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
      ..._extendedFieldsFromWeather(weatherMap, temperatureUnit: temperatureUnit),
    };

    final explicitDewPoint = _optionalDouble(weatherMap['dewPoint']);
    final dewPoint = explicitDewPoint ??
        (temperature != null && humidity != null
            ? _deriveDewPointCelsius(temperature, humidity)
            : null);
    if (dewPoint != null) {
      reading['dewPoint'] = _round(dewPoint, 1);
      reading['dewPointUnit'] = temperatureUnit;
    }

    return _hasMeasurements(reading) ? reading : null;
  }

  static Map<String, dynamic> _extendedFieldsFromWeather(
    Map<String, dynamic> weather, {
    required String temperatureUnit,
  }) {
    final fields = <String, dynamic>{};

    void addDouble(
      String sourceKey,
      String outputKey, {
      int fractionDigits = 1,
      String? unitKey,
      String? unit,
      Iterable<String> aliases = const [],
    }) {
      final value = _firstDouble(weather, [sourceKey, ...aliases]);
      if (value == null) {
        return;
      }
      fields[outputKey] = _round(value, fractionDigits);
      if (unitKey != null && unit != null) {
        fields[unitKey] = unit;
      }
    }

    void addInt(String sourceKey, String outputKey, {Iterable<String> aliases = const []}) {
      final value = _firstInt(weather, [sourceKey, ...aliases]);
      if (value != null) {
        fields[outputKey] = value;
      }
    }

    void addText(String sourceKey, String outputKey) {
      final value = weather[sourceKey]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        fields[outputKey] = value;
      }
    }

    addDouble('luminosity', 'luminosity', unitKey: 'luminosityUnit', unit: 'W/m²');
    addDouble(
      'solarRadiation',
      'solarRadiation',
      unitKey: 'solarRadiationUnit',
      unit: 'MJ/m²',
    );
    addDouble('uvIndex', 'uvIndex', fractionDigits: 1);
    addDouble('snowfall', 'snowfall', unitKey: 'snowfallUnit', unit: 'mm', aliases: ['snow']);
    addDouble('waterLevel', 'waterLevel', fractionDigits: 2, unitKey: 'waterLevelUnit', unit: 'm');
    addDouble(
      'soilTemperature',
      'soilTemperature',
      unitKey: 'soilTemperatureUnit',
      unit: temperatureUnit,
    );
    addDouble(
      'soilMoisture',
      'soilMoisture',
      unitKey: 'soilMoistureUnit',
      unit: '%',
    );
    addDouble(
      'leafWetness',
      'leafWetness',
      unitKey: 'leafWetnessUnit',
      unit: '%',
    );
    addDouble(
      'indoorTemperature',
      'indoorTemperature',
      unitKey: 'indoorTemperatureUnit',
      unit: temperatureUnit,
    );
    addInt(
      'indoorHumidityPercent',
      'indoorHumidityPercent',
      aliases: ['indoorHumidity'],
    );
    addDouble(
      'batteryVoltage',
      'batteryVoltage',
      fractionDigits: 2,
      unitKey: 'batteryVoltageUnit',
      unit: 'V',
    );
    addDouble('windRun', 'windRun', unitKey: 'windRunUnit', unit: 'km');
    addText('stationStatus', 'stationStatus');
    addText('sensorHealth', 'sensorHealth');

    return fields;
  }

  static double? _deriveDewPointCelsius(double temperatureC, int humidityPercent) {
    if (humidityPercent <= 0 || humidityPercent > 100) {
      return null;
    }

    const a = 17.27;
    const b = 237.7;
    final relativeHumidity = humidityPercent / 100.0;
    final gamma =
        (a * temperatureC) / (b + temperatureC) + math.log(relativeHumidity);
    return (b * gamma) / (a - gamma);
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
    const measurementKeys = {
      'temperature',
      'humidityPercent',
      'precipitation',
      'windSpeed',
      'pressure',
      'weatherCode',
      'dewPoint',
      'luminosity',
      'solarRadiation',
      'uvIndex',
      'snowfall',
      'waterLevel',
      'soilTemperature',
      'soilMoisture',
      'leafWetness',
      'indoorTemperature',
      'indoorHumidityPercent',
      'batteryVoltage',
      'windRun',
      'stationStatus',
      'sensorHealth',
    };

    if (measurementKeys.any(reading.containsKey)) {
      return true;
    }

    return reading['condition'] is String &&
        (reading['condition'] as String).trim().isNotEmpty;
  }

  static double? _firstDouble(
    Map<String, dynamic> weather,
    Iterable<String> keys,
  ) {
    for (final key in keys) {
      final value = _optionalDouble(weather[key]);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  static int? _firstInt(Map<String, dynamic> weather, Iterable<String> keys) {
    for (final key in keys) {
      final value = _optionalInt(weather[key]);
      if (value != null) {
        return value;
      }
    }
    return null;
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
