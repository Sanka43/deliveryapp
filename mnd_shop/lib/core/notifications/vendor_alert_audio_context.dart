import 'package:audioplayers/audioplayers.dart';

/// Audio context for in-app order alert playback.
///
/// Routes the sound to Android's notification stream (instead of the media
/// stream, which is often muted while notification volume is up) and uses the
/// iOS playback category so alerts are audible with the screen locked.
AudioContext vendorAlertAudioContext() {
  return AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.notification,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const <AVAudioSessionOptions>{
        AVAudioSessionOptions.duckOthers,
      },
    ),
  );
}
