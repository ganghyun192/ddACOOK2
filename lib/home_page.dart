import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'thermometer_page.dart';
import 'timer_page.dart';
import 'recipe_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Offset _panStart = Offset.zero;
  bool _isNavigating = false;

  // 스와이프 판정 임계값 (픽셀)
  static const double kMinSwipeDist = 60; // 너무 크면 안 먹히고, 너무 작으면 오작동

  void _navigateTo(Widget page, Offset beginOffset) {
    if (_isNavigating) return;
    _isNavigating = true;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
    ).then((_) => _isNavigating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue, // ✅ 기존 파란 배경 유지
      body: GestureDetector(
        behavior: HitTestBehavior.opaque, // ✅ 빈 영역도 제스처 인식
        onPanStart: (details) {
          _panStart = details.localPosition;
        },
        onPanUpdate: (details) {
          // 거리 기반 스와이프 판정: 시작점 대비 현재 위치
          final delta = details.localPosition - _panStart;
          final dx = delta.dx;
          final dy = delta.dy;

          // 이미 이동했으면 무시
          if (_isNavigating) return;

          // 수평/수직 중 더 큰 축을 스와이프로 판단
          if (dx.abs() > dy.abs()) {
            // 좌/우 스와이프
            if (dx >= kMinSwipeDist) {
              // ➡ 오른쪽: 온도계
              _navigateTo(const ThermometerPage(), const Offset(-1, 0));
            } else if (dx <= -kMinSwipeDist) {
              // ⬅ 왼쪽: 타이머
              _navigateTo(const TimerPage(), const Offset(1, 0));
            }
          } else {
            // 상/하 스와이프
            if (dy <= -kMinSwipeDist) {
              // ⬆ 위: 레시피
              _navigateTo(const RecipePage(), const Offset(0, 1));
            } else if (dy >= kMinSwipeDist) {
              // ⬇ 아래: 종료
              SystemNavigator.pop();
            }
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: const [
            // ✅ 중앙의 “홈” 텍스트 (흰색, 굵게)
            Center(
              child: Text(
                '홈',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
