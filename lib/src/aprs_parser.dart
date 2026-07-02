import 'dart:math' as math;

import 'aprs_message.dart';
import 'aprs_repeater.dart';
import 'ax25.dart';
import 'base91.dart';

class AprsParser {
  static AprsMessage? parse(Ax25Frame frame) {
    final info = frame.info;
    if (info.isEmpty) return null;

    final mice = _parseMicE(frame);
    if (mice != null) return mice;

    if (info.startsWith('T#')) {
      return _parseTelemetryReport(info);
    }

    if (info.startsWith('PARM.') ||
        info.startsWith('UNIT.') ||
        info.startsWith('EQNS.') ||
        info.startsWith('BITS.')) {
      return _parseTelemetryConfig(info);
    }

    if (info.startsWith('_')) {
      return _parseWeatherReport(info);
    }

    final type = info[0];
    if (type == '!' || type == '=') {
      return _parsePositionBody(info.substring(1), messagingCapable: type == '=');
    }

    if (type == '/' || type == '@') {
      if (info.length < 8) return null;
      return _parsePositionBody(
        info.substring(8),
        messagingCapable: type == '@',
      );
    }

    return null;
  }

  static AprsMessage? _parsePositionBody(
    String body, {
    required bool messagingCapable,
  }) {
    if (_looksCompressed(body)) {
      return _parseCompressed(body);
    }

    return _parseUncompressed(body, messagingCapable: messagingCapable);
  }

  static bool _looksCompressed(String body) {
    if (body.length < 13) return false;
    return RegExp(r'^[\/\\A-Za-j][!-|]{8}[!-{}]').hasMatch(body);
  }

  static AprsMessage? _parseUncompressed(
    String body, {
    required bool messagingCapable,
  }) {
    if (body.length < 19) return null;

    final latText = body.substring(0, 8);
    final symbolTable = body.substring(8, 9);
    final lonText = body.substring(9, 18);
    final symbolCode = body.substring(18, 19);
    var remainder = body.length > 19 ? body.substring(19) : '';

    final lat = _parseLatitude(latText);
    final lon = _parseLongitude(lonText);
    if (lat == null || lon == null) return null;

    Map<String, dynamic>? weather;
    String? comment;

    if (symbolCode == '_' && remainder.isNotEmpty) {
      final parsed = _parseWeatherData(remainder);
      weather = parsed.weather;
      comment = parsed.comment;
    } else {
      comment = remainder.trim().isEmpty ? null : remainder.trim();
    }

    final packetType = _packetTypeForPosition(
      symbolCode: symbolCode,
      weather: weather,
    );

    return AprsMessage(
      packetType: packetType,
      format: weather == null
          ? (packetType == AprsPacketType.repeater
              ? 'repeater'
              : 'uncompressed')
          : 'weather-position',
      latitude: lat,
      longitude: lon,
      symbolTable: symbolTable,
      symbolCode: symbolCode,
      comment: comment,
      weather: weather,
    );
  }

  static AprsMessage? _parseCompressed(String body) {
    if (body.length < 13) return null;

    final compressed = body.substring(0, 13);
    var remainder = body.substring(13);

    final symbolTable = compressed[0];
    final symbol = compressed[9];

    double latitude;
    double longitude;
    try {
      latitude = 90 - (base91ToDecimal(compressed.substring(1, 5)) / 380926.0);
      longitude =
          -180 + (base91ToDecimal(compressed.substring(5, 9)) / 190463.0);
    } on FormatException {
      return null;
    }

    final c1 = compressed.codeUnitAt(10) - 33;
    final s1 = compressed.codeUnitAt(11) - 33;
    final ctype = compressed.codeUnitAt(12) - 33;

    int? course;
    int? speed;
    int? altitude;

    if (c1 >= 0 && s1 >= 0) {
      if ((ctype & 0x18) == 0x10) {
        altitude =
            (math.pow(1.002, c1 * 91 + s1).toDouble() * 0.3048).round();
      } else if (c1 >= 0 && c1 <= 89) {
        course = c1 == 0 ? 360 : c1 * 4;
        speed = ((math.pow(1.08, s1).toDouble() - 1) * 1.852).round();
      }
    }

    return AprsMessage(
      packetType: AprsRepeater.isSymbol(symbolCode: symbol)
          ? AprsPacketType.repeater
          : AprsPacketType.position,
      format: AprsRepeater.isSymbol(symbolCode: symbol)
          ? 'repeater'
          : 'compressed',
      latitude: latitude,
      longitude: longitude,
      symbolTable: symbolTable,
      symbolCode: symbol,
      comment: remainder.trim().isEmpty ? null : remainder.trim(),
      course: course,
      speed: speed,
      altitude: altitude,
    );
  }

  static AprsMessage? _parseMicE(Ax25Frame frame) {
    final info = frame.info;
    if (info.length < 8) return null;

    final micType = info.codeUnitAt(0);
    if (micType != 0x60 && micType != 0x27 && micType != 0x1d) {
      return null;
    }

    final dstcall = frame.destinationCall;
    if (dstcall.length != 6) return null;
    if (!RegExp(r'^[0-9A-Z]{3}[0-9L-Z]{3}$').hasMatch(dstcall)) {
      return null;
    }

    var tmpdstcall = '';
    for (final char in dstcall.split('')) {
      final code = char.codeUnitAt(0);
      if ('KLZ'.contains(char)) {
        tmpdstcall += ' ';
      } else if (code > 76) {
        tmpdstcall += String.fromCharCode(code - 32);
      } else if (code > 57) {
        tmpdstcall += String.fromCharCode(code - 17);
      } else {
        tmpdstcall += char;
      }
    }

    final ambiguityMatch = RegExp(r'^\d+( *)$').firstMatch(tmpdstcall);
    if (ambiguityMatch == null) return null;

    final latMinutes =
        double.parse('${tmpdstcall.substring(2, 4)}.${tmpdstcall.substring(4, 6)}'.replaceAll(' ', '0'));
    var latitude = int.parse(tmpdstcall.substring(0, 2)) + (latMinutes / 60.0);
    if (dstcall.codeUnitAt(3) <= 0x4c) {
      latitude = -latitude;
    }

    var longitude = (info.codeUnitAt(1) - 28).toDouble();
    if (dstcall.codeUnitAt(4) >= 0x50) {
      longitude += 100;
    }
    if (longitude >= 180 && longitude <= 189) {
      longitude -= 80;
    } else if (longitude >= 190 && longitude <= 199) {
      longitude -= 190;
    }

    var lngMinutes = info.codeUnitAt(2) - 28.0;
    if (lngMinutes >= 60) lngMinutes -= 60;
    lngMinutes += (info.codeUnitAt(3) - 28.0) / 100.0;
    longitude += lngMinutes / 60.0;

    if (dstcall.codeUnitAt(5) >= 0x50) {
      longitude = -longitude;
    }

    var speed = (info.codeUnitAt(4) - 28) * 10;
    var course = info.codeUnitAt(5) - 28;
    final quotient = course ~/ 10;
    course = (course - (quotient * 10)) * 100 + (info.codeUnitAt(6) - 28);
    speed += quotient;
    if (speed >= 800) speed -= 800;
    if (course >= 400) course -= 400;

    final mbits = dstcall
        .substring(0, 3)
        .replaceAll(RegExp(r'[0-9L]'), '0')
        .replaceAll(RegExp(r'[P-Z]'), '1')
        .replaceAll(RegExp(r'[A-K]'), '2');

    final messageType = _micEMessageType(mbits);
    final comment = info.length > 8 ? info.substring(8).trim() : null;

    return AprsMessage(
      packetType: AprsPacketType.mice,
      format: 'mic-e',
      latitude: latitude,
      longitude: longitude,
      symbolTable: info[7],
      symbolCode: info[6],
      comment: comment?.isEmpty ?? true ? null : comment,
      course: course,
      speed: (speed * 1.852).round(),
      messageType: messageType,
    );
  }

  static String _micEMessageType(String mbits) {
    const standard = {
      '111': 'Off Duty',
      '110': 'En Route',
      '101': 'In Service',
      '100': 'Returning',
      '011': 'Committed',
      '010': 'Special',
      '001': 'Priority',
      '000': 'Emergency',
    };

    final key = mbits.contains('2') ? mbits.replaceAll('2', '1') : mbits;
    return standard[key] ?? 'Unknown';
  }

  static AprsMessage? _parseWeatherReport(String info) {
    final body = info.substring(1);

    if (RegExp(r'^\d{8}').hasMatch(body) &&
        RegExp(r'^\d{8}c').hasMatch(body)) {
      final weatherBody = body.substring(8);
      final parsed = _parseWeatherData(weatherBody);
      return AprsMessage(
        packetType: AprsPacketType.weather,
        format: 'weather-positionless',
        comment: parsed.comment,
        weather: {
          'rawTimestamp': body.substring(0, 8),
          ...?parsed.weather,
        },
      );
    }

    if (body.length >= 19 &&
        RegExp(r'^\d{2}\d{2}\.\d{2}[NS]/\d{3}\d{2}\.\d{2}[EW]_').hasMatch(body)) {
      final lat = _parseLatitude(body.substring(0, 8));
      final lon = _parseLongitude(body.substring(9, 18));
      final parsed = _parseWeatherData(body.substring(19));

      return AprsMessage(
        packetType: AprsPacketType.weather,
        format: 'weather',
        latitude: lat,
        longitude: lon,
        symbolTable: body.substring(8, 9),
        symbolCode: body.substring(18, 19),
        comment: parsed.comment,
        weather: parsed.weather,
      );
    }

    if (body.length >= 8) {
      final positionText = body.substring(0, 8);
      final lat = _parseWeatherLatitude(positionText.substring(0, 4));
      final lon = _parseWeatherLongitude(positionText.substring(4, 8));
      final parsed = _parseWeatherData(body.substring(8));

      return AprsMessage(
        packetType: AprsPacketType.weather,
        format: 'weather-compact',
        latitude: lat,
        longitude: lon,
        comment: parsed.comment,
        weather: parsed.weather,
      );
    }

    return null;
  }

  static double? _parseWeatherLatitude(String value) {
    if (value.length != 4) return null;
    final degrees = int.tryParse(value.substring(0, 2));
    final minutes = int.tryParse(value.substring(2, 4));
    if (degrees == null || minutes == null) return null;
    return degrees + minutes / 60.0;
  }

  static double? _parseWeatherLongitude(String value) {
    if (value.length != 4) return null;
    final degrees = int.tryParse(value.substring(0, 3));
    final minutes = int.tryParse(value.substring(3, 4)) != null
        ? int.parse(value.substring(3, 4)) * 10
        : null;
    if (degrees == null || minutes == null) return null;
    return degrees + minutes / 60.0;
  }

  static AprsMessage? _parseTelemetryReport(String info) {
    final match = RegExp(
      r'^T#(\d{3}),(\d{3}),(\d{3}),(\d{3}),(\d{3}),(\d{8})$',
    ).firstMatch(info);
    if (match == null) return null;

    final values = [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
    ];
    final digital = match.group(6)!;

    return AprsMessage(
      packetType: AprsPacketType.telemetry,
      format: 'telemetry-report',
      telemetry: {
        'channels': values,
        'digitalBits': digital,
      },
    );
  }

  static AprsMessage? _parseTelemetryConfig(String info) {
    final match = RegExp(r'^(PARM|UNIT|EQNS|BITS)\.(.*)$').firstMatch(info);
    if (match == null) return null;

    return AprsMessage(
      packetType: AprsPacketType.telemetry,
      format: 'telemetry-config',
      telemetry: {
        'section': match.group(1),
        'data': match.group(2),
      },
    );
  }

  static _WeatherParseResult _parseWeatherData(String body) {
    var normalized = body.replaceFirstMapped(
      RegExp(r'^(\d{3})/(\d{3})'),
      (match) => 'c${match.group(1)}s${match.group(2)}',
    );
    if (normalized.contains('s')) {
      normalized = normalized.replaceFirst('s', 'S');
    }

    final weather = <String, dynamic>{};
    final fieldPattern = RegExp(
      r'([cSgtrpPlLs#]\d{3}|t-\d{2}|h\d{2}|b\d{5}|s\.\d{2}|s\d\.\d)',
    );

    var index = 0;
    while (index < normalized.length) {
      final match = fieldPattern.matchAsPrefix(normalized, index);
      if (match == null) break;

      final token = match.group(1)!;
      final key = token[0];
      final value = token.substring(1);
      final mapped = _weatherField(key, value);
      if (mapped != null) {
        weather[mapped.key] = mapped.value;
      }
      index = match.end;
    }

    final comment = normalized.substring(index);

    return _WeatherParseResult(
      weather: weather.isEmpty ? null : weather,
      comment: comment.trim().isEmpty ? null : comment.trim(),
    );
  }

  static _WeatherField? _weatherField(String key, String value) {
    switch (key) {
      case 'c':
        return _WeatherField('windDirection', int.parse(value));
      case 'S':
        return _WeatherField('windSpeed', int.parse(value) * 0.44704);
      case 'g':
        return _WeatherField('windGust', int.parse(value) * 0.44704);
      case 't':
        return _WeatherField('temperature', (double.parse(value) - 32) / 1.8);
      case 'r':
        return _WeatherField('rain1h', int.parse(value) * 0.254);
      case 'p':
        return _WeatherField('rain24h', int.parse(value) * 0.254);
      case 'P':
        return _WeatherField('rainSinceMidnight', int.parse(value) * 0.254);
      case 'h':
        final humidity = int.parse(value);
        return _WeatherField('humidity', humidity == 0 ? 100 : humidity);
      case 'b':
        return _WeatherField('pressure', double.parse(value) / 10);
      case 'L':
        return _WeatherField('luminosity', int.parse(value));
      case 'l':
        return _WeatherField('luminosity', int.parse(value) + 1000);
      case 's':
        return _WeatherField('snow', double.parse(value) * 25.4);
      case '#':
        return _WeatherField('rainRaw', int.parse(value));
      default:
        return null;
    }
  }

  static double? _parseLatitude(String value) {
    final match = RegExp(r'^(\d{2})(\d{2}\.\d{2})([NS])$').firstMatch(value);
    if (match == null) return null;

    final degrees = double.parse(match.group(1)!);
    final minutes = double.parse(match.group(2)!);
    final hemisphere = match.group(3)!;

    var decimal = degrees + minutes / 60.0;
    if (hemisphere == 'S') decimal = -decimal;
    return decimal;
  }

  static double? _parseLongitude(String value) {
    final match = RegExp(r'^(\d{3})(\d{2}\.\d{2})([EW])$').firstMatch(value);
    if (match == null) return null;

    final degrees = double.parse(match.group(1)!);
    final minutes = double.parse(match.group(2)!);
    final hemisphere = match.group(3)!;

    var decimal = degrees + minutes / 60.0;
    if (hemisphere == 'W') decimal = -decimal;
    return decimal;
  }

  static AprsPacketType _packetTypeForPosition({
    required String symbolCode,
    required Map<String, dynamic>? weather,
  }) {
    if (weather != null) {
      return AprsPacketType.weather;
    }
    if (AprsRepeater.isSymbol(symbolCode: symbolCode)) {
      return AprsPacketType.repeater;
    }
    return AprsPacketType.position;
  }
}

class _WeatherParseResult {
  _WeatherParseResult({this.weather, this.comment});

  final Map<String, dynamic>? weather;
  final String? comment;
}

class _WeatherField {
  _WeatherField(this.key, this.value);

  final String key;
  final Object value;
}
