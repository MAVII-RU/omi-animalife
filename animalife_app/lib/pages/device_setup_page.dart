import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class DeviceSetupPage extends StatefulWidget {
  const DeviceSetupPage({super.key});

  @override
  State<DeviceSetupPage> createState() => _DeviceSetupPageState();
}

class _DeviceSetupPageState extends State<DeviceSetupPage> {
  static const _savedDeviceKey = 'saved_device_id';
  static const _savedDeviceNameKey = 'saved_device_name';

  List<ScanResult> _found = [];
  bool _scanning = false;
  String? _savedDeviceId;
  String? _savedDeviceName;
  StreamSubscription? _scanSub;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedDeviceId = prefs.getString(_savedDeviceKey);
      _savedDeviceName = prefs.getString(_savedDeviceNameKey);
    });
  }

  Future<void> _scan() async {
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    if (!scan.isGranted || !connect.isGranted) {
      _showSnack('Нет разрешения на Bluetooth. Разрешите в настройках телефона.');
      return;
    }

    setState(() { _scanning = true; _found = []; });

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _found = results.where((r) {
          final uuids = r.advertisementData.serviceUuids.map((u) => u.toString().toLowerCase()).toList();
          final name = r.device.platformName.toLowerCase();
          return uuids.contains(kOmiServiceUuid.toLowerCase()) ||
              name.contains('omi') ||
              name.contains('friend');
        }).toList();
      });
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    await Future.delayed(const Duration(seconds: 10));
    await FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    setState(() { _scanning = false; });
  }

  Future<void> _saveDevice(BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedDeviceKey, device.remoteId.str);
    final name = device.platformName.isNotEmpty ? device.platformName : 'omi Device';
    await prefs.setString(_savedDeviceNameKey, name);
    setState(() { _savedDeviceId = device.remoteId.str; _savedDeviceName = name; });
    _showSnack('✅ Устройство $name сохранено');
  }

  Future<void> _forgetDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedDeviceKey);
    await prefs.remove(_savedDeviceNameKey);
    setState(() { _savedDeviceId = null; _savedDeviceName = null; });
    _showSnack('Устройство забыто');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Подключение устройства', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Saved device card
          if (_savedDeviceId != null) ...[
            _SectionHeader('Сохранённое устройство'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.4)),
              ),
              child: Row(children: [
                const Text('📡', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_savedDeviceName ?? 'omi Device',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(_savedDeviceId!, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: _forgetDevice,
                  tooltip: 'Забыть устройство',
                ),
              ]),
            ),
            const SizedBox(height: 24),
          ],

          _SectionHeader('Найти устройство'),
          const Text(
            'Убедитесь, что устройство omi включено и находится рядом.',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.bluetooth_searching, color: Colors.white),
            label: Text(_scanning ? 'Сканирование...' : 'Найти omi устройства',
                style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          if (_found.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionHeader('Найдено устройств: ${_found.length}'),
            ..._found.map((r) => _DeviceCard(
              result: r,
              isSaved: r.device.remoteId.str == _savedDeviceId,
              onSave: () => _saveDevice(r.device),
            )),
          ] else if (!_scanning) ...[
            const SizedBox(height: 20),
            const Center(
              child: Text('Устройства не найдены.\nПроверьте что omi включён.',
                  style: TextStyle(color: Colors.white38), textAlign: TextAlign.center),
            ),
          ],

          const SizedBox(height: 32),
          _SectionHeader('Инструкция по прошивке'),
          _FirmwareGuide(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5)),
  );
}

class _DeviceCard extends StatelessWidget {
  final ScanResult result;
  final bool isSaved;
  final VoidCallback onSave;

  const _DeviceCard({required this.result, required this.isSaved, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final name = result.device.platformName.isNotEmpty ? result.device.platformName : 'omi Device';
    final rssi = result.rssi;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
        border: isSaved ? Border.all(color: const Color(0xFF6C63FF), width: 1.5) : null,
      ),
      child: Row(children: [
        const Text('📡', style: TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text('${result.device.remoteId.str} • RSSI: $rssi dBm',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ),
        if (isSaved)
          const Icon(Icons.check_circle, color: Color(0xFF6C63FF))
        else
          TextButton(
            onPressed: onSave,
            child: const Text('Выбрать', style: TextStyle(color: Color(0xFF6C63FF))),
          ),
      ]),
    );
  }
}

class _FirmwareGuide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _step('1', 'Скачайте прошивку', 'Откройте github.com/BasedHardware/omi → Releases → скачайте файл .uf2 для XIAO nRF52840'),
        const SizedBox(height: 12),
        _step('2', 'Переведите в режим загрузки', 'Дважды нажмите кнопку RESET на устройстве быстро. Появится диск "XIAO-SENSE" или "FTHRS52BOOT"'),
        const SizedBox(height: 12),
        _step('3', 'Установите прошивку', 'Перетащите скачанный .uf2 файл на диск устройства. Устройство перезагрузится автоматически.'),
        const SizedBox(height: 12),
        _step('4', 'Проверьте подключение', 'После прошивки вернитесь сюда и нажмите «Найти omi устройства»'),
      ]),
    );
  }

  Widget _step(String num, String title, String desc) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.3), shape: BoxShape.circle),
        child: Center(child: Text(num, style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold))),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4)),
        ]),
      ),
    ]);
  }
}
