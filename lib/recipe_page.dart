import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:wakelock_plus/wakelock_plus.dart';

import 'timer_page.dart';
import 'thermometer_page.dart';

enum RecipeUiState { waitingSpeech, confirming, preview, running, done }

class RecipePage extends StatefulWidget {
  const RecipePage({super.key});

  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage> {
  RecipeUiState state = RecipeUiState.waitingSpeech;

  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();

  String recognized = '';
  _Recipe? _recipe;
  bool _isListening = false;
  bool _sttAvailable = false;

  int _currentSentence = 0;

  @override
  void initState() {
    super.initState();
    _initTts();
    _initStt();
    WakelockPlus.enable(); // ✅ 화면 꺼짐 방지
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("ko-KR");
    await _tts.setSpeechRate(0.5);
    await _speak("레시피를 말씀하세요. 화면을 탭해 시작하세요.");
  }

  Future<void> _initStt() async {
    _sttAvailable = await _stt.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          setState(() => _isListening = false);
          if (recognized.isNotEmpty && state == RecipeUiState.waitingSpeech) {
            state = RecipeUiState.confirming;
            _speak("검색 결과. $recognized. 맞습니까? 맞으면 탭, 아니면 두 번 탭하세요.");
          }
        }
      },
      onError: (e) {
        setState(() => _isListening = false);
        _speak("음성 인식 오류. 다시 탭해서 시도하세요.");
      },
    );
    setState(() {});
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _startListening() async {
    if (!_sttAvailable || _isListening) return;
    setState(() {
      _isListening = true;
      recognized = '';
    });

    await _stt.listen(
      localeId: 'ko_KR',
      listenMode: stt.ListenMode.search,
      partialResults: true,
      onResult: (res) {
        setState(() => recognized = res.recognizedWords.trim());
      },
    );
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;
    await _stt.stop();
    setState(() => _isListening = false);
  }

  // ✅ 제스처 핸들링
  void _handleTap() {
    switch (state) {
      case RecipeUiState.waitingSpeech:
        if (_isListening) {
          _stopListening();
        } else {
          _startListening();
        }
        break;
      case RecipeUiState.confirming:
        _acceptCandidate();
        break;
      case RecipeUiState.preview:
        _startRecipe();
        break;
      case RecipeUiState.running:
        _nextSentence();
        break;
      case RecipeUiState.done:
        Navigator.pop(context);
        break;
    }
  }

  void _handleDoubleTap() {
    if (state == RecipeUiState.confirming) {
      setState(() => state = RecipeUiState.waitingSpeech);
      _speak("다시 말씀하세요.");
    } else if (state == RecipeUiState.running) {
      _repeatSentence();
    }
  }

  // ✅ 후보 수락
  void _acceptCandidate() {
    _recipe = _findRecipe(recognized);
    if (_recipe == null) {
      _speak("해당 레시피를 찾을 수 없습니다. 다시 말씀하세요.");
      setState(() => state = RecipeUiState.waitingSpeech);
    } else {
      setState(() => state = RecipeUiState.preview);
      _speak("${_recipe!.title}. 화면을 탭하면 시작합니다.");
    }
  }

  // ✅ 실행 시작
  void _startRecipe() {
    setState(() {
      state = RecipeUiState.running;
      _currentSentence = 0;
    });
    _processSentence();
  }

  Future<void> _processSentence() async {
    if (_recipe == null) return;
    final current = _recipe!.sentences[_currentSentence];

    // 온도계 호출
    if (current.targetTempC != null) {
      await _speak("목표 온도 ${current.targetTempC}도까지 기다리세요.");
      final ok = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ThermometerPage(target: current.targetTempC!),
        ),
      );
      if (ok == true) {
        await _speak("목표 온도에 도달했습니다. 이어서 진행합니다.");
      }
    }

    // 타이머 호출
    if (current.timerMinutes != null) {
      await _speak("${current.timerMinutes}분 타이머를 시작합니다.");
      final ok = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TimerPage(preset: current.timerMinutes!),
        ),
      );
      if (ok == true) {
        await _speak("타이머가 끝났습니다. 이어서 진행합니다.");
      }
    }

    // 일반 문장 읽기
    await _speak(current.text);
  }

  void _nextSentence() {
    if (_recipe == null) return;
    if (_currentSentence < _recipe!.sentences.length - 1) {
      setState(() => _currentSentence++);
      _processSentence();
    } else {
      setState(() => state = RecipeUiState.done);
      _speak("레시피가 완료되었습니다. 화면을 탭하면 홈으로 돌아갑니다.");
    }
  }

  void _repeatSentence() {
    if (_recipe == null) return;
    _speak(_recipe!.sentences[_currentSentence].text);
  }

  // ✅ 더미 레시피 매칭
  _Recipe? _findRecipe(String keyword) {
    keyword = keyword.replaceAll(" ", "");
    if (keyword.contains("알리오올리오")) return _aglio;
    if (keyword.contains("계란") || keyword.contains("삶기")) return _egg;
    return null;
  }

  @override
  void dispose() {
    _tts.stop();
    _stt.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      onDoubleTap: _handleDoubleTap,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("Recipe"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (state) {
      case RecipeUiState.waitingSpeech:
        return _centerText("레시피를 말씀하세요\n\n${_isListening ? "듣는 중…" : "탭하여 시작"}");
      case RecipeUiState.confirming:
        return _centerText("검색 결과: $recognized\n\n탭: 맞음 / 더블탭: 다시 말하기");
      case RecipeUiState.preview:
        return _centerText("${_recipe?.title}\n\n탭하면 시작합니다.");
      case RecipeUiState.running:
        return _sentenceList();
      case RecipeUiState.done:
        return _centerText("레시피 완료!\n\n탭하면 홈으로 이동");
    }
  }

  Widget _centerText(String text) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _sentenceList() {
    if (_recipe == null) return const SizedBox();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recipe!.sentences.length,
      itemBuilder: (_, i) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            _recipe!.sentences[i].text,
            style: TextStyle(
              fontSize: 22,
              color: i == _currentSentence ? Colors.blue : Colors.black,
              fontWeight: i == _currentSentence ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      },
    );
  }
}

/* ----------------- 모델 ----------------- */

class Sentence {
  final String text;
  final int? timerMinutes;
  final double? targetTempC;

  Sentence(this.text, {this.timerMinutes, this.targetTempC});
}

class _Recipe {
  final String title;
  final List<Sentence> sentences;
  _Recipe({required this.title, required this.sentences});
}

/* ----------------- 더미 레시피 ----------------- */

final _aglio = _Recipe(
  title: "알리오 올리오 파스타",
  sentences: [
    Sentence("냄비에 물을 넣습니다."),
    Sentence("물이 끓을 때까지 기다립니다.", targetTempC: 100), // ✅ 온도계 호출
    Sentence("끓는 물에 스파게티 면을 넣습니다."),
    Sentence("면을 7분 동안 삶습니다.", timerMinutes: 7), // ✅ 타이머 호출
    Sentence("면을 건져내고 올리브유, 마늘, 페퍼론치노와 함께 볶습니다."),
    Sentence("소금으로 간을 하고 접시에 담습니다."),
  ],
);

final _egg = _Recipe(
  title: "계란 삶기",
  sentences: [
    Sentence("냄비에 물을 넣습니다."),
    Sentence("물이 끓으면 계란을 넣습니다."),
    Sentence("약 10분간 삶습니다.", timerMinutes: 10), // ✅ 타이머 호출
    Sentence("찬물에 담가 식힙니다."),
    Sentence("껍질을 까고 접시에 담습니다."),
  ],
);
