import 'aprs_repeater.dart';
import 'aprs_transportation_mode.dart';

enum AprsPacketType {
  position,
  mice,
  weather,
  telemetry,
  repeater,
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
    this.isTracking,
    this.transportationMode,
    this.markerColor,
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
  final bool? isTracking;
  final String? transportationMode;
  final String? markerColor;

  bool get hasPosition => latitude != null && longitude != null;

  String? get resolvedTransportationMode => AprsTransportationMode.resolve(
        transportationMode: transportationMode,
        symbolTable: symbolTable,
        symbolCode: symbolCode,
      );

  bool get isRepeater =>
      packetType == AprsPacketType.repeater ||
      AprsRepeater.isSymbol(symbolTable: symbolTable, symbolCode: symbolCode);

  bool get shouldTrack => AprsTransportationMode.shouldTrack(
        packetType: packetType.name,
        hasPosition: hasPosition,
        transportationMode: transportationMode,
        symbolTable: symbolTable,
        symbolCode: symbolCode,
      );

  Map<String, dynamic> toPayload({
    required String stationId,
    required String destination,
    required List<String> path,
    required String rawAprs,
  }) {
    return {
      'source': 'aprs',
      'packetType': isRepeater ? 'repeater' : packetType.name,
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
      if (resolvedTransportationMode != null)
        'transportationMode': resolvedTransportationMode,
      if (shouldTrack || isTracking == true) 'isTracking': true,
      if (markerColor != null && markerColor!.isNotEmpty) 'color': markerColor,
      'rawAprs': rawAprs,
    };
  }
}
