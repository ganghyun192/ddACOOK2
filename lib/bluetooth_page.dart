import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'bluetooth_service.dart';
import 'home_page.dart';

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  List<BluetoothDevice> _devices = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBondedDevices();
  }

  Future<void> _fetchBondedDevices() async {
    try {
      final bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() {
        _devices = bondedDevices.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '블루투스 기기 검색 실패: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() => _isLoading = true);

    final success = await BluetoothService().connect(device.address);

    setState(() => _isLoading = false);

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("블루투스 연결에 실패했습니다.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('블루투스 기기 선택'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView.builder(
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final device = _devices[index];
          return ListTile(
            title: Text(device.name ?? '알 수 없는 기기'),
            subtitle: Text(device.address),
            onTap: () => _connectToDevice(device),
          );
        },
      ),
    );
  }
}
