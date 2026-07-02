import 'dart:typed_data';

class Kiss {
  static const int fend = 0xC0;
  static const int fesc = 0xDB;
  static const int tfend = 0xDC;
  static const int tfesc = 0xDD;

  static Uint8List decode(Uint8List input) {
    final output = BytesBuilder();

    for (var i = 0; i < input.length; i++) {
      final byte = input[i];

      if (byte == fesc && i + 1 < input.length) {
        final next = input[++i];

        if (next == tfend) {
          output.addByte(fend);
        } else if (next == tfesc) {
          output.addByte(fesc);
        }
      } else {
        output.addByte(byte);
      }
    }

    return output.takeBytes();
  }
}
