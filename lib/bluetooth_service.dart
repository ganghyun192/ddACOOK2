// ble_service.dart
// HM-10 / BT-05 (CC2541) BLE 전용 서비스
// - FFE0 서비스 / FFE1 캐릭터리스틱 Notify 구독
// - 실시간 온도 스트림 제공 (temperatureStream)
// - write()로 텍스트 전송
// - 끊김 시 소프트 자동 재연결 옵션(기본 on)

import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  // 싱글턴
  static final BleService _i = BleService._internal();
  factory BleService() => _i;
  BleService._internal();

  // HM-10 UART GATT UUID
  static final Guid _svc = Guid("0000ffe0-0000-1000-8000-00805f9b34fb");
  static final Guid _chr = Guid("0000ffe1-0000-1000-8000-00805f9b34fb");

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxChar;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  // 외부 노출 스트림
  final _tempCtrl = StreamController<double>.broadcast();
  final _logCtrl  = StreamController<String>.broadcast();

  // 내부 파서 상태
  String _lineBuffer = '';
  bool _autoReconnect = true;
  bool _reconnecting = false;

  // GETTERS
  Stream<double> get temperatureStream => _tempCtrl.stream;
  Stream<String> get logStream => _logCtrl.stream;
  BluetoothDevice? get device => _device;
  bool get isConnected => _device?.isConnected == true;

  void enableAutoReconnect([bool enable = true]) {
    _autoReconnect = enable;
    _log("♻️ AutoReconnect: ${enable ? 'ON' : 'OFF'}");
  }

  void _log(String m) => _logCtrl.add(m);

  // ====== 연결 & 구독 ======
  Future<void> connectAndSubscribe(BluetoothDevice device) async {
    _device = device;
    _log("🔗 연결 시도: ${device.platformName} (${device.remoteId.str})");

    // 연결 상태 구독 설정
    await _connSub?.cancel();
    _connSub = device.connectionState.listen((s) {
      _log("🔔 상태: $s");
      if (s == BluetoothConnectionState.disconnected && _autoReconnect) {
        _tryReconnect();
      }
    });

    // 실제 연결
    await device.connect(autoConnect: false).catchError((e) {
      _log("❌ 연결 실패: $e");
    });

    if (!isConnected) return;
    _log("✅ 연결됨");

    // MTU 여유 (옵션)
    try { await device.requestMtu(185); } catch (_) {}

    // 서비스/특성 탐색
    await _discoverAndSubscribe();
  }

  Future<void> _discoverAndSubscribe() async {
    final d = _device;
    if (d == null || !isConnected) return;

    _log("🔎 서비스 탐색...");
    final services = await d.discoverServices();

    // FFE0 → FFE1 우선 탐색
    BluetoothCharacteristic? target;
    for (final s in services) {
      if (s.uuid == _svc) {
        for (final c in s.characteristics) {
          if (c.uuid == _chr) { target = c; break; }
        }
      }
    }

    // 백업: 아무 서비스든 'ffe1' 포함 특성
    if (target == null) {
      final ffe1List = services
          .expand((s) => s.characteristics)
          .where((c) => c.uuid.toString().toLowerCase().contains('ffe1'))
          .toList();

      if (ffe1List.isNotEmpty) {
        target = ffe1List.first;
      }
    }


    _rxChar = target;
    _log("📨 수신 캐릭터리스틱: ${_rxChar!.uuid}");

    // Notify 활성화
    try { await _rxChar!.setNotifyValue(true); } catch (e) { _log("⚠️ notify 실패: $e"); }

    // 일부 펌웨어는 CCCD(0x2902) 직접 설정 필요
    try {
      final cccd = _rxChar!.descriptors
          .where((d) => d.uuid.toString().toLowerCase().endsWith("2902"))
          .toList();
      if (cccd.isNotEmpty) {
        await cccd.first.write([0x01, 0x00]); // Notification enable
        _log("✅ CCCD 0x2902 설정 완료");
      }
    } catch (e) {
      _log("⚠️ CCCD 설정 실패: $e");
    }

    // 이전 구독 해제 후 재구독
    await _notifySub?.cancel();
    _notifySub = _rxChar!.onValueReceived.listen(_onData);

    // 초기 read(옵션)
    try {
      final init = await _rxChar!.read();
      if (init.isNotEmpty) _onData(init);
    } catch (_) {}
  }

  // ====== 데이터 파싱 ======
  void _onData(List<int> data) {
    _log("RAW(${data.length}): ${data.map((b)=>b.toRadixString(16).padLeft(2,'0')).join(' ')}");

    // 1) 제어문자/ASCII 필터
    final filtered = data.where((b) =>
    b == 9 || b == 10 || b == 13 || (b >= 32 && b <= 126)).toList();

    // 2) 유니코드 디코드 (깨진 바이트 허용)
    final chunk = utf8.decode(filtered, allowMalformed: true);

    // 3) 라인 버퍼링
    _lineBuffer += chunk;
    final lines = _lineBuffer.split(RegExp(r'[\r\n]+'));
    _lineBuffer = lines.removeLast();

    // 4) 각 라인 처리
    for (final line in lines) {
      final text = line.trim();
      if (text.isEmpty) continue;

      _log("📥 RX: $text");

      // 숫자만 추출 (예: "25.1", "T=25.1C" 등)
      final m = RegExp(r'[-+]?\d*\.?\d+').firstMatch(text);
      if (m != null) {
        final v = double.tryParse(m.group(0)!);
        if (v != null) _tempCtrl.add(v);
      }
    }
  }

  // ====== 송신 ======
  Future<void> write(String text) async {
    if (_rxChar == null) {
      _log("⚠️ write 실패: 특성 없음");
      return;
    }
    final payload = utf8.encode(text);
    try {
      await _rxChar!.write(payload, withoutResponse: true);
      _log("📤 TX: $text");
    } catch (e) {
      _log("❌ write 에러: $e");
    }
  }

  // ====== 재연결 루틴 ======
  Future<void> _tryReconnect() async {
    if (_reconnecting || !_autoReconnect) return;
    final d = _device;
    if (d == null) return;

    _reconnecting = true;
    _log("⏳ 재연결 시도...");
    try {
      await Future.delayed(const Duration(milliseconds: 600));
      await d.connect(autoConnect: true).timeout(const Duration(seconds: 5));
      if (isConnected) {
        _log("✅ 재연결 성공");
        await _discoverAndSubscribe();
      } else {
        _log("⚠️ 재연결 실패(미확인)");
      }
    } catch (e) {
      _log("❌ 재연결 에러: $e");
    } finally {
      _reconnecting = false;
    }
  }

  // ====== 해제 ======
  Future<void> disconnect() async {
    await _notifySub?.cancel();
    await _connSub?.cancel();
    try { await _device?.disconnect(); } catch (_) {}
    _device = null;
    _rxChar = null;
    _log("🔌 연결 해제");
  }

  void dispose() {
    _notifySub?.cancel();
    _connSub?.cancel();
    _tempCtrl.close();
    _logCtrl.close();
  }
}
