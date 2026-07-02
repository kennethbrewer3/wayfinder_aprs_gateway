import 'aprs_message.dart';

/// A parsed APRS packet with AX.25 routing metadata.
class AprsPacket {
  AprsPacket({
    required this.source,
    required this.destination,
    required this.path,
    required this.rawAprs,
    required this.message,
  });

  final String source;
  final String destination;
  final List<String> path;
  final String rawAprs;
  final AprsMessage message;

  Map<String, dynamic> toPayload() {
    return message.toPayload(
      stationId: source,
      destination: destination,
      path: path,
      rawAprs: rawAprs,
    );
  }
}
