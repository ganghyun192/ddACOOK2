// home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 시스템 종료용
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';
import 'timer_page.dart';
import 'thermometer_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _speak('홈 화면입니다. 오른쪽으로 스와이프하면 온도계, 왼쪽으로 스와이프하면 타이머입니다. 아래로 스와이프하면 앱이 종료됩니다.');
  }

  Future<void> _speak(String text) async {
    await flutterTts.setLanguage("ko-KR");
    await flutterTts.setPitch(1.0); // 0.8~1.2 범위 추천
    await flutterTts.setSpeechRate(0.5); // 0.3~0.5 권장
    await flutterTts.awaitSpeakCompletion(true);
    await flutterTts.speak(text);
  }

  void _exitApp() {
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else if (Platform.isIOS) {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ThermometerPage()),
          );
        } else if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TimerPage()),
          );
        }
      },
      onVerticalDragEnd: (details) async {
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          await _speak('앱을 종료합니다.');
          Future.delayed(const Duration(seconds: 1), () {
            _exitApp();
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'ddacook',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 30),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.arrow_upward, size: 40, color: Colors.blue),
                  const Icon(Icons.arrow_upward, size: 40, color: Colors.blue),
                  const Icon(Icons.arrow_upward, size: 40, color: Colors.blue),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.arrow_back, size: 40, color: Colors.blue),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_back, size: 40, color: Colors.blue),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_back, size: 40, color: Colors.blue),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward, size: 40, color: Colors.blue),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward, size: 40, color: Colors.blue),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward, size: 40, color: Colors.blue),
                    ],
                  ),
                  const Icon(Icons.arrow_downward, size: 40, color: Colors.blue),
                  const Icon(Icons.arrow_downward, size: 40, color: Colors.blue),
                  const Icon(Icons.arrow_downward, size: 40, color: Colors.blue),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
