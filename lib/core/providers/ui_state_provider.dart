// lib/core/providers/ui_state_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

class ModalOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final modalOpenProvider =
NotifierProvider<ModalOpenNotifier, bool>(ModalOpenNotifier.new);