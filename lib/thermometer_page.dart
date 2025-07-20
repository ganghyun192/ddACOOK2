// thermometer_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ThermometerPage extends StatefulWidget {
  const ThermometerPage({super.key});

  @override
  State<ThermometerPage> createState() => _ThermometerPageState();
}

class _ThermometerPageState extends State<ThermometerPage> {
  int _currentTemperature = 0;
  final int _targetTemperature = 100;
  bool _isConfirmed = false;
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _speak('온도 설정 화면입니다. 오른쪽으로 스와이프하면 5도 증가, 왼쪽은 5도 감소, 위로는 10도 증가입니다. 설정을 마치려면 화면을 두 번 터치해주세요.');
  }

  Future<void> _speak(String text) async {
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.speak(text);
  }

  void _adjustTemperature(int delta) {
    if (_isConfirmed) return;
    setState(() {
      _currentTemperature = (_currentTemperature + delta).clamp(0, _targetTemperature);
    });
  }

  void _onDoubleTap() {
    if (_currentTemperature > 0) {
      setState(() {
        _isConfirmed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('온도 설정 완료')),
      );
      _speak('온도 설정이 완료되었습니다. 현재 설정된 온도는 $_currentTemperature 도 입니다.');
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          Navigator.pop(context);
        } else if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
          _adjustTemperature(10);
        }
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          _adjustTemperature(5);
        } else if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
          _adjustTemperature(-5);
        }
      },
      onDoubleTap: _onDoubleTap,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            '$_currentTemperature°C',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
