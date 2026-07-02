import 'dart:io';

import 'package:wayfinder_aprs_gateway/wayfinder_aprs_gateway.dart';
import 'package:test/test.dart';

void main() {
  group('uncompressed position', () {
    test('parses position without timestamp', () {
      final frame = Ax25Frame(
        destination: 'APRS',
        source: 'N0CALL-1',
        path: const [],
        info: '!3852.59N/07707.40W>Test comment',
      );

      final packet = AprsParser.parse(frame);

      expect(packet, isNotNull);
      expect(packet!.packetType, AprsPacketType.position);
      expect(packet.format, 'uncompressed');
      expect(packet.latitude, closeTo(38.8765, 0.0001));
      expect(packet.longitude, closeTo(-77.1233, 0.0001));
      expect(packet.comment, 'Test comment');
    });

    test('parses digipeater as repeater packet type', () {
      final frame = Ax25Frame(
        destination: 'APRS',
        source: 'W1DIGI',
        path: const [],
        info: '!3852.59N/07707.40W#Wide area digi PHG5450',
      );

      final packet = AprsParser.parse(frame);

      expect(packet, isNotNull);
      expect(packet!.packetType, AprsPacketType.repeater);
      expect(packet.format, 'repeater');
      expect(packet.symbolCode, '#');
    });
  });

  group('compressed position', () {
    test('parses base91 compressed coordinates', () {
      final frame = Ax25Frame(
        destination: 'APRS',
        source: 'M0XER-4',
        path: const [],
        info: '!/.(M4I^C,O comment',
      );

      final packet = AprsParser.parse(frame);

      expect(packet, isNotNull);
      expect(packet!.format, 'compressed');
      expect(packet.latitude, closeTo(64.11987367625208, 0.0001));
      expect(packet.longitude, closeTo(-19.070654142799384, 0.0001));
      expect(packet.symbolTable, '/');
      expect(packet.symbolCode, 'O');
    });
  });

  group('mic-e', () {
    test('parses mic-e position from destination and info fields', () {
      // TU3RTW encodes 45° 32.47' N per APRS Mic-E conventions.
      final frame = Ax25Frame(
        destination: 'TU3RTW',
        source: 'KF7WXW-9',
        path: const [],
        info: '`28${String.fromCharCode(28)}666/R',
      );

      final packet = AprsParser.parse(frame);

      expect(packet, isNotNull);
      expect(packet!.packetType, AprsPacketType.mice);
      expect(packet.format, 'mic-e');
      expect(packet.latitude, closeTo(45.5412, 0.001));
      expect(packet.longitude, closeTo(-122.4667, 0.01));
    });
  });

  group('weather', () {
    test('parses weather embedded in position report', () {
      final frame = Ax25Frame(
        destination: 'APRS',
        source: 'WX0ABC',
        path: const [],
        info: '=4903.50N/07201.75W_225/000g000t050r000p001h00b10138',
      );

      final packet = AprsParser.parse(frame);

      expect(packet, isNotNull);
      expect(packet!.packetType, AprsPacketType.weather);
      expect(packet.weather, isNotNull);
      expect(packet.weather!['windDirection'], 225);
      expect(packet.weather!['temperature'], closeTo(10.0, 0.1));
      expect(packet.weather!['pressure'], closeTo(1013.8, 0.1));
    });

    test('parses positionless weather report', () {
      final frame = Ax25Frame(
        destination: 'APRS',
        source: 'WX0ABC',
        path: const [],
        info: '_12345678c180s010g005t072r000p000P000h50b10123',
      );

      final packet = AprsParser.parse(frame);

      expect(packet, isNotNull);
      expect(packet!.packetType, AprsPacketType.weather);
      expect(packet.format, 'weather-positionless');
      expect(packet.weather, isNotNull);
      expect(packet.weather!['rawTimestamp'], '12345678');
      expect(packet.weather!['windDirection'], 180);
    });
  });

  group('telemetry', () {
    test('parses telemetry report', () {
      final frame = Ax25Frame(
        destination: 'APRS',
        source: 'TELEM-1',
        path: const [],
        info: 'T#025,100,150,200,255,10101010',
      );

      final packet = AprsParser.parse(frame);

      expect(packet, isNotNull);
      expect(packet!.packetType, AprsPacketType.telemetry);
      expect(packet.format, 'telemetry-report');
      expect(packet.telemetry!['channels'], [25, 100, 150, 200, 255]);
      expect(packet.telemetry!['digitalBits'], '10101010');
    });

    test('parses telemetry config message', () {
      final frame = Ax25Frame(
        destination: 'APRS',
        source: 'TELEM-1',
        path: const [],
        info: 'PARM.Voltage,Current,Temp1,Temp2,Temp5',
      );

      final packet = AprsParser.parse(frame);

      expect(packet, isNotNull);
      expect(packet!.format, 'telemetry-config');
      expect(packet.telemetry!['section'], 'PARM');
    });
  });

  group('duplicate filter', () {
    test('suppresses repeated position packets within window', () {
      final filter = DuplicateFilter(window: const Duration(seconds: 30));
      final payload = {
        'stationId': 'N0CALL',
        'packetType': 'position',
        'latitude': 38.8765,
        'longitude': -77.1233,
        'rawAprs': '!3852.59N/07707.40W>',
      };

      expect(filter.isDuplicate(payload), isFalse);
      expect(filter.isDuplicate(payload), isTrue);
    });
  });

  group('gateway config', () {
    test('loads defaults when no config file is provided', () async {
      final config = await GatewayConfig.load();

      expect(config.kissHost, '127.0.0.1');
      expect(config.kissPort, 8001);
      expect(config.packetSource, PacketSourceType.kiss);
      expect(config.mappingServerUrl.toString(),
          'http://localhost:18082');
      expect(config.authHeader, 'Authorization');
      expect(config.authScheme, 'Bearer');
    });

    test('loads packet source from config file', () async {
      final configFile = File(
        '${Directory.systemTemp.path}/wayfinder_aprs_gateway_config_test.json',
      );
      configFile.writeAsStringSync('{"packetSource":"simulator"}');
      addTearDown(() {
        if (configFile.existsSync()) {
          configFile.deleteSync();
        }
      });

      final config = await GatewayConfig.load(
        args: ['--config', configFile.path],
      );

      expect(config.packetSource, PacketSourceType.simulator);
    });
  });

  group('packet source type', () {
    test('parses supported APRS_PACKET_SOURCE values', () {
      expect(PacketSourceType.parse(null), PacketSourceType.kiss);
      expect(PacketSourceType.parse('kiss'), PacketSourceType.kiss);
      expect(PacketSourceType.parse('Direwolf'), PacketSourceType.kiss);
      expect(PacketSourceType.parse('simulator'), PacketSourceType.simulator);
      expect(PacketSourceType.parse('aprs-is'), PacketSourceType.aprsis);
    });

    test('rejects unknown APRS_PACKET_SOURCE values', () {
      expect(
        () => PacketSourceType.parse('not-a-source'),
        throwsArgumentError,
      );
    });
  });

  group('simulator packet source', () {
    test('emits provided packets to listeners', () async {
      final frame = Ax25Frame(
        destination: 'APRS',
        source: 'N0CALL-1',
        path: const [],
        info: '!3852.59N/07707.40W>Test comment',
      );
      final message = AprsParser.parse(frame)!;
      final expected = AprsPacket(
        source: frame.source,
        destination: frame.destination,
        path: frame.path,
        rawAprs: frame.info,
        message: message,
      );

      final source = SimulatorPacketSource.fromList([expected]);
      final received = <AprsPacket>[];
      source.packets.listen(received.add);

      await source.start();

      expect(received, [expected]);
      expect(received.single.toPayload()['stationId'], 'N0CALL-1');
    });
  });
}
