// bluetooth_page.dart
// HM-10/BT-05(BLE) 스캔 → (이전 연결 장치 자동 연결) → 수동 선택 → 연결 후 홈 이동
// ※ 파일/클래스 이름 그대로 사용

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bluetooth_service.dart';
import 'home_page.dart';

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  static const _prefKeyLastId = 'last_ble_remote_id';
  static const _prefKeyLastName = 'last_ble_name';

  bool _scanning = false;
  bool _autoConnecting = false;
  final List<ScanResult> _results = [];
  StreamSubscription<List<ScanResult>>? _scanSub;

  String? _lastId;
  String? _lastName;
  int _scanRetry = 0;

  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _ensurePermissions();
    await _loadLastDevice();
    await _startScan();
  }

  Future<void> _ensurePermissions() async {
    final req = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    if (req.values.any((s) => s.isDenied || s.isPermanentlyDenied)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('블루투스/위치 권한이 필요합니다. 설정에서 허용해주세요.')),
      );
    }
  }

  Future<void> _loadLastDevice() async {
    final sp = await SharedPreferences.getInstance();
    _lastId = sp.getString(_prefKeyLastId);
    _lastName = sp.getString(_prefKeyLastName);
  }

  Future<void> _saveLastDevice(BluetoothDevice d) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_prefKeyLastId, d.remoteId.str);
    await sp.setString(_prefKeyLastName, d.platformName);
  }

  bool _isHm10FamilyName(String name) {
    final up = name.toUpperCase();
    return up.contains('HM') || up.contains('BT');
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _autoConnecting = false;
    });
    _results.clear();
    await FlutterBluePlus.stopScan();

    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((list) async {
      bool triedAuto = false;

      for (final r in list) {
        final name = r.device.platformName;
        if (name.isEmpty) continue;
        if (!_isHm10FamilyName(name)) continue;

        final idx = _results.indexWhere((e) => e.device.remoteId == r.device.remoteId);
        if (idx < 0) _results.add(r);

        if (!_autoConnecting && !_isNavigating && (_lastId != null || _lastName != null)) {
          final matchById = _lastId != null && r.device.remoteId.str == _lastId;
          final matchByName = _lastId == null && _lastName != null && name == _lastName;

          if (matchById || matchByName) {
            _autoConnecting = true;
            triedAuto = true;
            setState(() {});
            await _connect(r, fromAuto: true);
            break;
          }
        }
      }

      if (!triedAuto) setState(() {});
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));
    if (!mounted) return;
    setState(() => _scanning = false);

    if (_results.isEmpty && (_lastId != null || _lastName != null) && _scanRetry < 2) {
      _scanRetry++;
      await Future.delayed(const Duration(seconds: 1));
      await _startScan();
    } else {
      _scanRetry = 0;
    }
  }

  Future<void> _connect(ScanResult r, {bool fromAuto = false}) async {
    await BleService().connectAndSubscribe(r.device);

    if (!mounted) return;
    if (BleService().isConnected) {
      await _saveLastDevice(r.device);

      if (_isNavigating) return;
      _isNavigating = true;

      if (!fromAuto) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('연결됨: ${r.device.platformName}')),
        );
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      ).then((_) => _isNavigating = false);
    } else {
      _autoConnecting = false;
      if (!fromAuto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('연결 실패: 장치를 다시 선택해 주세요.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final empty = _results.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE 장치 선택 (HM/BT)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanning ? null : _startScan,
            tooltip: '다시 스캔',
          ),
        ],
      ),
      body: empty
          ? Center(child: Text(_scanning ? '스캔 중...' : '장치가 없습니다'))
          : ListView.separated(
        itemCount: _results.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final r = _results[i];
          return ListTile(
            title: Text(r.device.platformName),
            subtitle: Text(r.device.remoteId.str),
            trailing: ElevatedButton(
              onPressed: () => _connect(r),
              child: const Text('연결'),
            ),
          );
        },
      ),
      bottomNavigationBar: _FooterStatus(
        scanning: _scanning,
        count: _results.length,
        lastName: _lastName,
        autoConnecting: _autoConnecting,
      ),
    );
  }
}

class _FooterStatus extends StatelessWidget {
  final bool scanning;
  final int count;
  final String? lastName;
  final bool autoConnecting;

  const _FooterStatus({
    required this.scanning,
    required this.count,
    required this.lastName,
    required this.autoConnecting,
  });

  @override
  Widget build(BuildContext context) {
    final text = scanning
        ? '스캔 중…'
        : autoConnecting
        ? '이전 장치 자동 연결 시도 중${lastName != null ? " ($lastName)" : ""}…'
        : '발견된 장치: $count';

    return SafeArea(
      child: Container(
        height: 44,
        alignment: Alignment.center,
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
