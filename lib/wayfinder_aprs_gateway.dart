export 'src/aprs_message.dart';
export 'src/aprs_packet.dart';
export 'src/aprs_parser.dart';
export 'src/ax25.dart';
export 'src/config.dart';
export 'src/duplicate_filter.dart';
export 'src/gateway.dart';
export 'src/kiss.dart';
export 'src/kiss_packet_source.dart';
export 'src/logger.dart';
export 'src/mapping_client.dart';
export 'src/packet_source.dart';
export 'src/packet_source_factory.dart';
export 'src/packet_source_type.dart';
export 'src/simulator/aprs_info_builder.dart';
export 'src/simulator/simulator_config.dart';
export 'src/simulator/simulator_engine.dart';
export 'src/simulator/simulator_layer.dart';
export 'src/simulator/simulator_packet_source.dart';
export 'src/simulator/waypoint_path.dart';

// Backward-compatible defaults for simple usage.
const kissHost = '127.0.0.1';
const kissPort = 8001;
const mappingServerUrl = 'http://localhost:8080/api/aprs/position';
