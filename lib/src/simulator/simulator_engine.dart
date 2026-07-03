import 'dart:math' as math;

import '../aprs_message.dart';
import '../aprs_packet.dart';
import 'aprs_info_builder.dart';
import 'simulator_config.dart';
import 'waypoint_path.dart';

class SimulatorEngine {
  SimulatorEngine(this.config)
      : _states = config.stations.map(_StationState.new).toList();

  final SimulatorConfig config;
  final List<_StationState> _states;

  List<AprsPacket> buildPackets() {
    final packets = <AprsPacket>[];

    for (final state in _states) {
      if (state.config.type == SimulatorStationType.weather) {
        packets.add(state.buildPacket());
        state.advance(config.interval);
      } else {
        state.advance(config.interval);
        packets.add(state.buildPacket());
      }
    }

    return packets;
  }
}

class _StationState {
  _StationState(SimulatorStationConfig config)
      : config = config,
        latitude = config.latitude,
        longitude = config.longitude,
        course = config.course ?? 0,
        _waypointPath = _buildWaypointPath(config),
        _weather = config.initialWeather;

  final SimulatorStationConfig config;
  double latitude;
  double longitude;
  int course;
  final WaypointPath? _waypointPath;
  SimulatorWeatherSettings _weather;
  var _weatherStep = 0;

  static WaypointPath? _buildWaypointPath(SimulatorStationConfig config) {
    if (config.waypoints.length < 2) return null;
    return WaypointPath(
      config.waypoints,
      loop: config.loopWaypoints,
    );
  }

  void advance(Duration interval) {
    if (config.type == SimulatorStationType.weather) {
      _advanceWeather();
      return;
    }

    if (!config.type.isMobile) return;

    final distanceKm =
        config.resolvedSpeedKnots * 1.852 * (interval.inSeconds / 3600);

    if (_waypointPath != null) {
      _waypointPath.advance(distanceKm);
      final position = _waypointPath.position;
      latitude = position.latitude;
      longitude = position.longitude;
      course = _waypointPath.course;
      return;
    }

    _advanceByCourse(distanceKm);
  }

  void _advanceWeather() {
    final sequence = config.weatherSequence;
    if (sequence.length <= 1) return;

    if (config.weatherLoop) {
      _weatherStep = (_weatherStep + 1) % sequence.length;
    } else if (_weatherStep < sequence.length - 1) {
      _weatherStep++;
    }

    _weather = sequence[_weatherStep];
  }

  void _advanceByCourse(double distanceKm) {
    final moved = _move(latitude, longitude, course.toDouble(), distanceKm);
    latitude = moved.latitude;
    longitude = moved.longitude;
  }

  AprsPacket buildPacket() {
    return AprsPacket(
      source: config.callsign,
      destination: config.destination,
      path: config.path,
      rawAprs: _buildRawAprs(),
      message: _buildMessage(),
    );
  }

  String _buildRawAprs() {
    switch (config.type) {
      case SimulatorStationType.weather:
        return AprsInfoBuilder.weatherPosition(
          latitude: latitude,
          longitude: longitude,
          weather: _weather,
          comment: config.comment,
        );
      case SimulatorStationType.car:
      case SimulatorStationType.boat:
      case SimulatorStationType.aircraft:
      case SimulatorStationType.hiker:
      case SimulatorStationType.train:
      case SimulatorStationType.mobile:
      case SimulatorStationType.repeater:
        return AprsInfoBuilder.uncompressedPosition(
          latitude: latitude,
          longitude: longitude,
          symbolTable: config.resolvedSymbolTable,
          symbolCode: config.resolvedSymbolCode,
          comment: config.comment,
        );
    }
  }

  AprsMessage _buildMessage() {
    switch (config.type) {
      case SimulatorStationType.weather:
        return AprsMessage(
          packetType: AprsPacketType.weather,
          format: 'weather-position',
          latitude: latitude,
          longitude: longitude,
          symbolTable: '/',
          symbolCode: '_',
          comment: config.comment,
          markerColor: config.color,
          weather: _weather.toWeatherMap(),
        );
      case SimulatorStationType.car:
      case SimulatorStationType.boat:
      case SimulatorStationType.aircraft:
      case SimulatorStationType.hiker:
      case SimulatorStationType.train:
      case SimulatorStationType.mobile:
        return AprsMessage(
          packetType: AprsPacketType.position,
          format: 'simulator-${config.transportationMode ?? config.type.name}',
          latitude: latitude,
          longitude: longitude,
          symbolTable: config.resolvedSymbolTable,
          symbolCode: config.resolvedSymbolCode,
          comment: config.comment,
          course: course,
          speed: config.resolvedSpeedKnots,
          altitude: _altitudeForConfig(config),
          isTracking: true,
          transportationMode: config.transportationMode,
          markerColor: config.color,
        );
      case SimulatorStationType.repeater:
        return AprsMessage(
          packetType: AprsPacketType.repeater,
          format: 'simulator-repeater',
          latitude: latitude,
          longitude: longitude,
          symbolTable: config.resolvedSymbolTable,
          symbolCode: config.resolvedSymbolCode,
          comment: config.comment,
          markerColor: config.color,
        );
    }
  }
}

int? _altitudeForConfig(SimulatorStationConfig config) {
  if (config.altitudeMeters != null) {
    return config.altitudeMeters;
  }

  return switch (config.transportationMode) {
    'aircraft' || 'helicopter' || 'glider' || 'balloon' => 3500,
    _ => null,
  };
}

({double latitude, double longitude}) _move(
  double latitude,
  double longitude,
  double bearingDegrees,
  double distanceKm,
) {
  final bearing = degreesToRadians(bearingDegrees);
  final latRadians = degreesToRadians(latitude);
  final angularDistance = distanceKm / 6371.0;

  final newLat = math.asin(
    math.sin(latRadians) * math.cos(angularDistance) +
        math.cos(latRadians) *
            math.sin(angularDistance) *
            math.cos(bearing),
  );

  final newLon = degreesToRadians(longitude) +
      math.atan2(
        math.sin(bearing) * math.sin(angularDistance) * math.cos(latRadians),
        math.cos(angularDistance) - math.sin(latRadians) * math.sin(newLat),
      );

  return (
    latitude: newLat * 180 / math.pi,
    longitude: _normalizeLongitude(newLon * 180 / math.pi),
  );
}

double _normalizeLongitude(double longitude) {
  var normalized = longitude;
  while (normalized <= -180) {
    normalized += 360;
  }
  while (normalized > 180) {
    normalized -= 360;
  }
  return normalized;
}
