import 'aprs_packet.dart';

/// Supplies parsed APRS packets to the gateway.
///
/// Concrete implementations may read from KISS/TCP (Direwolf), a simulator,
/// recorded captures, or APRS-IS. The gateway only consumes [AprsPacket]s.
abstract interface class PacketSource {
  Stream<AprsPacket> get packets;

  Future<void> start();

  Future<void> stop();
}
