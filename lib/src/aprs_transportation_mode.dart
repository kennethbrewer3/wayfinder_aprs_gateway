/// Maps APRS symbol table/code pairs to Wayfinder track transportation modes.
///
/// See https://www.aprs.org/symbols/symbols-new.txt for the full symbol list.
abstract final class AprsTransportationMode {
  static const onFoot = 'onFoot';
  static const bike = 'bike';
  static const landVehicle = 'landVehicle';
  static const watercraft = 'watercraft';
  static const aircraft = 'aircraft';

  static const _primary = {
    '>': landVehicle, // car
    '<': landVehicle, // motorcycle
    'k': landVehicle, // truck
    'R': landVehicle, // truck
    'u': landVehicle, // bus
    'v': landVehicle, // van
    'L': landVehicle, // train / streetcar
    'j': landVehicle, // jeep / 4x4
    't': landVehicle, // truck (alt)
    'T': landVehicle, // pickup truck
    'C': landVehicle, // car (alt)
    'O': landVehicle, // car (alt)
    '[': onFoot, // person / runner
    'b': bike, // bicycle
    'B': bike, // bike (alt)
    '^': aircraft, // large aircraft
    'n': aircraft, // helicopter
    'X': aircraft, // helicopter (alt)
    's': watercraft, // ship / power boat
    'Y': watercraft, // yacht / sailboat
    'S': watercraft, // ship (alt)
    'W': watercraft, // ship (alt)
  };

  static const _alternate = {
    '>': landVehicle,
    'k': landVehicle,
    'L': landVehicle,
    '[': onFoot,
    'b': bike,
    '^': aircraft,
    's': watercraft,
    'Y': watercraft,
  };

  static String? infer({
    String? symbolTable,
    String? symbolCode,
  }) {
    if (symbolCode == null || symbolCode.isEmpty) {
      return null;
    }

    final table = symbolTable ?? '/';
    if (table == r'\' || table == '\\') {
      return _alternate[symbolCode];
    }

    return _primary[symbolCode];
  }

  static bool shouldTrack({
    required String? packetType,
    required bool hasPosition,
    String? transportationMode,
    String? symbolTable,
    String? symbolCode,
  }) {
    if (!hasPosition || packetType == 'weather') {
      return false;
    }

    return resolve(
          transportationMode: transportationMode,
          symbolTable: symbolTable,
          symbolCode: symbolCode,
        ) !=
        null;
  }

  static String? resolve({
    String? transportationMode,
    String? symbolTable,
    String? symbolCode,
  }) {
    if (transportationMode != null && transportationMode.isNotEmpty) {
      return transportationMode;
    }
    return infer(symbolTable: symbolTable, symbolCode: symbolCode);
  }
}
