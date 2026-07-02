import 'dart:convert';
import 'dart:io';

import 'logger.dart';
import 'packet_source_type.dart';
import 'simulator/simulator_layer.dart';

class GatewayConfig {
  GatewayConfig({
    required this.kissHost,
    required this.kissPort,
    required this.mappingServerUrl,
    this.packetSource = PacketSourceType.kiss,
    this.authToken,
    this.authHeader = 'Authorization',
    this.authScheme = 'Bearer',
    this.duplicateWindow = const Duration(seconds: 30),
    this.retryInterval = const Duration(seconds: 30),
    this.maxRetryQueueSize = 1000,
    this.reconnectDelay = const Duration(seconds: 5),
    this.logLevel = LogLevel.info,
    this.simulatorConfigPath,
    this.simulatorLayerName = defaultSimulatorLayerName,
  });

  final String kissHost;
  final int kissPort;
  final Uri mappingServerUrl;
  final PacketSourceType packetSource;
  final String? authToken;
  final String authHeader;
  final String authScheme;
  final Duration duplicateWindow;
  final Duration retryInterval;
  final int maxRetryQueueSize;
  final Duration reconnectDelay;
  final LogLevel logLevel;
  final String? simulatorConfigPath;
  final String simulatorLayerName;

  static Future<GatewayConfig> load({List<String> args = const []}) async {
    final configPath = _resolveConfigPath(args);
    final fileValues = configPath == null
        ? <String, dynamic>{}
        : _loadConfigFile(configPath);

    return GatewayConfig(
      kissHost: _envOrFile('APRS_KISS_HOST', fileValues, 'kissHost') ?? '127.0.0.1',
      kissPort: int.parse(
        _envOrFile('APRS_KISS_PORT', fileValues, 'kissPort') ?? '8001',
      ),
      mappingServerUrl: Uri.parse(
        _envOrFile(
              'APRS_MAPPING_SERVER_URL',
              fileValues,
              'mappingServerUrl',
            ) ??
            'http://localhost:8080/api/aprs/position',
      ),
      packetSource: PacketSourceType.parse(
        _envOrFile('APRS_PACKET_SOURCE', fileValues, 'packetSource'),
      ),
      authToken: _envOrFile('APRS_AUTH_TOKEN', fileValues, 'authToken'),
      authHeader:
          _envOrFile('APRS_AUTH_HEADER', fileValues, 'authHeader') ??
          'Authorization',
      authScheme:
          _envOrFile('APRS_AUTH_SCHEME', fileValues, 'authScheme') ?? 'Bearer',
      duplicateWindow: Duration(
        seconds: int.parse(
          _envOrFile(
                'APRS_DUPLICATE_WINDOW_SECONDS',
                fileValues,
                'duplicateWindowSeconds',
              ) ??
              '30',
        ),
      ),
      retryInterval: Duration(
        seconds: int.parse(
          _envOrFile(
                'APRS_RETRY_INTERVAL_SECONDS',
                fileValues,
                'retryIntervalSeconds',
              ) ??
              '30',
        ),
      ),
      maxRetryQueueSize: int.parse(
        _envOrFile(
              'APRS_MAX_RETRY_QUEUE_SIZE',
              fileValues,
              'maxRetryQueueSize',
            ) ??
            '1000',
      ),
      reconnectDelay: Duration(
        seconds: int.parse(
          _envOrFile(
                'APRS_RECONNECT_DELAY_SECONDS',
                fileValues,
                'reconnectDelaySeconds',
              ) ??
              '5',
        ),
      ),
      logLevel: LogLevel.fromString(
        _envOrFile('APRS_LOG_LEVEL', fileValues, 'logLevel') ?? 'info',
      ),
      simulatorConfigPath:
          _envOrFile('APRS_SIMULATOR_CONFIG', fileValues, 'simulatorConfig'),
      simulatorLayerName:
          _envOrFile('APRS_SIMULATOR_LAYER_NAME', fileValues, 'simulatorLayerName') ??
          defaultSimulatorLayerName,
    );
  }

  static String? _resolveConfigPath(List<String> args) {
    for (var i = 0; i < args.length; i++) {
      if (args[i] == '--config' && i + 1 < args.length) {
        return args[i + 1];
      }
      if (args[i].startsWith('--config=')) {
        return args[i].substring('--config='.length);
      }
    }

    return Platform.environment['APRS_CONFIG_FILE'];
  }

  static Map<String, dynamic> _loadConfigFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('Config file not found: $path');
    }

    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Config file must contain a JSON object: $path');
    }

    return decoded;
  }

  static String? _envOrFile(
    String envName,
    Map<String, dynamic> fileValues,
    String fileKey,
  ) {
    final envValue = Platform.environment[envName];
    if (envValue != null && envValue.isNotEmpty) {
      return envValue;
    }

    final fileValue = fileValues[fileKey];
    if (fileValue == null) return null;
    return fileValue.toString();
  }
}
