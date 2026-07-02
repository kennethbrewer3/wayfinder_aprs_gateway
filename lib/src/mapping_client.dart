import 'dart:convert';
import 'dart:io';

import 'config.dart';
import 'logger.dart';
import 'track_zone_geometry.dart';
import 'wayfinder_marker_mapper.dart';

class MappingClient {
  MappingClient({
    required this.config,
    required this.logger,
  });

  final GatewayConfig config;
  final StructuredLogger logger;
  final Map<String, String> _markerIdsByStationId = {};

  /// Upserts a Wayfinder marker from a parsed APRS payload.
  Future<bool> post(Map<String, dynamic> payload) async {
    final stationId = payload['stationId']?.toString();
    if (stationId == null || stationId.isEmpty) {
      logger.warn('Skipping APRS payload without stationId');
      return true;
    }

    final markerId = _markerIdsByStationId[stationId] ??
        await _findMarkerIdByName(stationId, payload['layerId']?.toString());

    if (markerId != null) {
      _markerIdsByStationId[stationId] = markerId;
      return _updateMarker(markerId, payload);
    }

    return _createMarker(payload);
  }

  Future<bool> _createMarker(Map<String, dynamic> payload) async {
    final stationId = payload['stationId']?.toString();
    Map<String, dynamic> body;
    try {
      body = WayfinderMarkerMapper.createBody(payload);
    } on FormatException catch (e) {
      logger.warn(
        'Skipping invalid APRS payload',
        fields: {'error': e.message, 'stationId': stationId},
      );
      return true;
    }

    final decoded = await _sendJson(
      method: 'POST',
      url: markersApiUrl(config.mappingServerUrl),
      body: body,
    );

    if (decoded is! Map) {
      return false;
    }

    final marker = Map<String, dynamic>.from(decoded);
    final markerId = marker['id']?.toString();
    if (markerId != null && stationId != null) {
      _markerIdsByStationId[stationId] = markerId;
    }

    logger.info(
      'Created Wayfinder marker',
      fields: {
        'stationId': stationId,
        'markerId': markerId,
        'packetType': payload['packetType'],
      },
    );
    await _syncTrackTransportationMode(marker, payload);
    return markerId != null;
  }

  Future<bool> _updateMarker(
    String markerId,
    Map<String, dynamic> payload,
  ) async {
    String? existingWeatherJson;
    if (payload['packetType']?.toString() == 'weather') {
      final existing = await getMarker(markerId);
      existingWeatherJson = existing?['weatherJson']?.toString();
    }

    final body = WayfinderMarkerMapper.updateBody(
      payload,
      existingWeatherJson: existingWeatherJson,
    );
    if (body.isEmpty) {
      return true;
    }

    final decoded = await _sendJson(
      method: 'PATCH',
      url: markersApiUrl(config.mappingServerUrl).replace(
        path: '/api/markers/$markerId',
      ),
      body: body,
    );

    if (decoded is! Map) {
      return false;
    }

    logger.info(
      'Updated Wayfinder marker',
      fields: {
        'stationId': payload['stationId'],
        'markerId': markerId,
        'packetType': payload['packetType'],
      },
    );
    if (decoded is Map) {
      await _syncTrackTransportationMode(
        Map<String, dynamic>.from(decoded),
        payload,
      );
    }
    return true;
  }

  Future<void> _syncTrackTransportationMode(
    Map<String, dynamic> marker,
    Map<String, dynamic> payload,
  ) async {
    final transportationMode = payload['transportationMode']?.toString();
    if (transportationMode == null || transportationMode.isEmpty) {
      return;
    }

    final trackZoneId = marker['trackZoneId']?.toString();
    if (trackZoneId == null || trackZoneId.isEmpty) {
      return;
    }

    final zone = await getZone(trackZoneId);
    if (zone == null) {
      return;
    }

    final geometryJson = zone['geometryJson']?.toString();
    if (geometryJson == null || geometryJson.isEmpty) {
      return;
    }

    final updatedGeometry = TrackZoneGeometry.updatedTransportationMode(
      geometryJson,
      transportationMode,
    );
    if (updatedGeometry == null) {
      return;
    }

    final decoded = await _sendJson(
      method: 'PATCH',
      url: zonesApiUrl(config.mappingServerUrl).replace(
        path: '/api/zones/$trackZoneId',
      ),
      body: {'geometryJson': updatedGeometry},
    );

    if (decoded is Map) {
      logger.info(
        'Synced track transportation mode',
        fields: {
          'stationId': payload['stationId'],
          'trackZoneId': trackZoneId,
          'transportationMode': transportationMode,
        },
      );
    }
  }

  Future<Map<String, dynamic>?> getMarker(String id) async {
    final decoded = await _sendJson(
      method: 'GET',
      url: markersApiUrl(config.mappingServerUrl).replace(
        path: '/api/markers/$id',
      ),
    );
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>?> getZone(String id) async {
    final decoded = await _sendJson(
      method: 'GET',
      url: zonesApiUrl(config.mappingServerUrl).replace(path: '/api/zones/$id'),
    );
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }

  Future<String?> _findMarkerIdByName(
    String stationId,
    String? layerId,
  ) async {
    for (final marker in await listMarkers()) {
      if (marker['name'] != stationId) continue;
      if (layerId != null && marker['layerId']?.toString() != layerId) {
        continue;
      }
      return marker['id']?.toString();
    }
    return null;
  }

  /// Ensures the simulator layer exists and clears its markers and zones.
  Future<String?> prepareSimulatorLayer(String layerName) async {
    _markerIdsByStationId.clear();
    final layer = await findOrCreateLayer(layerName);
    final layerId = layer?['id']?.toString();
    if (layerId == null || layerId.isEmpty) {
      logger.warn(
        'Unable to prepare simulator layer',
        fields: {'layerName': layerName},
      );
      return null;
    }

    final markersDeleted = await _deleteLayerMarkers(layerId);
    final zonesDeleted = await _deleteLayerZones(layerId);

    logger.info(
      'Prepared simulator layer',
      fields: {
        'layerName': layerName,
        'layerId': layerId,
        'markersDeleted': markersDeleted,
        'zonesDeleted': zonesDeleted,
      },
    );

    return layerId;
  }

  Future<Map<String, dynamic>?> findOrCreateLayer(String layerName) async {
    final layers = await listLayers();
    for (final layer in layers) {
      if (layer['name'] == layerName) {
        return layer;
      }
    }

    return createLayer(layerName);
  }

  Future<Map<String, dynamic>?> createLayer(String name) async {
    final decoded = await _sendJson(
      method: 'POST',
      url: layersApiUrl(config.mappingServerUrl),
      body: {'name': name},
    );
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }

  Future<List<Map<String, dynamic>>> listLayers() async {
    final decoded = await _sendJson(
      method: 'GET',
      url: layersApiUrl(config.mappingServerUrl),
    );
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map((layer) => Map<String, dynamic>.from(layer))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listZones() async {
    final decoded = await _sendJson(
      method: 'GET',
      url: zonesApiUrl(config.mappingServerUrl),
    );
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map((zone) => Map<String, dynamic>.from(zone))
        .toList();
  }

  Future<int> _deleteLayerMarkers(String layerId) async {
    final markers = await listMarkers();
    var deleted = 0;

    for (final marker in markers) {
      if (marker['layerId']?.toString() != layerId) continue;
      final id = marker['id']?.toString();
      if (id == null || id.isEmpty) continue;
      if (await deleteMarker(id)) deleted++;
    }

    return deleted;
  }

  Future<int> _deleteLayerZones(String layerId) async {
    final zones = await listZones();
    var deleted = 0;

    for (final zone in zones) {
      if (zone['layerId']?.toString() != layerId) continue;
      final id = zone['id']?.toString();
      if (id == null || id.isEmpty) continue;
      if (await deleteZone(id)) deleted++;
    }

    return deleted;
  }

  Future<bool> deleteZone(String id) async {
    return _send(
      method: 'DELETE',
      url: zonesApiUrl(config.mappingServerUrl).replace(path: '/api/zones/$id'),
      onSuccess: (_) => true,
      onFailure: (statusCode, body) {
        logger.warn(
          'Failed to delete Wayfinder zone',
          fields: {
            'zoneId': id,
            'statusCode': statusCode,
            'body': body,
          },
        );
        return false;
      },
    );
  }

  Future<List<Map<String, dynamic>>> listMarkers() async {
    final decoded = await _sendJson(
      method: 'GET',
      url: markersApiUrl(config.mappingServerUrl),
    );
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map((marker) => Map<String, dynamic>.from(marker))
        .toList();
  }

  Future<bool> deleteMarker(String id) async {
    return _send(
      method: 'DELETE',
      url: markersApiUrl(config.mappingServerUrl).replace(path: '/api/markers/$id'),
      onSuccess: (_) => true,
      onFailure: (statusCode, body) {
        logger.warn(
          'Failed to delete Wayfinder marker',
          fields: {
            'markerId': id,
            'statusCode': statusCode,
            'body': body,
          },
        );
        return false;
      },
    );
  }

  static Uri markersApiUrl(Uri mappingServerUrl) {
    return mappingServerUrl.replace(path: '/api/markers');
  }

  static Uri layersApiUrl(Uri mappingServerUrl) {
    return mappingServerUrl.replace(path: '/api/layers');
  }

  static Uri zonesApiUrl(Uri mappingServerUrl) {
    return mappingServerUrl.replace(path: '/api/zones');
  }

  Future<bool> _send({
    required String method,
    required Uri url,
    Map<String, dynamic>? body,
    required bool Function(int statusCode) onSuccess,
    required bool Function(int statusCode, String body) onFailure,
  }) async {
    final client = HttpClient();

    try {
      final request = await _openRequest(client, method, url);
      request.headers.contentType = ContentType.json;
      _applyAuth(request.headers);

      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return onSuccess(response.statusCode);
      }

      return onFailure(response.statusCode, responseBody);
    } on SocketException catch (e) {
      logger.warn(
        'Mapping server unreachable',
        fields: {'error': e.message, 'url': url.toString()},
      );
      return false;
    } on HttpException catch (e) {
      logger.warn(
        'Mapping server HTTP error',
        fields: {'error': e.message, 'url': url.toString()},
      );
      return false;
    } catch (e) {
      logger.error(
        'Unexpected mapping server error',
        fields: {'error': e.toString(), 'url': url.toString()},
      );
      return false;
    } finally {
      client.close();
    }
  }

  Future<Object?> _sendJson({
    required String method,
    required Uri url,
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient();

    try {
      final request = await _openRequest(client, method, url);
      _applyAuth(request.headers);

      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        logger.warn(
          'Mapping server request failed',
          fields: {
            'method': method,
            'statusCode': response.statusCode,
            'url': url.toString(),
            'body': responseBody,
          },
        );
        return null;
      }

      if (responseBody.trim().isEmpty) return null;
      return jsonDecode(responseBody);
    } on SocketException catch (e) {
      logger.warn(
        'Mapping server unreachable',
        fields: {'error': e.message, 'url': url.toString()},
      );
      return null;
    } catch (e) {
      logger.warn(
        'Failed to read mapping server response',
        fields: {'error': e.toString(), 'url': url.toString()},
      );
      return null;
    } finally {
      client.close();
    }
  }

  Future<HttpClientRequest> _openRequest(
    HttpClient client,
    String method,
    Uri url,
  ) {
    switch (method) {
      case 'GET':
        return client.getUrl(url);
      case 'DELETE':
        return client.deleteUrl(url);
      case 'POST':
        return client.postUrl(url);
      case 'PATCH':
        return client.patchUrl(url);
      default:
        throw ArgumentError.value(method, 'method', 'Unsupported HTTP method');
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
