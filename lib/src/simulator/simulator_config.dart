import 'dart:convert';
import 'dart:io';

import '../wayfinder_transportation_modes.dart';
import 'waypoint_path.dart';

enum SimulatorStationType {
  mobile,
  car,
  boat,
  aircraft,
  hiker,
  train,
  weather,
  repeater;

  static SimulatorStationType parse(String value) {
    final key = value.trim();
    final lower = key.toLowerCase();

    if (WayfinderTransportationModes.contains(key)) {
      return SimulatorStationType.mobile;
    }

    switch (lower) {
      case 'car':
      case 'vehicle':
        return SimulatorStationType.car;
      case 'boat':
        return SimulatorStationType.boat;
      case 'aircraft':
      case 'plane':
        return SimulatorStationType.aircraft;
      case 'hiker':
      case 'pedestrian':
        return SimulatorStationType.hiker;
      case 'train':
        return SimulatorStationType.train;
      case 'weather':
      case 'weather_station':
        return SimulatorStationType.weather;
      case 'repeater':
      case 'fixed':
        return SimulatorStationType.repeater;
      default:
        throw ArgumentError.value(
          value,
          'type',
          'Supported values: Wayfinder transportation modes, car, boat, '
          'aircraft, hiker, train, weather, repeater',
        );
    }
  }

  bool get isMobile {
    switch (this) {
      case SimulatorStationType.weather:
      case SimulatorStationType.repeater:
        return false;
      case SimulatorStationType.mobile:
      case SimulatorStationType.car:
      case SimulatorStationType.boat:
      case SimulatorStationType.aircraft:
      case SimulatorStationType.hiker:
      case SimulatorStationType.train:
        return true;
    }
  }
}

class SimulatorWeatherSettings {
  SimulatorWeatherSettings({
    this.windDirection = 180,
    this.windSpeedKnots = 0,
    this.windGustKnots = 0,
    this.temperatureF = 72,
    this.humidity = 50,
    this.pressureMb = 1013.2,
    this.rain1hInches = 0,
    this.luminosity,
    this.solarRadiation,
    this.uvIndex,
    this.snowfallInches,
    this.waterLevelMeters,
    this.soilTemperatureF,
    this.soilMoisture,
    this.leafWetness,
    this.indoorTemperatureF,
    this.indoorHumidity,
    this.batteryVoltage,
    this.windRunKm,
    this.stationStatus,
    this.sensorHealth,
    this.dewPointF,
  });

  factory SimulatorWeatherSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return SimulatorWeatherSettings();

    return SimulatorWeatherSettings(
      windDirection: _optionalInt(json, 'windDirection') ?? 180,
      windSpeedKnots: _optionalInt(json, 'windSpeedKnots') ?? 0,
      windGustKnots: _optionalInt(json, 'windGustKnots') ?? 0,
      temperatureF: _optionalInt(json, 'temperatureF') ?? 72,
      humidity: _optionalInt(json, 'humidity') ?? 50,
      pressureMb: _optionalDouble(json, 'pressureMb') ?? 1013.2,
      rain1hInches: _optionalDouble(json, 'rain1hInches') ?? 0,
      luminosity: _optionalDouble(json, 'luminosity'),
      solarRadiation: _optionalDouble(json, 'solarRadiation'),
      uvIndex: _optionalDouble(json, 'uvIndex'),
      snowfallInches: _optionalDouble(json, 'snowfallInches'),
      waterLevelMeters: _optionalDouble(json, 'waterLevelMeters'),
      soilTemperatureF: _optionalDouble(json, 'soilTemperatureF'),
      soilMoisture: _optionalDouble(json, 'soilMoisture'),
      leafWetness: _optionalDouble(json, 'leafWetness'),
      indoorTemperatureF: _optionalDouble(json, 'indoorTemperatureF'),
      indoorHumidity: _optionalInt(json, 'indoorHumidity'),
      batteryVoltage: _optionalDouble(json, 'batteryVoltage'),
      windRunKm: _optionalDouble(json, 'windRunKm'),
      stationStatus: json['stationStatus'] as String?,
      sensorHealth: json['sensorHealth'] as String?,
      dewPointF: _optionalDouble(json, 'dewPointF'),
    );
  }

  final int windDirection;
  final int windSpeedKnots;
  final int windGustKnots;
  final int temperatureF;
  final int humidity;
  final double pressureMb;
  final double rain1hInches;
  final double? luminosity;
  final double? solarRadiation;
  final double? uvIndex;
  final double? snowfallInches;
  final double? waterLevelMeters;
  final double? soilTemperatureF;
  final double? soilMoisture;
  final double? leafWetness;
  final double? indoorTemperatureF;
  final int? indoorHumidity;
  final double? batteryVoltage;
  final double? windRunKm;
  final String? stationStatus;
  final String? sensorHealth;
  final double? dewPointF;

  Map<String, dynamic> toWeatherMap() {
    final humidityValue = humidity == 0 ? 100 : humidity;

    return {
      'windDirection': windDirection,
      'windSpeed': windSpeedKnots * 0.514444,
      'windGust': windGustKnots * 0.514444,
      'temperature': (temperatureF - 32) / 1.8,
      'humidity': humidityValue,
      'pressure': pressureMb,
      'rain1h': rain1hInches * 25.4,
      if (luminosity != null) 'luminosity': luminosity,
      if (solarRadiation != null) 'solarRadiation': solarRadiation,
      if (uvIndex != null) 'uvIndex': uvIndex,
      if (snowfallInches != null) 'snowfall': snowfallInches! * 25.4,
      if (waterLevelMeters != null) 'waterLevel': waterLevelMeters,
      if (soilTemperatureF != null)
        'soilTemperature': (soilTemperatureF! - 32) / 1.8,
      if (soilMoisture != null) 'soilMoisture': soilMoisture,
      if (leafWetness != null) 'leafWetness': leafWetness,
      if (indoorTemperatureF != null)
        'indoorTemperature': (indoorTemperatureF! - 32) / 1.8,
      if (indoorHumidity != null) 'indoorHumidityPercent': indoorHumidity,
      if (batteryVoltage != null) 'batteryVoltage': batteryVoltage,
      if (windRunKm != null) 'windRun': windRunKm,
      if (stationStatus != null && stationStatus!.trim().isNotEmpty)
        'stationStatus': stationStatus!.trim(),
      if (sensorHealth != null && sensorHealth!.trim().isNotEmpty)
        'sensorHealth': sensorHealth!.trim(),
      if (dewPointF != null) 'dewPoint': (dewPointF! - 32) / 1.8,
    };
  }

  SimulatorWeatherSettings copyWith({
    int? windDirection,
    int? windSpeedKnots,
    int? windGustKnots,
    int? temperatureF,
    int? humidity,
    double? pressureMb,
    double? rain1hInches,
  }) {
    return SimulatorWeatherSettings(
      windDirection: windDirection ?? this.windDirection,
      windSpeedKnots: windSpeedKnots ?? this.windSpeedKnots,
      windGustKnots: windGustKnots ?? this.windGustKnots,
      temperatureF: temperatureF ?? this.temperatureF,
      humidity: humidity ?? this.humidity,
      pressureMb: pressureMb ?? this.pressureMb,
      rain1hInches: rain1hInches ?? this.rain1hInches,
      luminosity: luminosity,
      solarRadiation: solarRadiation,
      uvIndex: uvIndex,
      snowfallInches: snowfallInches,
      waterLevelMeters: waterLevelMeters,
      soilTemperatureF: soilTemperatureF,
      soilMoisture: soilMoisture,
      leafWetness: leafWetness,
      indoorTemperatureF: indoorTemperatureF,
      indoorHumidity: indoorHumidity,
      batteryVoltage: batteryVoltage,
      windRunKm: windRunKm,
      stationStatus: stationStatus,
      sensorHealth: sensorHealth,
      dewPointF: dewPointF,
    );
  }
}

class SimulatorStationConfig {
  SimulatorStationConfig({
    required this.callsign,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.destination = 'APRS',
    this.path = const [],
    this.comment,
    this.color,
    this.symbolTable,
    this.symbolCode,
    this.course,
    this.speedKnots,
    this.altitudeMeters,
    this.waypoints = const [],
    this.loopWaypoints = true,
    SimulatorWeatherSettings? weather,
    this.weatherSequence = const [],
    this.weatherLoop = true,
    this.intervalSeconds,
    this.transportationModeOverride,
    this.typeName = '',
  }) : weather = weather ?? SimulatorWeatherSettings();

  factory SimulatorStationConfig.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String;
    final type = SimulatorStationType.parse(typeName);
    final waypoints = _optionalWaypoints(json['waypoints'] ?? json['route']);

    final latitude = waypoints.isNotEmpty
        ? waypoints.first.latitude
        : _requireDouble(json, 'latitude');
    final longitude = waypoints.isNotEmpty
        ? waypoints.first.longitude
        : _requireDouble(json, 'longitude');

    return SimulatorStationConfig(
      callsign: json['callsign'] as String,
      type: type,
      typeName: typeName,
      latitude: latitude,
      longitude: longitude,
      destination: json['destination'] as String? ?? 'APRS',
      path: _optionalStringList(json, 'path'),
      comment: json['comment'] as String?,
      color: json['color'] as String?,
      symbolTable: json['symbolTable'] as String?,
      symbolCode: json['symbolCode'] as String?,
      course: _optionalInt(json, 'course'),
      speedKnots: _optionalInt(json, 'speedKnots'),
      altitudeMeters: _optionalInt(json, 'altitudeMeters'),
      waypoints: waypoints,
      loopWaypoints: json['loop'] is bool ? json['loop'] as bool : true,
      weather: json['weather'] is Map<String, dynamic>
          ? SimulatorWeatherSettings.fromJson(
              Map<String, dynamic>.from(json['weather'] as Map),
            )
          : SimulatorWeatherSettings(),
      weatherSequence: _optionalWeatherSequence(json['weatherSequence']),
      weatherLoop: json['loopWeather'] is bool
          ? json['loopWeather'] as bool
          : true,
      intervalSeconds: _optionalInt(json, 'intervalSeconds'),
      transportationModeOverride: _optionalTransportationMode(json),
    );
  }

  final String callsign;
  final SimulatorStationType type;
  final String typeName;
  final double latitude;
  final double longitude;
  final String destination;
  final List<String> path;
  final String? comment;
  final String? color;
  final String? symbolTable;
  final String? symbolCode;
  final int? course;
  final int? speedKnots;
  final int? altitudeMeters;
  final List<SimulatorWaypoint> waypoints;
  final bool loopWaypoints;
  final SimulatorWeatherSettings weather;
  final List<SimulatorWeatherSettings> weatherSequence;
  final bool weatherLoop;
  final int? intervalSeconds;
  final String? transportationModeOverride;

  SimulatorWeatherSettings get initialWeather =>
      weatherSequence.isNotEmpty ? weatherSequence.first : weather;

  bool get isTracking => type.isMobile;

  String? get transportationMode {
    if (transportationModeOverride != null) {
      return transportationModeOverride;
    }
    if (WayfinderTransportationModes.contains(typeName)) {
      return typeName;
    }

    switch (type) {
      case SimulatorStationType.car:
        return 'landVehicle';
      case SimulatorStationType.boat:
        return 'watercraft';
      case SimulatorStationType.aircraft:
        return 'aircraft';
      case SimulatorStationType.hiker:
        return 'onFoot';
      case SimulatorStationType.train:
        return 'train';
      case SimulatorStationType.mobile:
      case SimulatorStationType.weather:
      case SimulatorStationType.repeater:
        return null;
    }
  }

  String get resolvedSymbolTable {
    if (symbolTable != null) {
      return symbolTable!;
    }
    if (transportationMode == 'train') {
      return r'\';
    }
    return '/';
  }

  String get resolvedSymbolCode {
    if (symbolCode != null) {
      return symbolCode!;
    }

    return switch (transportationMode) {
      'onFoot' => '[',
      'horse' => '[',
      'bike' => 'b',
      'motorcycle' => '<',
      'atv' => '<',
      'landVehicle' => '>',
      'truck' || 'bus' || 'rv' || 'farmVehicle' => 'k',
      'train' => 'L',
      'ambulance' => 'a',
      'fireTruck' => 'f',
      'canoe' || 'watercraft' => 's',
      'sailboat' => 'Y',
      'aircraft' => '^',
      'helicopter' => 'n',
      'glider' => '^',
      'balloon' => 'O',
      _ => defaultSymbolCode(type),
    };
  }

  int get resolvedSpeedKnots => speedKnots ?? defaultSpeedKnots(type, transportationMode);

  static String defaultSymbolTable(SimulatorStationType type) {
    switch (type) {
      case SimulatorStationType.train:
        return r'\';
      default:
        return '/';
    }
  }

  static String defaultSymbolCode(SimulatorStationType type) {
    switch (type) {
      case SimulatorStationType.car:
        return '>';
      case SimulatorStationType.boat:
        return 's';
      case SimulatorStationType.aircraft:
        return '^';
      case SimulatorStationType.hiker:
        return '[';
      case SimulatorStationType.train:
        return 'L';
      case SimulatorStationType.mobile:
        return '>';
      case SimulatorStationType.weather:
        return '_';
      case SimulatorStationType.repeater:
        return '#';
    }
  }

  static int defaultSpeedKnots(
    SimulatorStationType type,
    String? transportationMode,
  ) {
    if (transportationMode != null) {
      return switch (transportationMode) {
        'onFoot' || 'horse' => 3,
        'bike' => 12,
        'motorcycle' || 'atv' => 35,
        'landVehicle' || 'truck' || 'bus' || 'rv' || 'farmVehicle' => 35,
        'train' => 40,
        'ambulance' || 'fireTruck' => 45,
        'canoe' => 4,
        'watercraft' => 15,
        'sailboat' => 8,
        'aircraft' || 'helicopter' || 'glider' => 90,
        'balloon' => 5,
        _ => 20,
      };
    }

    switch (type) {
      case SimulatorStationType.car:
        return 35;
      case SimulatorStationType.boat:
        return 15;
      case SimulatorStationType.aircraft:
        return 150;
      case SimulatorStationType.hiker:
        return 3;
      case SimulatorStationType.train:
        return 40;
      case SimulatorStationType.mobile:
        return 20;
      case SimulatorStationType.weather:
      case SimulatorStationType.repeater:
        return 0;
    }
  }
}

class SimulatorConfig {
  SimulatorConfig({
    required this.interval,
    required this.stations,
  });

  factory SimulatorConfig.fromJson(Map<String, dynamic> json) {
    final stationsJson = json['stations'];
    if (stationsJson is! List || stationsJson.isEmpty) {
      throw FormatException('Simulator config requires a non-empty stations list');
    }

    return SimulatorConfig(
      interval: Duration(
        seconds: _optionalInt(json, 'intervalSeconds') ?? 30,
      ),
      stations: stationsJson
          .map(
            (station) => SimulatorStationConfig.fromJson(
              Map<String, dynamic>.from(station as Map),
            ),
          )
          .toList(),
    );
  }

  static SimulatorConfig load(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('Simulator config file not found: $path');
    }

    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Simulator config must contain a JSON object: $path');
    }

    return SimulatorConfig.fromJson(decoded);
  }

  final Duration interval;
  final List<SimulatorStationConfig> stations;
}

double _requireDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw FormatException('Missing or invalid "$key" in simulator config');
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  throw FormatException('Invalid "$key" in simulator config');
}

double? _optionalDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw FormatException('Invalid "$key" in simulator config');
}

List<String> _optionalStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return const [];
  if (value is! List) {
    throw FormatException('Invalid "$key" in simulator config');
  }
  return value.map((item) => item.toString()).toList();
}

List<SimulatorWaypoint> _optionalWaypoints(Object? value) {
  if (value == null) return const [];
  if (value is! List) {
    throw FormatException('Invalid waypoints in simulator config');
  }

  return value
      .map(
        (point) => SimulatorWaypoint.fromJson(
          Map<String, dynamic>.from(point as Map),
        ),
      )
      .toList();
}

List<SimulatorWeatherSettings> _optionalWeatherSequence(Object? value) {
  if (value == null) return const [];
  if (value is! List) {
    throw FormatException('Invalid weatherSequence in simulator config');
  }

  return value
      .map(
        (reading) => SimulatorWeatherSettings.fromJson(
          Map<String, dynamic>.from(reading as Map),
        ),
      )
      .toList();
}

String? _optionalTransportationMode(Map<String, dynamic> json) {
  final explicit = json['transportationMode'];
  if (explicit is String && explicit.isNotEmpty) {
    if (!WayfinderTransportationModes.contains(explicit)) {
      throw FormatException('Invalid transportationMode in simulator config');
    }
    return explicit;
  }
  return null;
}
