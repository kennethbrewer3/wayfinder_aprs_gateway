import 'dart:convert';
import 'dart:typed_data';

class Ax25Frame {
  Ax25Frame({
    required this.destination,
    required this.source,
    required this.path,
    required this.info,
  });

  final String destination;
  final String source;
  final List<String> path;
  final String info;

  String get destinationCall => destination.split('-').first;

  static Ax25Frame? tryParse(Uint8List bytes) {
    if (bytes.length < 16) return null;

    var offset = 0;

    final destination = _decodeAddress(bytes.sublist(offset, offset + 7));
    offset += 7;

    final source = _decodeAddress(bytes.sublist(offset, offset + 7));
    offset += 7;

    final path = <String>[];

    while (offset + 7 <= bytes.length) {
      final addressBytes = bytes.sublist(offset, offset + 7);
      final isLastAddress = (addressBytes[6] & 0x01) == 0x01;

      if (offset >= 14) {
        path.add(_decodeAddress(addressBytes));
      }

      offset += 7;

      if (isLastAddress) break;
    }

    if (offset + 2 > bytes.length) return null;

    final control = bytes[offset++];
    final pid = bytes[offset++];

    if (control != 0x03 || pid != 0xF0) return null;

    final infoBytes = bytes.sublist(offset);
    final info = ascii.decode(infoBytes, allowInvalid: true);

    return Ax25Frame(
      destination: destination,
      source: source,
      path: path,
      info: info,
    );
  }

  static String _decodeAddress(Uint8List bytes) {
    final call = StringBuffer();

    for (var i = 0; i < 6; i++) {
      final charCode = bytes[i] >> 1;
      if (charCode != 0x20) {
        call.writeCharCode(charCode);
      }
    }

    final ssid = (bytes[6] >> 1) & 0x0F;

    if (ssid > 0) {
      return '${call.toString()}-$ssid';
    }

    return call.toString();
  }
}
