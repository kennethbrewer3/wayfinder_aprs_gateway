enum AprsPacketType {
  position,
  mice,
  weather,
  telemetry,
}

class AprsMessage {
  AprsMessage({
    required this.packetType,
    required this.format,
    this.latitude,
    this.longitude,
    this.symbolTable,
    this.symbolCode,
    this.comment,
    this.course,
    this.speed,
    this.altitude,
    this.messageType,
    this.weather,
    this.telemetry,
  });

  final AprsPacketType packetType;
  final String format;
  final double? latitude;
  final double? longitude;
  final String? symbolTable;
  final String? symbolCode;
  final String? comment;
  final int? course;
  final int? speed;
  final int? altitude;
  final String? messageType;
  final Map<String, dynamic>? weather;
  final Map<String, dynamic>? telemetry;

  bool get hasPosition => latitude != null && longitude != null;

  Map<String, dynamic> toPayload({
    required String stationId,
    required String destination,
    required List<String> path,
    required String rawAprs,
  }) {
    return {
      'source': 'aprs',
      'packetType': packetType.name,
      'format': format,
      'stationId': stationId,
      'destination': destination,
      'path': path,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (symbolTable != null) 'symbolTable': symbolTable,
      if (symbolCode != null) 'symbolCode': symbolCode,
      if (comment != null && comment!.isNotEmpty) 'comment': comment,
      if (course != null) 'course': course,
      if (speed != null) 'speed': speed,
      if (altitude != null) 'altitude': altitude,
      if (messageType != null) 'messageType': messageType,
      if (weather != null) 'weather': weather,
      if (telemetry != null) 'telemetry': telemetry,
      'rawAprs': rawAprs,
    };
  }
}
