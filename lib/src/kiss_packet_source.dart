import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'aprs_message.dart';
import 'aprs_packet.dart';
import 'aprs_parser.dart';
import 'ax25.dart';
import 'config.dart';
import 'kiss.dart';
import 'logger.dart';
import 'packet_source.dart';

/// KISS-over-TCP packet source (for example Direwolf's `KISSPORT`).
class KissPacketSource implements PacketSource {
  KissPacketSource({
    required GatewayConfig config,
    required StructuredLogger logger,
  })  : _config = config,
        _logger = logger;

  final GatewayConfig _config;
  final StructuredLogger _logger;
  final _controller = StreamController<AprsPacket>();
  final _kissBuffer = BytesBuilder();

  Socket? _socket;
  var _running = false;

  @override
  Stream<AprsPacket> get packets => _controller.stream;

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;

    while (_running) {
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
          if (!_running) break;
          _handleBytes(chunk);
        }
      } catch (e) {
        if (!_running) break;
        _logger.warn(
          'KISS connection failed',
          fields: {'error': e.toString()},
        );
      } finally {
        await _socket?.close();
        _socket = null;
      }

      if (!_running) break;

      _logger.info(
        'Disconnected from KISS server; reconnecting',
        fields: {'delaySeconds': _config.reconnectDelay.inSeconds},
      );
      await Future.delayed(_config.reconnectDelay);
    }
  }

  @override
  Future<void> stop() async {
    _running = false;
    await _socket?.close();
    _socket = null;
    await _controller.close();
  }

  void _handleBytes(Uint8List bytes) {
    for (final byte in bytes) {
      if (byte == Kiss.fend) {
        final frame = _kissBuffer.takeBytes();
        if (frame.isNotEmpty) {
          final packet = _parseKissFrame(Uint8List.fromList(frame));
          if (packet != null) {
            _controller.add(packet);
          }
        }
      } else {
        _kissBuffer.addByte(byte);
      }
    }
  }

  AprsPacket? _parseKissFrame(Uint8List rawFrame) {
    final kissPayload = Kiss.decode(rawFrame);
    if (kissPayload.isEmpty) return null;

    final command = kissPayload.first;
    final ax25Bytes = kissPayload.sublist(1);

    if ((command & 0x0F) != 0x00) return null;

    final ax25 = Ax25Frame.tryParse(ax25Bytes);
    if (ax25 == null) return null;

    final message = AprsParser.parse(ax25);
    if (message == null) return null;

    if (message.packetType == AprsPacketType.position && !message.hasPosition) {
      return null;
    }

    return AprsPacket(
      source: ax25.source,
      destination: ax25.destination,
      path: ax25.path,
      rawAprs: ax25.info,
      message: message,
    );
  }
}

/// Alias for setups where KISS comes from Direwolf.
typedef DireWolfSource = KissPacketSource;
