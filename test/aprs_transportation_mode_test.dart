import 'package:test/test.dart';
import 'package:wayfinder_aprs_gateway/src/aprs_message.dart';
import 'package:wayfinder_aprs_gateway/src/aprs_transportation_mode.dart';
import 'package:wayfinder_aprs_gateway/src/track_zone_geometry.dart';

void main() {
  group('AprsTransportationMode', () {
    test('maps common APRS symbols to Wayfinder modes', () {
      expect(
        AprsTransportationMode.infer(symbolTable: '/', symbolCode: '>'),
        AprsTransportationMode.landVehicle,
      );
      expect(
        AprsTransportationMode.infer(symbolTable: '/', symbolCode: 's'),
        AprsTransportationMode.watercraft,
      );
      expect(
        AprsTransportationMode.infer(symbolTable: '/', symbolCode: '['),
        AprsTransportationMode.onFoot,
      );
      expect(
        AprsTransportationMode.infer(symbolTable: '/', symbolCode: '^'),
        AprsTransportationMode.aircraft,
      );
      expect(
        AprsTransportationMode.infer(symbolTable: '/', symbolCode: 'b'),
        AprsTransportationMode.bike,
      );
    });

    test('returns null for fixed-station symbols', () {
      expect(
        AprsTransportationMode.infer(symbolTable: '/', symbolCode: '#'),
        isNull,
      );
    });
  });

  group('AprsMessage tracking payload', () {
    test('infers transportation mode and tracking from APRS symbols', () {
      final message = AprsMessage(
        packetType: AprsPacketType.position,
        format: 'uncompressed',
        latitude: 38.88,
        longitude: -77.10,
        symbolTable: '/',
        symbolCode: '>',
        comment: 'Mobile',
      );

      final payload = message.toPayload(
        stationId: 'W1CAR-9',
        destination: 'APRS',
        path: const [],
        rawAprs: 'raw',
      );

      expect(payload['transportationMode'], 'landVehicle');
      expect(payload['isTracking'], true);
    });
  });

  group('TrackZoneGeometry', () {
    test('updates transportationMode in track geometry json', () {
      const original =
          '{"markerId":"abc","points":[],"transportationMode":"onFoot"}';

      final updated = TrackZoneGeometry.updatedTransportationMode(
        original,
        'landVehicle',
      );

      expect(updated, isNotNull);
      expect(updated, contains('"transportationMode":"landVehicle"'));
    });

    test('returns null when mode is unchanged', () {
      const original =
          '{"markerId":"abc","points":[],"transportationMode":"landVehicle"}';

      expect(
        TrackZoneGeometry.updatedTransportationMode(
          original,
          'landVehicle',
        ),
        isNull,
      );
    });
  });
}
