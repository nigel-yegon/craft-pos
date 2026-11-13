import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';
import '../services/mpesa/mpesa_config.dart';
import '../services/mpesa/mpesa_service.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService.instance;
});

final mpesaConfigProvider = Provider<MpesaConfig>((ref) {
  return MpesaConfig.fromEnvironment();
});

final mpesaServiceProvider = Provider<MpesaService>((ref) {
  final config = ref.watch(mpesaConfigProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  return MpesaService(config, connectivity);
});