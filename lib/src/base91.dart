int base91ToDecimal(String text) {
  if (text.isEmpty) return 0;

  var decimal = 0;
  final length = text.length - 1;

  for (var i = 0; i < text.length; i++) {
    final code = text.codeUnitAt(i);
    if (code <= 0x20 || code >= 0x7c) {
      throw FormatException('invalid base91 character');
    }
    decimal += (code - 33) * _pow91(length - i);
  }

  return decimal;
}

int _pow91(int exponent) {
  var result = 1;
  for (var i = 0; i < exponent; i++) {
    result *= 91;
  }
  return result;
}
