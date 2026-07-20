import 'package:audioplayers/audioplayers.dart';

class PreviewSoundService {
  static final PreviewSoundService _instance = PreviewSoundService._internal();
  factory PreviewSoundService() => _instance;
  PreviewSoundService._internal();

  final AudioPlayer _piecePlayer = AudioPlayer();
  final AudioPlayer _typingPlayer = AudioPlayer();

  bool _isTyping = false;

  void playMoveSound({bool isCapture = false, bool isPromotion = false, bool isCheck = false}) {
    String file = 'put.wav';
    if (isPromotion) file = 'promotion.wav';
    else if (isCapture) file = 'capture.wav';
    // isCheck can be added later if we find a sound for it

    _piecePlayer.play(AssetSource('audio/$file'));
  }

  void startTyping() async {
    if (_isTyping) return;
    _isTyping = true;
    _typingPlayer.setReleaseMode(ReleaseMode.loop);
    await _typingPlayer.play(AssetSource('audio/typing.wav'));
  }

  void stopTyping() async {
    if (!_isTyping) return;
    _isTyping = false;
    await _typingPlayer.stop();
  }
}
