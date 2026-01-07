import 'package:flutter/widgets.dart';

/// Helper to track block alignment between search index and widget generation.
class BlockIndexCounter {
  int _value = 0;
  final Map<int, GlobalKey> keyRegistry = {};

  int get value => _value;

  void increment() => _value++;

  GlobalKey registerKey(int index) {
    if (!keyRegistry.containsKey(index)) {
      keyRegistry[index] = GlobalKey(debugLabel: 'block_$index');
    }
    return keyRegistry[index]!;
  }
}
