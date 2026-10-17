import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// نغمة الطلب الجديد: نغمتان صاعدتان — تُسمع في ضجيج المطعم بلا إزعاج.
/// نفس نغمة الموقع (784 ثم 1046 هرتز) محفوظة كملف صوتي.
///
/// «تُخفض» الموسيقى المشغّلة بدل إيقافها: كثير من المطاعم تشغّل موسيقى
/// من نفس الجهاز، والتنبيه يجب ألا يقطعها.
class OrderChime {
  OrderChime._();

  static final OrderChime instance = OrderChime._();

  AudioPlayer? _player;
  bool _failed = false;

  Future<AudioPlayer?> _ensure() async {
    if (_failed) return null;
    if (_player != null) return _player;
    try {
      final player = AudioPlayer(playerId: 'order_chime');
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.duckOthers).build());
      _player = player;
      return player;
    } catch (e) {
      // منصة بلا دعم صوت (مثل الاختبارات) — التنبيه الاهتزازي يكفي
      _failed = true;
      debugPrint('order chime unavailable: $e');
      return null;
    }
  }

  Future<void> play() async {
    HapticFeedback.heavyImpact();
    final player = await _ensure();
    if (player == null) return;
    try {
      await player.stop();
      await player.play(AssetSource('sounds/order_chime.wav'), volume: 1);
    } catch (e) {
      debugPrint('order chime failed: $e');
    }
  }
}
