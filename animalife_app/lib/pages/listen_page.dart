import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/pet.dart';
import '../services/animalife_api.dart';
import '../services/device_stream_service.dart';

class ListenPage extends StatefulWidget {
  final Pet pet;
  const ListenPage({super.key, required this.pet});

  @override
  State<ListenPage> createState() => _ListenPageState();
}

class _ListenPageState extends State<ListenPage> {
  final _svc = DeviceStreamService();
  DeviceStreamState _state = DeviceStreamState.idle;
  final List<TranslationResult> _results = [];
  String? _error;

  late final StreamSubscription _stateSub;
  late final StreamSubscription _translationSub;
  late final StreamSubscription _errorSub;

  @override
  void initState() {
    super.initState();
    _stateSub = _svc.stateStream.listen((s) => setState(() { _state = s; }));
    _translationSub = _svc.translationStream.listen((r) => setState(() { _results.insert(0, r); }));
    _errorSub = _svc.errorStream.listen((e) => setState(() { _error = e; }));
  }

  Future<void> _start() async {
    setState(() { _error = null; _results.clear(); });

    // Request BLE permissions
    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    if (!bluetoothScan.isGranted || !bluetoothConnect.isGranted) {
      setState(() { _error = 'Нужен доступ к Bluetooth. Разрешите его в настройках.'; });
      return;
    }

    final token = await AnimalifeApi.getToken();
    if (token == null) {
      setState(() { _error = 'Токен не найден. Выйдите и войдите снова.'; });
      return;
    }

    await _svc.startSession(token: token, petId: widget.pet.id);
  }

  Future<void> _stop() async {
    await _svc.stopSession();
    setState(() { _state = DeviceStreamState.idle; });
  }

  @override
  void dispose() {
    _stateSub.cancel();
    _translationSub.cancel();
    _errorSub.cancel();
    _svc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(widget.pet.name, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(children: [
        _StatusPanel(state: _state, pet: widget.pet),
        if (_error != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.shade900.withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
          ),
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Text(
                    _state == DeviceStreamState.streaming
                        ? 'Слушаю ${widget.pet.name}...\nБуду присылать переводы звуков.'
                        : 'Нажмите "Слушать" чтобы\nначать сессию с устройством',
                    style: const TextStyle(color: Colors.white38, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _results.length,
                  itemBuilder: (_, i) => _ResultCard(result: _results[i]),
                ),
        ),
        _ControlButton(state: _state, onStart: _start, onStop: _stop),
      ]),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final DeviceStreamState state;
  final Pet pet;
  const _StatusPanel({required this.state, required this.pet});

  String get _label {
    switch (state) {
      case DeviceStreamState.scanning: return 'Поиск устройства...';
      case DeviceStreamState.connecting: return 'Подключение к omi...';
      case DeviceStreamState.streaming: return '● Идёт запись';
      case DeviceStreamState.error: return 'Ошибка';
      default: return 'Готов';
    }
  }

  Color get _color {
    switch (state) {
      case DeviceStreamState.streaming: return const Color(0xFF4CAF50);
      case DeviceStreamState.error: return Colors.redAccent;
      case DeviceStreamState.scanning:
      case DeviceStreamState.connecting: return const Color(0xFFFFB300);
      default: return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(pet.emoji, style: const TextStyle(fontSize: 32)),
        Row(children: [
          if (state == DeviceStreamState.scanning || state == DeviceStreamState.connecting)
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFB300)))
          else
            Container(width: 10, height: 10, decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(_label, style: TextStyle(color: _color, fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final TranslationResult result;
  const _ResultCard({required this.result});

  Color get _urgencyColor {
    switch (result.urgency) {
      case 'high': return Colors.redAccent;
      case 'medium': return Colors.orangeAccent;
      default: return const Color(0xFF4CAF50);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _urgencyColor.withOpacity(0.3), width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _urgencyColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(result.emotion, style: TextStyle(color: _urgencyColor, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const Spacer(),
          Text('${(result.confidence * 100).round()}%', style: const TextStyle(color: Colors.white38, fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        Text(
          result.humanTranslation,
          style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
        ),
        if (result.advice != null && result.advice!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '💡 ${result.advice}',
            style: const TextStyle(color: Colors.white60, fontSize: 14, height: 1.3),
          ),
        ],
      ]),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final DeviceStreamState state;
  final VoidCallback onStart;
  final VoidCallback onStop;
  const _ControlButton({required this.state, required this.onStart, required this.onStop});

  bool get _isActive => state == DeviceStreamState.scanning ||
      state == DeviceStreamState.connecting ||
      state == DeviceStreamState.streaming;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isActive ? onStop : onStart,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isActive ? Colors.red.shade700 : const Color(0xFF6C63FF),
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            _isActive ? 'Стоп' : 'Слушать',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
