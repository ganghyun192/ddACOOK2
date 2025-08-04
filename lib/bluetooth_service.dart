import 'dart:async';
import 'dart:convert';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  BluetoothConnection? _connection;
  final StreamController<String> _dataController = StreamController.broadcast();
  String? _savedAddress;

  bool get isConnected => _connection != null && _connection!.isConnected;

  void setAddress(String address) {
    _savedAddress = address;
  }

  // ✅ 외부에서 주소를 직접 받아 연결
  Future<bool> connect(String deviceAddress) async {
    setAddress(deviceAddress);
    return await connectWithSavedAddress();
  }

  // ✅ 저장된 주소로 연결 시도
  Future<bool> connectWithSavedAddress() async {
    if (_savedAddress == null) {
      print('❌ 저장된 MAC 주소가 없습니다.');
      return false;
    }

    try {
      _connection = await BluetoothConnection.toAddress(_savedAddress);
      print('✅ 블루투스 연결됨: $_savedAddress');

      _connection!.input?.listen((data) {
        final raw = utf8.decode(data);
        final lines = raw.split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            _dataController.add(trimmed);
            print('📥 원본 수신: $trimmed');
          }
        }
      }).onDone(() {
        print('🔌 연결 종료됨');
        _connection = null;
      });

      return true;
    } catch (e) {
      print('❌ 연결 실패: $e');
      _connection = null;
      return false;
    }
  }

  Stream<String> get onDataReceived => _dataController.stream;

  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
    print('🔌 연결 해제됨');
  }
}
