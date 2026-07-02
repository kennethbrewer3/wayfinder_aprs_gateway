import 'simulator_config.dart';

class AprsInfoBuilder {
  static String formatLatitude(double latitude) {
    final hemisphere = latitude >= 0 ? 'N' : 'S';
    final absolute = latitude.abs();
    final degrees = absolute.floor();
    final minutes = (absolute - degrees) * 60;
    return '${degrees.toString().padLeft(2, '0')}'
        '${minutes.toStringAsFixed(2).padLeft(5, '0')}'
        '$hemisphere';
  }

  static String formatLongitude(double longitude) {
    final hemisphere = longitude >= 0 ? 'E' : 'W';
    final absolute = longitude.abs();
    final degrees = absolute.floor();
    final minutes = (absolute - degrees) * 60;
    return '${degrees.toString().padLeft(3, '0')}'
        '${minutes.toStringAsFixed(2).padLeft(5, '0')}'
        '$hemisphere';
  }

  static String uncompressedPosition({
    required double latitude,
    required double longitude,
    required String symbolTable,
    required String symbolCode,
    String? comment,
    bool messagingCapable = false,
  }) {
    final prefix = messagingCapable ? '=' : '!';
    return '$prefix${formatLatitude(latitude)}$symbolTable'
        '${formatLongitude(longitude)}$symbolCode${comment ?? ''}';
  }

  static String weatherPosition({
    required double latitude,
    required double longitude,
    required SimulatorWeatherSettings weather,
    String? comment,
  }) {
    final weatherBody = encodeWeather(weather);
    return uncompressedPosition(
      latitude: latitude,
      longitude: longitude,
      symbolTable: '/',
      symbolCode: '_',
      comment: '$weatherBody${comment ?? ''}',
      messagingCapable: true,
    );
  }

  static String encodeWeather(SimulatorWeatherSettings weather) {
    final windSpeed = weather.windSpeedKnots.clamp(0, 999);
    final windGust = weather.windGustKnots.clamp(0, 999);
    final humidity = weather.humidity.clamp(0, 99);
    final rain = (weather.rain1hInches * 100).round().clamp(0, 999);
    final pressure = (weather.pressureMb * 10).round().clamp(0, 99999);
    final temperature = weather.temperatureF;

    return '${weather.windDirection.toString().padLeft(3, '0')}/'
        '${windSpeed.toString().padLeft(3, '0')}'
        'g${windGust.toString().padLeft(3, '0')}'
        't${temperature.toString().padLeft(3, '0')}'
        'r${rain.toString().padLeft(3, '0')}'
        'h${humidity.toString().padLeft(2, '0')}'
        'b${pressure.toString().padLeft(5, '0')}';
  }
}
