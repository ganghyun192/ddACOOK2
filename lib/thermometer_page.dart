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
  final FlutterTts _tts = FlutterTts();
  double _currentTemperature = 0;
  int _targetTemperature = 30;
  bool _isTemperatureSet = false;
  bool _hasAnnounced = false;
  double? _lastTemperature;
  StreamSubscription<String>? _btSubscription;

  Offset _swipeStart = Offset.zero;
  Offset _swipeEnd = Offset.zero;

  @override
  void initState() {
    super.initState();
    _listenToBluetooth();
    debugPrint('🌡️ ThermometerPage 초기화됨');
    _tts.speak("온도를 설정해주세요");
  }

  void _listenToBluetooth() {
    _btSubscription = BluetoothService().onDataReceived.listen((data) {
      data = data.trim();
      final parsed = double.tryParse(data);

      if (parsed != null && parsed != _lastTemperature && parsed != 85.0) {
        setState(() {
          _currentTemperature = parsed;
          _lastTemperature = parsed;
        });

        if (_isTemperatureSet &&
            _currentTemperature >= _targetTemperature &&
            !_hasAnnounced) {
          _tts.speak("설정 온도에 도달했습니다");
          _hasAnnounced = true;
        }
      }
    });
  }

  void _handleSwipe() {
    if (_isTemperatureSet) return;

    final dx = _swipeEnd.dx - _swipeStart.dx;
    final dy = _swipeEnd.dy - _swipeStart.dy;

    setState(() {
      if (dx > 50) {
        _targetTemperature += 5;
      } else if (dx < -50) {
        _targetTemperature -= 5;
      } else if (dy < -50) {
        _targetTemperature += 10;
      } else if (dy > 50) {
        Navigator.pop(context);
        return;
      }

      if (_targetTemperature > 200) _targetTemperature = 200;
      if (_targetTemperature < 0) _targetTemperature = 0;
    });
  }

  void _handleDoubleTap() async {
    if (_isTemperatureSet) return;

    setState(() {
      _isTemperatureSet = true;
    });

    if (!BluetoothService().isConnected) {
      final success = await BluetoothService().connectWithSavedAddress();
      if (!success) {
        _tts.speak("블루투스 연결에 실패했습니다");
        return;
      }
    }

    _tts.speak("설정하신 온도는 $_targetTemperature 도입니다");
  }

  @override
  void dispose() {
    _btSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onPanStart: (details) => _swipeStart = details.localPosition,
        onPanUpdate: (details) => _swipeEnd = details.localPosition,
        onPanEnd: (_) => _handleSwipe(),
        onDoubleTap: _handleDoubleTap,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '현재 온도',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
              Text(
                '${_currentTemperature.toStringAsFixed(1)} °C',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
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
            ],
          ),
        ),
      ),
    );
  }
}
