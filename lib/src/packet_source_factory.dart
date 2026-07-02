import 'config.dart';
import 'kiss_packet_source.dart';
import 'logger.dart';
import 'packet_source.dart';
import 'packet_source_type.dart';
import 'simulator/simulator_config.dart';
import 'simulator/simulator_packet_source.dart';

PacketSource createPacketSource({
  required GatewayConfig config,
  required StructuredLogger logger,
}) {
  switch (config.packetSource) {
    case PacketSourceType.kiss:
      return KissPacketSource(config: config, logger: logger);
    case PacketSourceType.simulator:
      final path = config.simulatorConfigPath;
      if (path == null || path.isEmpty) {
        throw StateError(
          'APRS_SIMULATOR_CONFIG is required when APRS_PACKET_SOURCE=simulator',
        );
      }
      final simulatorConfig = SimulatorConfig.load(path);
      return SimulatorPacketSource(
        config: simulatorConfig,
        logger: logger,
      );
    case PacketSourceType.replay:
    case PacketSourceType.aprsis:
      throw UnsupportedError(
        'APRS_PACKET_SOURCE=${config.packetSource.name} is not implemented yet',
      );
  }
}
