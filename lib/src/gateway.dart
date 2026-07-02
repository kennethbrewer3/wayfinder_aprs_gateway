import 'dart:async';

import 'aprs_message.dart';
import 'aprs_packet.dart';
import 'config.dart';
import 'duplicate_filter.dart';
import 'logger.dart';
import 'mapping_client.dart';
import 'packet_source.dart';
import 'packet_source_type.dart';
import 'retry_queue.dart';

class AprsGateway {
  AprsGateway({
    required PacketSource packetSource,
    required GatewayConfig config,
    required StructuredLogger logger,
  })  : _packetSource = packetSource,
        _config = config,
        _logger = logger,
        _mappingClient = MappingClient(config: config, logger: logger),
        _duplicateFilter = DuplicateFilter(window: config.duplicateWindow) {
    _retryQueue = RetryQueue(
      maxSize: config.maxRetryQueueSize,
      onFlush: _mappingClient.post,
    );
  }

  final PacketSource _packetSource;
  final GatewayConfig _config;
  final StructuredLogger _logger;
  final MappingClient _mappingClient;
  final DuplicateFilter _duplicateFilter;
  late final RetryQueue _retryQueue;

  StreamSubscription<AprsPacket>? _subscription;
  String? _simulatorLayerId;

  Future<void> start() async {
    _retryQueue.start(_config.retryInterval);
    _logger.info(
      'Starting APRS gateway',
      fields: {
        'packetSource': _config.packetSource.name,
        'mappingServerUrl': _config.mappingServerUrl.toString(),
      },
    );

    if (_config.packetSource == PacketSourceType.simulator) {
      _simulatorLayerId = await _mappingClient.prepareSimulatorLayer(
        _config.simulatorLayerName,
      );
    }

    _subscription = _packetSource.packets.listen(
      _handlePacket,
      onError: (Object error, StackTrace stackTrace) {
        _logger.warn(
          'Packet source error',
          fields: {'error': error.toString()},
        );
      },
    );

    await _packetSource.start();
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    await _packetSource.stop();
    _retryQueue.stop();
  }

  Future<void> _handlePacket(AprsPacket packet) async {
    if (packet.message.packetType == AprsPacketType.position &&
        !packet.message.hasPosition) {
      return;
    }

    final payload = packet.toPayload();
    if (_simulatorLayerId != null) {
      payload['layerId'] = _simulatorLayerId;
      payload['layerName'] = _config.simulatorLayerName;
    }

    if (_duplicateFilter.isDuplicate(payload)) {
      _logger.debug(
        'Skipped duplicate packet',
        fields: {
          'stationId': packet.source,
          'packetType': packet.message.packetType.name,
        },
      );
      return;
    }

    await _deliver(payload);
  }

  Future<void> _deliver(Map<String, dynamic> payload) async {
    final success = await _mappingClient.post(payload);
    if (!success) {
      _retryQueue.enqueue(payload);
      _logger.warn(
        'Queued packet for retry',
        fields: {
          'stationId': payload['stationId'],
          'packetType': payload['packetType'],
          'queueLength': _retryQueue.length,
        },
      );
    }
  }
}
