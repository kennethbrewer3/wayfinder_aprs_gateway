import 'dart:async';

import '../aprs_packet.dart';
import '../logger.dart';
import '../packet_source.dart';
import 'simulator_config.dart';
import 'simulator_engine.dart';

/// Injects simulated [AprsPacket]s based on [SimulatorConfig].
class SimulatorPacketSource implements PacketSource {
  SimulatorPacketSource({
    required SimulatorConfig config,
    required StructuredLogger logger,
  })  : _config = config,
        _logger = logger,
        _engine = SimulatorEngine(config),
        _presetPackets = null,
        _delayBetweenPackets = Duration.zero;

  /// Test helper for injecting a fixed list of packets.
  factory SimulatorPacketSource.fromList(
    List<AprsPacket> packets, {
    Duration delayBetweenPackets = Duration.zero,
  }) {
    return SimulatorPacketSource._preset(
      packets: packets,
      delayBetweenPackets: delayBetweenPackets,
    );
  }

  SimulatorPacketSource._preset({
    required List<AprsPacket> packets,
    required Duration delayBetweenPackets,
  })  : _config = null,
        _logger = null,
        _engine = null,
        _presetPackets = packets,
        _delayBetweenPackets = delayBetweenPackets;

  final SimulatorConfig? _config;
  final StructuredLogger? _logger;
  final SimulatorEngine? _engine;
  final List<AprsPacket>? _presetPackets;
  final Duration _delayBetweenPackets;

  final _controller = StreamController<AprsPacket>();
  var _running = false;

  @override
  Stream<AprsPacket> get packets => _controller.stream;

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;

    if (_presetPackets != null) {
      for (final packet in _presetPackets) {
        if (!_running) break;
        _controller.add(packet);
        if (_delayBetweenPackets > Duration.zero) {
          await Future.delayed(_delayBetweenPackets);
        }
      }
      return;
    }

    final config = _config!;
    final logger = _logger!;
    final engine = _engine!;

    logger.info(
      'Starting APRS simulator',
      fields: {
        'stationCount': config.stations.length,
        'intervalSeconds': config.interval.inSeconds,
      },
    );

    while (_running) {
      for (final packet in engine.buildPackets()) {
        if (!_running) break;
        _controller.add(packet);
      }

      if (!_running) break;
      await Future.delayed(config.interval);
    }
  }

  @override
  Future<void> stop() async {
    _running = false;
    await _controller.close();
  }
}
