import 'dart:io';

import 'package:test/test.dart';
import 'package:wayfinder_aprs_gateway/wayfinder_aprs_gateway.dart';

void main() {
  group('simulator config', () {
    test('loads mobile station types from json', () {
      final config = SimulatorConfig.fromJson({
        'intervalSeconds': 10,
        'stations': [
          {
            'callsign': 'W1CAR-9',
            'type': 'car',
            'waypoints': [
              {'latitude': 38.88, 'longitude': -77.10},
              {'latitude': 38.89, 'longitude': -77.11},
            ],
          },
          {
            'callsign': 'W1BOAT-1',
            'type': 'boat',
            'waypoints': [
              {'latitude': 38.87, 'longitude': -77.05},
              {'latitude': 38.88, 'longitude': -77.04},
            ],
          },
          {
            'callsign': 'W1HIKE-7',
            'type': 'hiker',
            'waypoints': [
              {'latitude': 38.95, 'longitude': -77.20},
              {'latitude': 38.96, 'longitude': -77.19},
            ],
          },
          {
            'callsign': 'N12345',
            'type': 'aircraft',
            'waypoints': [
              {'latitude': 39.0, 'longitude': -77.05},
              {'latitude': 39.01, 'longitude': -77.06},
            ],
            'altitudeMeters': 3500,
          },
          {
            'callsign': 'W1TRN-1',
            'type': 'train',
            'waypoints': [
              {'latitude': 38.92, 'longitude': -77.21},
              {'latitude': 38.93, 'longitude': -77.20},
            ],
          },
          {
            'callsign': 'WX0ABC',
            'type': 'weather',
            'latitude': 38.8765,
            'longitude': -77.1233,
          },
          {
            'callsign': 'W1DIGI',
            'type': 'repeater',
            'latitude': 38.9,
            'longitude': -77.15,
          },
        ],
      });

      expect(config.stations, hasLength(7));
      expect(config.stations[0].type, SimulatorStationType.car);
      expect(config.stations[1].type, SimulatorStationType.boat);
      expect(config.stations[2].type, SimulatorStationType.hiker);
      expect(config.stations[3].type, SimulatorStationType.aircraft);
      expect(config.stations[4].type, SimulatorStationType.train);
      expect(config.stations[0].transportationMode, 'landVehicle');
      expect(config.stations[1].transportationMode, 'watercraft');
      expect(config.stations[2].transportationMode, 'onFoot');
      expect(config.stations[3].transportationMode, 'aircraft');
      expect(config.stations[4].transportationMode, 'landVehicle');
    });

    test('accepts route as an alias for waypoints', () {
      final station = SimulatorStationConfig.fromJson({
        'callsign': 'W1CAR-9',
        'type': 'car',
        'route': [
          {'latitude': 1, 'longitude': 2},
          {'latitude': 3, 'longitude': 4},
        ],
      });

      expect(station.waypoints, hasLength(2));
      expect(station.latitude, 1);
      expect(station.longitude, 2);
    });
  });

  group('waypoint path', () {
    test('interpolates linearly between waypoints', () {
      final path = WaypointPath(
        [
          SimulatorWaypoint(latitude: 38.0, longitude: -77.0),
          SimulatorWaypoint(latitude: 39.0, longitude: -77.0),
        ],
        loop: false,
      );

      expect(path.position.latitude, closeTo(38.0, 0.0001));

      path.advance(55.5);
      expect(path.position.latitude, closeTo(38.5, 0.05));
      expect(path.course, 0);
    });
  });

  group('simulator engine', () {
    test('moves along waypoints and marks tracking payloads', () {
      final config = SimulatorConfig.fromJson({
        'intervalSeconds': 60,
        'stations': [
          {
            'callsign': 'W1CAR-9',
            'type': 'car',
            'speedKnots': 30,
            'waypoints': [
              {'latitude': 38.8800, 'longitude': -77.1000},
              {'latitude': 38.8800, 'longitude': -77.2000},
            ],
            'loop': false,
          },
        ],
      });

      final engine = SimulatorEngine(config);
      final firstTick = engine.buildPackets().single;
      final secondTick = engine.buildPackets().single;
      final payload = firstTick.toPayload();

      expect(payload['isTracking'], isTrue);
      expect(payload['transportationMode'], 'landVehicle');
      expect(firstTick.message.longitude, closeTo(-77.1000, 0.02));
      expect(
        secondTick.message.longitude,
        lessThan(firstTick.message.longitude!),
      );
    });

    test('builds parser-compatible weather packets', () {
      final config = SimulatorConfig.fromJson({
        'stations': [
          {
            'callsign': 'WX0ABC',
            'type': 'weather',
            'latitude': 38.8765,
            'longitude': -77.1233,
            'weather': {
              'windDirection': 225,
              'windSpeedKnots': 0,
              'temperatureF': 50,
              'humidity': 0,
              'pressureMb': 1013.8,
            },
          },
        ],
      });

      final packet = SimulatorEngine(config).buildPackets().single;
      final parsed = AprsParser.parse(
        Ax25Frame(
          destination: 'APRS',
          source: packet.source,
          path: const [],
          info: packet.rawAprs,
        ),
      );

      expect(parsed, isNotNull);
      expect(parsed!.packetType, AprsPacketType.weather);
      expect(parsed.weather, isNotNull);
      expect(packet.toPayload()['isTracking'], isNull);
    });

    test('cycles weatherSequence readings over time', () {
      final config = SimulatorConfig.fromJson({
        'intervalSeconds': 15,
        'stations': [
          {
            'callsign': 'WX1RKI',
            'type': 'weather',
            'latitude': 38.905,
            'longitude': -77.045,
            'weatherSequence': [
              {
                'windDirection': 270,
                'windSpeedKnots': 8,
                'temperatureF': 70,
                'humidity': 48,
                'pressureMb': 1012.8,
              },
              {
                'windDirection': 300,
                'windSpeedKnots': 18,
                'temperatureF': 67,
                'humidity': 61,
                'pressureMb': 1011.4,
              },
            ],
          },
        ],
      });

      final engine = SimulatorEngine(config);
      final first = engine.buildPackets().single;
      final second = engine.buildPackets().single;
      final third = engine.buildPackets().single;

      expect(first.message.weather!['windDirection'], 270);
      expect(second.message.weather!['windDirection'], 300);
      expect(third.message.weather!['windDirection'], 270);
    });
  });

  group('simulator packet source', () {
    test('emits configured scenario packets', () async {
      final configFile = File(
        '${Directory.systemTemp.path}/wayfinder_simulator_config_test.json',
      );
      configFile.writeAsStringSync('''
{
  "intervalSeconds": 1,
  "stations": [
    {
      "callsign": "W1CAR-9",
      "type": "car",
      "speedKnots": 30,
      "waypoints": [
        {"latitude": 38.8800, "longitude": -77.1000},
        {"latitude": 38.8900, "longitude": -77.1000}
      ]
    }
  ]
}
''');
      addTearDown(() {
        if (configFile.existsSync()) {
          configFile.deleteSync();
        }
      });

      final source = SimulatorPacketSource(
        config: SimulatorConfig.load(configFile.path),
        logger: StructuredLogger(LogLevel.error),
      );
      final received = <AprsPacket>[];
      source.packets.listen(received.add);

      final run = source.start();
      await Future.delayed(const Duration(milliseconds: 100));
      await source.stop();
      await run;

      expect(received, isNotEmpty);
      expect(received.first.source, 'W1CAR-9');
      expect(received.first.toPayload()['isTracking'], isTrue);
    });
  });
}
