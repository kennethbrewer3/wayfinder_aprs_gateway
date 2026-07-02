export 'src/aprs_message.dart';
export 'src/aprs_parser.dart';
export 'src/ax25.dart';
export 'src/config.dart';
export 'src/duplicate_filter.dart';
export 'src/gateway.dart';
export 'src/kiss.dart';
export 'src/logger.dart';

// Backward-compatible defaults for simple usage.
const kissHost = '127.0.0.1';
const kissPort = 8001;
const mappingServerUrl = 'http://localhost:8080/api/aprs/position';
