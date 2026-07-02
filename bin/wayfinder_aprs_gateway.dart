import 'package:wayfinder_aprs_gateway/wayfinder_aprs_gateway.dart';

Future<void> main(List<String> args) async {
  final config = await GatewayConfig.load(args: args);
  final logger = StructuredLogger(config.logLevel);
  final gateway = AprsGateway(config: config, logger: logger);

  await gateway.start();
}
