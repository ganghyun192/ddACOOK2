// thermometer_page.dart
// ⚠️ UI 구조/배치 변경 없이, BLE 온도 스트림(FFE1 notify)만 붙인 전체본

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'bluetooth_service.dart';

class ThermometerPage extends StatefulWidget {
  const ThermometerPage({super.key});

  @override
  State<ThermometerPage> createState() => _ThermometerPageState();
}

class _ThermometerPageState extends State<ThermometerPage> {
  // ====== TTS & BLE ======
  final FlutterTts _tts = FlutterTts();
  StreamSubscription<double>? _tempSub;

  // ====== 상태값 ======
  double _currentTemperature = 0.0;   // 실시간 현재 온도
  double _targetTemperature  = 50.0;  // 목표 온도
  bool _isTemperatureSet     = false; // 더블탭으로 설정 완료 여부
  bool _hasAnnouncedArrival  = false; // 목표 도달 1회 안내 플래그

  // 스와이프 판정용
  Offset _swipeStart = Offset.zero;

  @override
  void initState() {
    super.initState();

    // ★ BLE 온도 스트림 구독 (UI 변경 없음)
    _tempSub = BleService().temperatureStream.listen((v) {
      setState(() => _currentTemperature = v);
      if (_isTemperatureSet && !_hasAnnouncedArrival && _currentTemperature >= _targetTemperature) {
        _hasAnnouncedArrival = true;
        _tts.speak("목표 온도에 도달했습니다.");
      }
    });

    // TTS 기본 안내
    _tts.setLanguage("ko-KR");
    _tts.setSpeechRate(0.5);
    _tts.setPitch(1.0);
    _tts.speak("온도를 설정해주세요.");
  }

  @override
  void dispose() {
    _tempSub?.cancel(); // ★ 통합: 구독 해제
    super.dispose();
  }

  // ====== 스와이프 처리 ======
  void _handleSwipe(Offset start, Offset end) {
    if (_isTemperatureSet) return; // 설정 완료 후엔 변경 불가 (원래 의도 유지)

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    const threshold = 40;

    // 위 스와이프: +10도
    if (dy < -threshold && dy.abs() > dx.abs()) {
      setState(() {
        _targetTemperature = (_targetTemperature + 10).clamp(0, 200);
      });
      return;
    }
    // 오른쪽 스와이프: +5도
    if (dx > threshold && dx.abs() > dy.abs()) {
      setState(() {
        _targetTemperature = (_targetTemperature + 5).clamp(0, 200);
      });
      return;
    }
    // 왼쪽 스와이프: -5도
    if (dx < -threshold && dx.abs() > dy.abs()) {
      setState(() {
        _targetTemperature = (_targetTemperature - 5).clamp(0, 200);
      });
      return;
    }
    // 아래 스와이프: 홈으로 이동 (UI는 그대로, 동작만 유지)
    if (dy > threshold && dy.abs() > dx.abs()) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }
  }

  // ====== 더블탭(설정 확정) ======
  Future<void> _confirmTarget() async {
    if (_isTemperatureSet) return;
    setState(() {
      _isTemperatureSet = true;
      _hasAnnouncedArrival = false;
    });
    await _tts.stop();
    await _tts.speak("설정하신 온도는 $_targetTemperature 도 입니다.");
  }

  // ====== 위젯 (UI 배치는 기존 구조 유지) ======
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue, // 기존 테마 유지
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _swipeStart = d.localPosition,
        onPanEnd: (d) {
          // 끝점 근사치: 속도를 이용해 방향 추정
          final end = _swipeStart + d.velocity.pixelsPerSecond / 30;
          _handleSwipe(_swipeStart, end);
        },
        onDoubleTap: _confirmTarget,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 현재 온도 표시 (실시간)
              Text(
                '${_currentTemperature.toStringAsFixed(1)} °C',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // 설정 온도 표시
              const Text(
                '설정 온도',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
              Text(
                '$_targetTemperature °C',
                style: const TextStyle(color: Colors.white, fontSize: 36),
              ),
              if (_isTemperatureSet)
                const Padding(
                  padding: EdgeInsets.only(top: 12.0),
                  child: Text(
                    '설정 완료됨',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              // (필요 시 안내 문구가 있었더라도 UI 변경 없이 유지)
            ],
          ),
        ),
      ),
    );
  }
}
