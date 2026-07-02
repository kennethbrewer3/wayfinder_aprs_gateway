import 'dart:math' as math;

class SimulatorWaypoint {
  SimulatorWaypoint({
    required this.latitude,
    required this.longitude,
  });

  factory SimulatorWaypoint.fromJson(Map<String, dynamic> json) {
    return SimulatorWaypoint(
      latitude: _requireDouble(json, 'latitude'),
      longitude: _requireDouble(json, 'longitude'),
    );
  }

  final double latitude;
  final double longitude;
}

/// Moves along waypoint segments with linear interpolation.
class WaypointPath {
  WaypointPath(
    List<SimulatorWaypoint> waypoints, {
    this.loop = true,
  }) : _segments = _buildSegments(waypoints, loop: loop) {
    if (_segments.isEmpty) {
      throw ArgumentError('WaypointPath requires at least two waypoints');
    }
    _position = _segments.first.start;
  }

  final bool loop;
  final List<_PathSegment> _segments;
  var _segmentIndex = 0;
  var _segmentProgressKm = 0.0;
  late WaypointPosition _position;

  WaypointPosition get position => _position;

  int get course => _segments[_segmentIndex].course;

  void advance(double distanceKm) {
    if (distanceKm <= 0) return;

    var remaining = distanceKm;
    while (remaining > 0) {
      final segment = _segments[_segmentIndex];
      if (segment.lengthKm == 0) {
        if (!loop && _segmentIndex == _segments.length - 1) {
          _position = segment.end;
          return;
        }
        _segmentIndex = _nextSegmentIndex(_segmentIndex);
        _segmentProgressKm = 0;
        _position = _segments[_segmentIndex].start;
        continue;
      }

      if (!loop && _segmentIndex == _segments.length - 1) {
        final remainingOnSegment = segment.lengthKm - _segmentProgressKm;
        if (remainingOnSegment <= 0) {
          _position = segment.end;
          return;
        }
      }

      final remainingOnSegment = segment.lengthKm - _segmentProgressKm;

      if (remaining <= remainingOnSegment) {
        _segmentProgressKm += remaining;
        _position = segment.interpolate(_segmentProgressKm / segment.lengthKm);
        return;
      }

      remaining -= remainingOnSegment;
      if (!loop && _segmentIndex == _segments.length - 1) {
        _segmentProgressKm = segment.lengthKm;
        _position = segment.end;
        return;
      }

      _segmentIndex = _nextSegmentIndex(_segmentIndex);
      _segmentProgressKm = 0;
      _position = _segments[_segmentIndex].start;
    }
  }

  int _nextSegmentIndex(int current) {
    final next = current + 1;
    if (next < _segments.length) return next;
    return loop ? 0 : current;
  }

  static List<_PathSegment> _buildSegments(
    List<SimulatorWaypoint> waypoints, {
    required bool loop,
  }) {
    if (waypoints.length < 2) return const [];

    final segments = <_PathSegment>[];
    for (var i = 0; i < waypoints.length - 1; i++) {
      segments.add(
        _PathSegment(
          start: WaypointPosition.fromWaypoint(waypoints[i]),
          end: WaypointPosition.fromWaypoint(waypoints[i + 1]),
        ),
      );
    }

    if (loop && waypoints.length > 2) {
      segments.add(
        _PathSegment(
          start: WaypointPosition.fromWaypoint(waypoints.last),
          end: WaypointPosition.fromWaypoint(waypoints.first),
        ),
      );
    }

    return segments;
  }
}

class WaypointPosition {
  const WaypointPosition({
    required this.latitude,
    required this.longitude,
  });

  factory WaypointPosition.fromWaypoint(SimulatorWaypoint waypoint) {
    return WaypointPosition(
      latitude: waypoint.latitude,
      longitude: waypoint.longitude,
    );
  }

  final double latitude;
  final double longitude;
}

class _PathSegment {
  _PathSegment({
    required this.start,
    required this.end,
  }) : lengthKm = _distanceKm(
          start.latitude,
          start.longitude,
          end.latitude,
          end.longitude,
        ),
        course = _bearingTo(
          start.latitude,
          start.longitude,
          end.latitude,
          end.longitude,
        ).round();

  final WaypointPosition start;
  final WaypointPosition end;
  final double lengthKm;
  final int course;

  WaypointPosition interpolate(double fraction) {
    final t = fraction.clamp(0.0, 1.0);
    return WaypointPosition(
      latitude: start.latitude + (end.latitude - start.latitude) * t,
      longitude: start.longitude + (end.longitude - start.longitude) * t,
    );
  }
}

double _requireDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw FormatException('Missing or invalid "$key" in simulator config');
}

double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final deltaLat = (lat2 - lat1) * math.pi / 180;
  final deltaLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
      math.cos(phi1) *
          math.cos(phi2) *
          math.sin(deltaLon / 2) *
          math.sin(deltaLon / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _bearingTo(
  double fromLat,
  double fromLon,
  double toLat,
  double toLon,
) {
  final lat1 = fromLat * math.pi / 180;
  final lat2 = toLat * math.pi / 180;
  final deltaLon = (toLon - fromLon) * math.pi / 180;

  final y = math.sin(deltaLon) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(deltaLon);

  return _normalizeBearing(math.atan2(y, x) * 180 / math.pi);
}

double _normalizeBearing(double bearing) {
  var normalized = bearing % 360;
  if (normalized < 0) normalized += 360;
  return normalized;
}

double degreesToRadians(double degrees) => degrees * math.pi / 180.0;
