import 'dart:math';

class IdGenerator {
  const IdGenerator();

  String create() {
    final random = Random.secure();
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final suffix = List<int>.generate(8, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '$now$suffix';
  }
}
