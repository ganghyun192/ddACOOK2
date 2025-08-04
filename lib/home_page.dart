import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'thermometer_page.dart';
import 'timer_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Offset _swipeStart = Offset.zero;
  Offset _swipeEnd = Offset.zero;
  bool _isNavigating = false;

  void _navigateTo(Widget page, Offset beginOffset) {
    if (_isNavigating) return;
    _isNavigating = true;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: beginOffset, end: Offset.zero)
              .animate(anim),
          child: child,
        ),
      ),
    ).then((_) => _isNavigating = false);
  }

  void _exitApp() {
    Future.delayed(const Duration(milliseconds: 200), () {
      SystemNavigator.pop();
    });
  }

  void _handleSwipe() {
    final dx = _swipeEnd.dx - _swipeStart.dx;
    final dy = _swipeEnd.dy - _swipeStart.dy;

    if (dx > 50 && !_isNavigating) {
      // ➡ 오른쪽 → 온도계
      _navigateTo(const ThermometerPage(), const Offset(-1, 0));
    } else if (dx < -50 && !_isNavigating) {
      // ⬅ 왼쪽 → 타이머
      _navigateTo(const TimerPage(), const Offset(1, 0));
    } else if (dy > 50) {
      // ⬇ 아래 → 앱 종료
      _exitApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: GestureDetector(
        onPanStart: (details) {
          _swipeStart = details.localPosition;
        },
        onPanUpdate: (details) {
          _swipeEnd = details.localPosition;
        },
        onPanEnd: (_) {
          _handleSwipe();
        },
        child: const Center(
          child: Text(
            '홈',
            style: TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
