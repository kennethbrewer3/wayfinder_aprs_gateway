import 'package:test/test.dart';
import 'package:wayfinder_aprs_gateway/wayfinder_aprs_gateway.dart';

void main() {
  group('MappingClient API URLs', () {
    test('derives markers endpoint from APRS mapping URL', () {
      final mappingUrl = Uri.parse('http://localhost:18080/api/aprs/position');

      expect(
        MappingClient.markersApiUrl(mappingUrl).toString(),
        'http://localhost:18080/api/markers',
      );
      expect(
        MappingClient.layersApiUrl(mappingUrl).toString(),
        'http://localhost:18080/api/layers',
      );
      expect(
        MappingClient.zonesApiUrl(mappingUrl).toString(),
        'http://localhost:18080/api/zones',
      );
    });
  });

  group('simulator layer defaults', () {
    test('uses APRS Simulator as the default layer name', () async {
      final config = await GatewayConfig.load();

      expect(config.simulatorLayerName, defaultSimulatorLayerName);
      expect(config.simulatorLayerName, 'APRS Simulator');
    });
  });
}
