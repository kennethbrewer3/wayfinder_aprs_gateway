/// Identifies APRS digipeater / repeater fixed-station reports.
abstract final class AprsRepeater {
  static const symbolCode = '#';

  static bool isSymbol({
    String? symbolTable,
    String? symbolCode,
  }) {
    return symbolCode == AprsRepeater.symbolCode;
  }

  static bool isPayload(Map<String, dynamic> payload) {
    if (payload['packetType']?.toString() == 'repeater') {
      return true;
    }

    return isSymbol(
      symbolTable: payload['symbolTable']?.toString(),
      symbolCode: payload['symbolCode']?.toString(),
    );
  }
}
