// lib/core/providers/mpesa_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:craft_pos/core/services/connectivity_service.dart';
import 'package:craft_pos/core/services/mpesa/mpesa_config.dart';
import 'package:craft_pos/core/services/mpesa/mpesa_service.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService.instance;
});

final mpesaConfigProvider = Provider<MpesaConfig>((ref) {
  return MpesaConfig.fromEnvironment();
});

final mpesaServiceProvider = Provider<MpesaService>((ref) {
  final config = ref.watch(mpesaConfigProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final service = MpesaService(config, connectivity);
  ref.onDispose(service.dispose);
  return service;
});