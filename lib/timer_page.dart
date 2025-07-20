// timer_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  int _remainingSeconds = 0;
  Timer? _timer;
  bool _isRunning = false;
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _speak('타이머 설정 화면입니다. 위로 스와이프하면 10분, 오른쪽은 1분 증가, 왼쪽은 1분 감소합니다. 설정을 마치려면 화면을 두 번 터치해주세요.');
  }

  Future<void> _speak(String text) async {
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.speak(text);
  }

  void _startTimer() {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isRunning = false;
        });
        _speak('타이머가 종료되었습니다.');
      }
    });
  }

  void _adjustTime(int delta) {
    if (_isRunning) return;
    setState(() {
      _remainingSeconds = (_remainingSeconds + delta).clamp(0, 3599);
    });
  }

  void _onDoubleTap() {
    if (_remainingSeconds > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('타이머 설정 완료')),
      );
      final minutes = _remainingSeconds ~/ 60;
      final seconds = _remainingSeconds % 60;
      _speak('타이머 설정이 완료되었습니다. 설정된 시간은 $minutes분 $seconds초 입니다.');
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          Navigator.pop(context);
        } else if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
          _adjustTime(600);
        }
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          _adjustTime(60);
        } else if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
          _adjustTime(-60);
        }
      },
      onDoubleTap: _onDoubleTap,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            '$minutes:$seconds',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
