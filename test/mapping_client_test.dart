import 'package:test/test.dart';
import 'package:wayfinder_aprs_gateway/wayfinder_aprs_gateway.dart';

void main() {
  group('MappingClient API URLs', () {
    test('derives REST endpoints from Wayfinder web server URL', () {
      final mappingUrl = Uri.parse('http://localhost:18082');

      expect(
        MappingClient.markersApiUrl(mappingUrl).toString(),
        'http://localhost:18082/api/markers',
      );
      expect(
        MappingClient.layersApiUrl(mappingUrl).toString(),
        'http://localhost:18082/api/layers',
      );
      expect(
        MappingClient.zonesApiUrl(mappingUrl).toString(),
        'http://localhost:18082/api/zones',
      );
    });

    test('derives REST endpoints when legacy APRS path is present', () {
      final mappingUrl =
          Uri.parse('http://localhost:18082/api/aprs/position');

      expect(
        MappingClient.markersApiUrl(mappingUrl).toString(),
        'http://localhost:18082/api/markers',
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
