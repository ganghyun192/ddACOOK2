// timer_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  // ===== 상태 =====
  int _seconds = 600; // 기본 10분
  bool _isRunning = false;
  bool _isLockedAfterConfirm = false; // 더블탭 후 조정 잠금

  Timer? _timer;
  final FlutterTts _tts = FlutterTts();

  // 스와이프 판정용
  Offset _swipeStart = Offset.zero;

  @override
  void initState() {
    super.initState();
    // TTS 기본 설정(필요시 조정 가능)
    _tts.setLanguage("ko-KR");
    _tts.setSpeechRate(0.5);
    _tts.setPitch(1.0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ===== 표시 유틸 =====
  String _format(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return "$mm:$ss";
  }

  // ===== 제어 =====
  void _adjustBySwipe(Offset start, Offset end) {
    if (_isRunning || _isLockedAfterConfirm) return; // 실행/확정 후엔 조정 불가

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    const threshold = 40; // 스와이프 민감도

    // 수직 우선 판정(위로 스와이프)
    if (dy < -threshold && dy.abs() > dx.abs()) {
      setState(() {
        _seconds += 600; // +10분
      });
      return;
    }

    // 수평 판정
    if (dx > threshold && dx.abs() > dy.abs()) {
      // 오른쪽: +1분
      setState(() {
        _seconds += 60;
      });
      return;
    }
    if (dx < -threshold && dx.abs() > dy.abs()) {
      // 왼쪽: -1분
      setState(() {
        _seconds = (_seconds - 60).clamp(0, 24 * 60 * 60); // 음수 방지
      });
      return;
    }
  }

  Future<void> _confirmAndStart() async {
    if (_isRunning) return;

    // 더블탭 시 확정 → TTS → 카운트다운 시작
    final minutes = (_seconds / 60).floor();
    _isLockedAfterConfirm = true;
    await _tts.stop();
    await _tts.speak("설정하신 시간은 $minutes 분입니다.");

    // 0이면 바로 종료 안내
    if (_seconds <= 0) {
      await _tts.speak("끝");
      return;
    }

    setState(() => _isRunning = true);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (_seconds <= 0) {
        t.cancel();
        setState(() => _isRunning = false);
        await _tts.stop();
        await _tts.speak("끝");
      } else {
        setState(() => _seconds -= 1);
      }
    });
  }

  // ===== 위젯 =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 배경/색상 등은 상위 테마를 그대로 사용 (UI 변경 최소화)
      body: GestureDetector(
        onPanStart: (d) => _swipeStart = d.localPosition,
        onPanEnd: (d) => _adjustBySwipe(_swipeStart, d.velocity.pixelsPerSecond / 30), // 끝점 유사 처리
        onDoubleTap: _confirmAndStart,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Text(
            _format(_seconds),
            // 폰트 스타일은 기본값 유지(프로젝트 테마 따름)
            style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
