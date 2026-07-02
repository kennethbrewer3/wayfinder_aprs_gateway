import 'package:test/test.dart';
import 'package:wayfinder_aprs_gateway/src/wayfinder_marker_mapper.dart';

void main() {
  group('WayfinderMarkerMapper', () {
    test('builds create body from APRS payload', () {
      final body = WayfinderMarkerMapper.createBody({
        'stationId': 'N0CALL-1',
        'latitude': 38.9,
        'longitude': -77.1,
        'comment': 'Test',
        'isTracking': true,
        'layerId': 'layer-123',
        'transportationMode': 'landVehicle',
      });

      expect(body['name'], 'N0CALL-1');
      expect(body['latitude'], 38.9);
      expect(body['longitude'], -77.1);
      expect(body['icon'], 'directions_car');
      expect(body['isTracking'], true);
      expect(body['layerId'], 'layer-123');
      expect(body['notes'], 'Test');
    });

    test('builds update body with changed coordinates', () {
      final body = WayfinderMarkerMapper.updateBody({
        'latitude': 39.0,
        'longitude': -77.2,
        'comment': 'Updated',
      });

      expect(body['latitude'], 39.0);
      expect(body['longitude'], -77.2);
      expect(body['notes'], 'Updated');
    });
  });
}
