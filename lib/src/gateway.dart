import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'aprs_message.dart';
import 'aprs_parser.dart';
import 'ax25.dart';
import 'config.dart';
import 'duplicate_filter.dart';
import 'kiss.dart';
import 'logger.dart';
import 'mapping_client.dart';
import 'retry_queue.dart';

class AprsGateway {
  AprsGateway({
    required GatewayConfig config,
    required StructuredLogger logger,
  })  : _config = config,
        _logger = logger,
        _mappingClient = MappingClient(config: config, logger: logger),
        _duplicateFilter = DuplicateFilter(window: config.duplicateWindow) {
    _retryQueue = RetryQueue(
      maxSize: config.maxRetryQueueSize,
      onFlush: _mappingClient.post,
    );
  }

  final GatewayConfig _config;
  final StructuredLogger _logger;
  final MappingClient _mappingClient;
  final DuplicateFilter _duplicateFilter;
  late final RetryQueue _retryQueue;

  Socket? _socket;
  final _kissBuffer = BytesBuilder();

  Future<void> start() async {
    _retryQueue.start(_config.retryInterval);
    _logger.info(
      'Starting APRS gateway',
      fields: {
        'kissHost': _config.kissHost,
        'kissPort': _config.kissPort,
        'mappingServerUrl': _config.mappingServerUrl.toString(),
      },
    );

    while (true) {
      try {
        _logger.info(
          'Connecting to KISS server',
          fields: {
            'host': _config.kissHost,
            'port': _config.kissPort,
          },
        );
        _socket = await Socket.connect(_config.kissHost, _config.kissPort);
        _logger.info('Connected to KISS server');

        await for (final chunk in _socket!) {
          _handleBytes(chunk);
        }
      } catch (e) {
        _logger.warn(
          'KISS connection failed',
          fields: {'error': e.toString()},
        );
      }

      _logger.info(
        'Disconnected from KISS server; reconnecting',
        fields: {'delaySeconds': _config.reconnectDelay.inSeconds},
      );
      await Future.delayed(_config.reconnectDelay);
    }
  }

  void _handleBytes(Uint8List bytes) {
    for (final byte in bytes) {
      if (byte == Kiss.fend) {
        final frame = _kissBuffer.takeBytes();
        if (frame.isNotEmpty) {
          unawaited(_handleKissFrame(Uint8List.fromList(frame)));
        }
      } else {
        _kissBuffer.addByte(byte);
      }
    }
  }

  Future<void> _handleKissFrame(Uint8List rawFrame) async {
    final kissPayload = Kiss.decode(rawFrame);
    if (kissPayload.isEmpty) return;

    final command = kissPayload.first;
    final ax25Bytes = kissPayload.sublist(1);

    if ((command & 0x0F) != 0x00) return;

    final ax25 = Ax25Frame.tryParse(ax25Bytes);
    if (ax25 == null) return;

    final message = AprsParser.parse(ax25);
    if (message == null) return;

    if (message.packetType == AprsPacketType.position && !message.hasPosition) {
      return;
    }

    final payload = message.toPayload(
      stationId: ax25.source,
      destination: ax25.destination,
      path: ax25.path,
      rawAprs: ax25.info,
    );

    if (_duplicateFilter.isDuplicate(payload)) {
      _logger.debug(
        'Skipped duplicate packet',
        fields: {
          'stationId': ax25.source,
          'packetType': message.packetType.name,
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
