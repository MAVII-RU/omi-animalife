import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';

enum DeviceStreamState { idle, scanning, connecting, streaming, error }

class TranslationResult {
  final String humanTranslation;
  final String emotion;
  final String? intent;
  final String? advice;
  final String urgency;
  final double confidence;

  const TranslationResult({
    required this.humanTranslation,
    required this.emotion,
    this.intent,
    this.advice,
    required this.urgency,
    required this.confidence,
  });

  factory TranslationResult.fromJson(Map<String, dynamic> j) => TranslationResult(
        humanTranslation: j['human_translation'] as String? ?? '',
        emotion: j['emotion'] as String? ?? '',
        intent: j['intent'] as String?,
        advice: j['advice'] as String?,
        urgency: j['urgency_level'] as String? ?? 'low',
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
      );
}

class DeviceStreamService {
  DeviceStreamState _state = DeviceStreamState.idle;
  DeviceStreamState get state => _state;

  final _stateController = StreamController<DeviceStreamState>.broadcast();
  Stream<DeviceStreamState> get stateStream => _stateController.stream;

  final _translationController = StreamController<TranslationResult>.broadcast();
  Stream<TranslationResult> get translationStream => _translationController.stream;

  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  BluetoothDevice? _device;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _audioSub;
  StreamSubscription? _wsSub;

  void _setState(DeviceStreamState s) {
    _state = s;
    _stateController.add(s);
  }

  // Scan for omi devices and connect to the first found
  Future<void> startSession({
    required String token,
    required int petId,
    String language = 'ru',
  }) async {
    if (_state != DeviceStreamState.idle) return;
    _setState(DeviceStreamState.scanning);

    try {
      // Scan for omi device (filter by service UUID)
      final completer = Completer<BluetoothDevice>();
      final scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final serviceUuids = r.advertisementData.serviceUuids.map((u) => u.toString().toLowerCase()).toList();
          if (serviceUuids.contains(kOmiServiceUuid.toLowerCase()) ||
              r.device.platformName.toLowerCase().contains('omi') ||
              r.device.platformName.toLowerCase().contains('friend')) {
            if (!completer.isCompleted) completer.complete(r.device);
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      try {
        _device = await completer.future.timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw Exception('Устройство omi не найдено. Убедитесь, что оно рядом и включено.'),
        );
      } finally {
        await FlutterBluePlus.stopScan();
        scanSub.cancel();
      }

      _setState(DeviceStreamState.connecting);

      // Connect to device
      await _device!.connect(timeout: const Duration(seconds: 10));

      // Discover services
      final services = await _device!.discoverServices();
      BluetoothCharacteristic? audioChar;
      BluetoothCharacteristic? codecChar;

      for (final svc in services) {
        if (svc.uuid.toString().toLowerCase() == kOmiServiceUuid.toLowerCase()) {
          for (final c in svc.characteristics) {
            final cuuid = c.uuid.toString().toLowerCase();
            if (cuuid == kAudioDataStreamCharUuid.toLowerCase()) audioChar = c;
            if (cuuid == kAudioCodecCharUuid.toLowerCase()) codecChar = c;
          }
        }
      }

      if (audioChar == null) {
        throw Exception('Аудио характеристика не найдена. Попробуйте перезагрузить устройство.');
      }

      // Read codec (1 = PCM16LE, 10 = Opus — standard omi firmware)
      int codecId = 1;
      if (codecChar != null) {
        final codecValue = await codecChar.read();
        codecId = codecValue.isNotEmpty ? codecValue[0] : 1;
      }
      final codec = codecId == 10 ? 'opus' : 'pcm';

      // Open WebSocket to AnimaLife
      final wsUrl = 'wss://animapp.ru/api/device/stream?token=${Uri.encodeComponent(token)}&pet_id=$petId&codec=$codec&language=$language';
      _wsChannel = IOWebSocketChannel.connect(
        Uri.parse(wsUrl),
        pingInterval: const Duration(seconds: 20),
      );

      // Listen for translations from server
      _wsSub = _wsChannel!.stream.listen(
        (msg) {
          try {
            final data = jsonDecode(msg as String) as Map<String, dynamic>;
            final type = data['type'] as String?;
            if (type == 'translation') {
              final result = TranslationResult.fromJson(data['data'] as Map<String, dynamic>);
              _translationController.add(result);
            }
          } catch (_) {}
        },
        onError: (e) => _onError('WebSocket ошибка: $e'),
        onDone: () {
          if (_state == DeviceStreamState.streaming) _onError('Соединение с сервером разорвано');
        },
      );

      // Subscribe to audio BLE notifications
      await audioChar.setNotifyValue(true);
      _audioSub = audioChar.onValueReceived.listen((chunk) {
        if (_state == DeviceStreamState.streaming && chunk.isNotEmpty) {
          _wsChannel?.sink.add(Uint8List.fromList(chunk));
        }
      });

      _setState(DeviceStreamState.streaming);
    } catch (e) {
      _onError(e.toString());
      await stopSession();
    }
  }

  void _onError(String msg) {
    _errorController.add(msg);
    _setState(DeviceStreamState.error);
  }

  Future<void> stopSession() async {
    _setState(DeviceStreamState.idle);
    await _audioSub?.cancel();
    _audioSub = null;
    await _wsSub?.cancel();
    _wsSub = null;
    await _wsChannel?.sink.close();
    _wsChannel = null;
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
  }

  Future<void> dispose() async {
    await stopSession();
    await _stateController.close();
    await _translationController.close();
    await _errorController.close();
  }
}
