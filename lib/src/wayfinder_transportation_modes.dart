/// Wayfinder track transportation modes accepted by the server.
abstract final class WayfinderTransportationModes {
  static const all = {
    'onFoot',
    'horse',
    'bike',
    'motorcycle',
    'atv',
    'landVehicle',
    'truck',
    'bus',
    'rv',
    'train',
    'ambulance',
    'fireTruck',
    'farmVehicle',
    'canoe',
    'watercraft',
    'sailboat',
    'aircraft',
    'helicopter',
    'glider',
    'balloon',
  };

  static bool contains(String value) => all.contains(value);
}
