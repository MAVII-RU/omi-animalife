# AnimalLife Device App

Flutter-приложение для подключения XIAO nRF52840 Sense (omi) к AnimalLife.

## Архитектура

```
XIAO nRF52840 → BLE → AnimalLife Device App → WebSocket → animapp.ru/api/device/stream → Gemini/Qwen → перевод → App
```

## Экраны

1. **Login** — авторизация через email OTP (AnimaLife, без Firebase)
2. **Pet Select** — выбор питомца из профилей AnimaLife
3. **Listen** — сессия прослушивания: BLE → WebSocket → перевод в реальном времени

## Сборка

```bash
cd animalife_app
flutter pub get
flutter run                    # debug
flutter build apk --release    # Android APK
flutter build ios --release    # iOS (нужен Mac + Xcode)
```

## Требования

- Flutter 3.x
- Android 6.0+ (BLE support)
- iOS 13+ (optional)
- Устройство XIAO nRF52840 Sense с прошивкой omi (стандартная)

## BLE UUID (omi firmware)

- Service: `19b10000-e8f2-537e-4f6c-d104768a1214`
- Audio stream: `19b10001-e8f2-537e-4f6c-d104768a1214`
- Codec: `19b10002-e8f2-537e-4f6c-d104768a1214`

## API

- Base: `https://animapp.ru/api`
- Auth: `POST /auth/email/send` → `POST /auth/email/verify`
- Pets: `GET /pets`
- Stream: `WSS /device/stream?token=JWT&pet_id=X&codec=opus`
