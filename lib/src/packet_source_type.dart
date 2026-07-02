enum PacketSourceType {
  kiss,
  simulator,
  replay,
  aprsis;

  static PacketSourceType parse(String? value) {
    switch (value?.trim().toLowerCase()) {
      case null:
      case '':
      case 'kiss':
      case 'direwolf':
        return PacketSourceType.kiss;
      case 'simulator':
        return PacketSourceType.simulator;
      case 'replay':
        return PacketSourceType.replay;
      case 'aprsis':
      case 'aprs-is':
        return PacketSourceType.aprsis;
      default:
        throw ArgumentError.value(
          value,
          'APRS_PACKET_SOURCE',
          'Supported values: kiss, simulator, replay, aprsis',
        );
    }
  }
}
