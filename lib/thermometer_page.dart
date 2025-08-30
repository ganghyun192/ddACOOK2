import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'bluetooth_service.dart';

class ThermometerPage extends StatefulWidget {
  const ThermometerPage({super.key, this.target}); // 레시피에서 넘겨줄 목표 온도
  final double? target;

  @override
  State<ThermometerPage> createState() => _ThermometerPageState();
}

class _ThermometerPageState extends State<ThermometerPage> {
  final FlutterTts _tts = FlutterTts();

  double _targetC = 50.0;   // 목표 온도(스와이프로 조절)
  double _currentC = 25.0;  // 현재 온도(BLE 수신으로 갱신)
  StreamSubscription<double>? _tempSub; // ✅ BleService temperatureStream 구독

  bool _autoReturnOnReached = false;

  // ── 스와이프 인식용 ──
  Offset _panStart = Offset.zero;
  bool _gestureConsumed = false;
  static const double kMinSwipeDist = 60; // 거리 기반 임계값

  @override
  void initState() {
    super.initState();
    _initTts();

    if (widget.target != null) {
      _targetC = widget.target!;
      _autoReturnOnReached = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _announce("목표 온도 섭씨 ${_targetC.toStringAsFixed(0)}도 입니다. 도달하면 자동으로 돌아갑니다.");
      });
    }

    // ✅ BLE 실시간 온도 수신 연결
    _tempSub = BleService().temperatureStream.listen((v) {
      setState(() => _currentC = v);
      _maybeAutoReturn(); // 목표 도달 체크
    });

    // 데모 테스트 필요 시 임시 온도 상승 시뮬(원하면 주석 해제)
    // _mockWarmUp();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _announce(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  // 더미: 온도 상승 시뮬 (테스트용)
  Timer? _mockTimer;
  void _mockWarmUp() {
    _mockTimer?.cancel();
    _mockTimer = Timer.periodic(const Duration(milliseconds: 800), (t) {
      setState(() => _currentC += 2.5);
      _maybeAutoReturn();
      if (_currentC >= _targetC + 5) {
        t.cancel();
      }
    });
  }

  void _maybeAutoReturn() async {
    if (_autoReturnOnReached && _currentC >= _targetC && mounted) {
      await _announce("목표온도도달");
      if (!mounted) return;
      Navigator.pop(context, true); // 레시피로 “도달” 신호
    }
  }

  // ── 스와이프 제스처: 위 +10, 오른쪽 +5, 왼쪽 -5, 아래 뒤로가기 ──
  void _onPanStart(DragStartDetails d) {
    _panStart = d.localPosition;
    _gestureConsumed = false;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_gestureConsumed) return;

    final delta = d.localPosition - _panStart;
    final dx = delta.dx;
    final dy = delta.dy;

    if (dx.abs() < kMinSwipeDist && dy.abs() < kMinSwipeDist) return;

    if (dx.abs() > dy.abs()) {
      // 수평: 오른쪽/왼쪽
      if (dx > 0) {
        _bumpTarget(5);
      } else {
        _bumpTarget(-5);
      }
    } else {
      // 수직: 위/아래
      if (dy < 0) {
        _bumpTarget(10);
      } else {
        // 아래로: 뒤로가기(레시피에서 온 경우 결과 false로 반환)
        Navigator.pop(context, false);
      }
    }
    _gestureConsumed = true;
  }

  void _onPanEnd(DragEndDetails d) {
    _gestureConsumed = false;
  }

  void _bumpTarget(int delta) {
    double next = (_targetC + delta).clamp(0, 200).toDouble();
    setState(() => _targetC = next);
    _announce("목표 온도 ${_targetC.toStringAsFixed(0)}도");
    _maybeAutoReturn();
  }

  @override
  void dispose() {
    _tempSub?.cancel();
    _mockTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ UI는 기존 레이아웃 유지 (텍스트만 표시)
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Thermometer'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onDoubleTap: () {
          _announce("현재 온도 ${_currentC.toStringAsFixed(1)}도. 목표 ${_targetC.toStringAsFixed(0)}도.");
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${_currentC.toStringAsFixed(1)} ℃",
                style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "목표: ${_targetC.toStringAsFixed(0)} ℃",
                style: TextStyle(fontSize: 18, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              const Text("위: +10°, 오른쪽: +5°, 왼쪽: -5°, 아래: 뒤로"),
            ],
          ),
        ),
      ),
    );
  }
}
