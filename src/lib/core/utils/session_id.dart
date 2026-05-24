import 'dart:math';

String newEditorSessionId() {
  final random = Random.secure();
  final now = DateTime.now().millisecondsSinceEpoch;
  final tail = List<int>.generate(8, (_) => random.nextInt(16))
      .map((number) => number.toRadixString(16))
      .join();
  return 'mobile-$now-$tail';
}
