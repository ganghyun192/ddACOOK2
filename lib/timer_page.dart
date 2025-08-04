import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  int _remainingSeconds = 0;
  bool _isRunning = false;
  late FlutterTts _tts;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _tts.setLanguage("ko-KR");
    _tts.setSpeechRate(0.5);
  }

  void _startTimer() {
    _isRunning = true;
    _tts.speak("설정하신 시간은 ${_remainingSeconds ~/ 60}분입니다.");
    Future.delayed(const Duration(seconds: 1), _tick);
  }

  void _tick() {
    if (!_isRunning) return;
    if (_remainingSeconds > 0) {
      setState(() {
        _remainingSeconds--;
      });
      Future.delayed(const Duration(seconds: 1), _tick);
    } else {
      _tts.speak("끝");
      _isRunning = false;
    }
  }

  void _adjustTime(int delta) {
    if (_isRunning) return;
    setState(() {
      _remainingSeconds = (_remainingSeconds + delta).clamp(0, 3600);
    });
  }

  void _onDoubleTap() {
    if (_remainingSeconds > 0 && !_isRunning) {
      _startTimer();
    }
  }

  String _formatTime() {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (_isRunning) return;
          if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
            _adjustTime(60); // ➡️ 오른쪽: +1분
          } else if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
            _adjustTime(-60); // ⬅️ 왼쪽: -1분
          }
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
            Navigator.pop(context); // ⬇️ 아래로: 홈으로 복귀
          } else if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
            _adjustTime(600); // ⬆️ 위로: +10분
          }
        },
        onDoubleTap: _onDoubleTap,
        child: Center(
          child: Text(
            _formatTime(),
            style: const TextStyle(
              fontSize: 72,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
