import 'dart:convert';
import 'dart:io';

import 'config.dart';
import 'logger.dart';

class MappingClient {
  MappingClient({
    required this.config,
    required this.logger,
  });

  final GatewayConfig config;
  final StructuredLogger logger;

  Future<bool> post(Map<String, dynamic> payload) async {
    final client = HttpClient();

    try {
      final request = await client.postUrl(config.mappingServerUrl);
      request.headers.contentType = ContentType.json;
      _applyAuth(request.headers);

      request.write(jsonEncode(payload));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        logger.info(
          'Posted APRS packet',
          fields: {
            'stationId': payload['stationId'],
            'packetType': payload['packetType'],
            'statusCode': response.statusCode,
          },
        );
        return true;
      }

      if (response.statusCode >= 500) {
        logger.warn(
          'Mapping server error',
          fields: {
            'statusCode': response.statusCode,
            'body': body,
          },
        );
        return false;
      }

      logger.warn(
        'Mapping server rejected packet',
        fields: {
          'statusCode': response.statusCode,
          'body': body,
        },
      );
      return true;
    } on SocketException catch (e) {
      logger.warn(
        'Mapping server unreachable',
        fields: {'error': e.message},
      );
      return false;
    } on HttpException catch (e) {
      logger.warn(
        'Mapping server HTTP error',
        fields: {'error': e.message},
      );
      return false;
    } catch (e) {
      logger.error(
        'Unexpected mapping server error',
        fields: {'error': e.toString()},
      );
      return false;
    } finally {
      client.close();
    }
  }

  void _applyAuth(HttpHeaders headers) {
    final token = config.authToken;
    if (token == null || token.isEmpty) return;

    if (config.authScheme.isEmpty) {
      headers.set(config.authHeader, token);
      return;
    }

    headers.set(config.authHeader, '${config.authScheme} $token');
  }
}
