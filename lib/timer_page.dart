import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({super.key, this.preset}); // ✅ 레시피에서 넘겨줄 분 단위
  final int? preset;

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  final FlutterTts _tts = FlutterTts();

  // 내부 상태
  int _totalSeconds = 10 * 60; // 기본 10분 (UI 변화 없음)
  int _remainSeconds = 10 * 60;
  Timer? _ticker;
  bool _running = false;

  // 레시피에서 preset으로 들어오면 자동 시작 + 완료 시 자동 복귀
  bool _autoReturnOnFinish = false;

  // 제스처 민감도(네 기존 제스처를 그대로 유지하려면 임계값만 조절)
  Offset _swipeStart = Offset.zero;

  @override
  void initState() {
    super.initState();
    _initTts();

    // ✅ preset 적용: 분 → 초
    if (widget.preset != null) {
      _totalSeconds = widget.preset! * 60;
      _remainSeconds = _totalSeconds;
      _autoReturnOnFinish = true;

      // 프레임 이후 자동 시작
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _announce("타이머 ${widget.preset}분을 시작합니다.");
        _start();
      });
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _announce(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  void _start() {
    if (_running) return;
    setState(() => _running = true);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainSeconds <= 1) {
        t.cancel();
        setState(() {
          _remainSeconds = 0;
          _running = false;
        });
        _onFinished();
      } else {
        setState(() => _remainSeconds--);
      }
    });
  }

  void _pause() {
    if (!_running) return;
    _ticker?.cancel();
    setState(() => _running = false);
  }

  void _resetTo(int minutes) {
    final s = minutes.clamp(0, 600) * 60; // 최대 600분 제한(안전)
    setState(() {
      _totalSeconds = s;
      _remainSeconds = s;
      _running = false;
    });
    _ticker?.cancel();
  }

  Future<void> _onFinished() async {
    await _announce("타이머가 끝났습니다.");

    if (_autoReturnOnFinish && mounted) {
      Navigator.pop(context, true); // ✅ 레시피로 완료 신호 전달
      return;
    }
    // 자동 복귀가 아닌 경우, 기존 UI 흐름 그대로 유지(여기서 아무 것도 안 함)
  }

  String _format(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  // == 제스처 ==
  void _onPanStart(DragStartDetails d) {
    _swipeStart = d.localPosition;
  }

  void _onPanEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    final dx = v.dx;
    final dy = v.dy;

    // 위: +10분, 오른쪽: +1분, 왼쪽: -1분 (네가 쓰던 규칙 유지)
    if (dy < -300 && dy.abs() > dx.abs()) {
      _resetTo((_totalSeconds ~/ 60) + 10);
      _announce("10분 증가. 현재 설정 ${_totalSeconds ~/ 60}분");
      return;
    }
    if (dx > 300 && dx.abs() > dy.abs()) {
      _resetTo((_totalSeconds ~/ 60) + 1);
      _announce("1분 증가. 현재 설정 ${_totalSeconds ~/ 60}분");
      return;
    }
    if (dx < -300 && dx.abs() > dy.abs()) {
      _resetTo((_totalSeconds ~/ 60) - 1);
      _announce("1분 감소. 현재 설정 ${_totalSeconds ~/ 60}분");
      return;
    }
    // 아래 스와이프 등은 기존 로직이 있으면 그대로 두세요.
  }

  // 더블탭: 시작/일시정지 토글 (네 기존 동작과 동일하게)
  void _onDoubleTap() {
    if (_running) {
      _pause();
      _announce("타이머 일시정지");
    } else {
      if (_remainSeconds == 0) {
        _resetTo(_totalSeconds ~/ 60);
      }
      _start();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ 여기 UI 구조는 건드리지 않고, 텍스트/숫자만 기존처럼 표시합니다.
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Timer'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: GestureDetector(
        onPanStart: _onPanStart,
        onPanEnd: _onPanEnd,
        onDoubleTap: _onDoubleTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _format(_remainSeconds),
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _running ? '진행 중' : '대기 중',
                style: TextStyle(
                  fontSize: 16,
                  color: _running ? Colors.green : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              const Text('위: +10분, 오른쪽: +1분, 왼쪽: -1분 / 더블탭: 시작·일시정지'),
            ],
          ),
        ),
      ),
    );
  }
}
