# HostConnect - Build-Anleitung

## Flutter Befehle

Abhaengigkeiten:

```bash
flutter pub get
```

Statische Analyse:

```bash
flutter analyze
```

Tests:

```bash
flutter test
```

Debug-APK:

```bash
flutter build apk --debug
```

Release-APK:

```bash
flutter build apk --release
```

Release-App-Bundle:

```bash
flutter build appbundle --release
```

Clean Build:

```bash
flutter clean
flutter pub get
flutter build apk --release
```

## Erwartete Artefakte

APK:

```text
build/app/outputs/flutter-apk/app-release.apk
```

AAB:

```text
build/app/outputs/bundle/release/app-release.aab
```

## Lokale Verifikation

Nach dem Build:

1. APK auf Android-Geraet installieren.
2. Serverprofil speichern.
3. Host starten.
4. Minecraft Bedrock im selben WLAN oeffnen.
5. LAN-Eintrag `HostConnect - <Servername>` suchen.
6. App-Logs pruefen.
