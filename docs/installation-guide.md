# HostConnect - Installationsanleitung

## Voraussetzungen

- Flutter SDK installiert und im PATH.
- Android Studio oder Android Command Line Tools.
- Android SDK mit passender Platform fuer `compileSdk 35`.
- Ein physisches Android-Geraet oder Emulator fuer UI-Tests.
- Fuer LAN-Discovery-Tests: physisches Android-Geraet im WLAN.

## Abhaengigkeiten installieren

```bash
flutter pub get
```

## Debug-Start

```bash
flutter run
```

## Release APK bauen

```bash
flutter build apk --release
```

Ausgabe:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Android App Bundle bauen

```bash
flutter build appbundle --release
```

Ausgabe:

```text
build/app/outputs/bundle/release/app-release.aab
```

## Release-Signierung

Fuer Play-Store- oder externe Release-Verteilung muss eine Android-Signierung eingerichtet werden.

Empfohlener Ablauf:

1. Keystore ausserhalb des Repositories erzeugen.
2. `android/key.properties` lokal anlegen.
3. Signing-Konfiguration in `android/app/build.gradle` eintragen.
4. Release erneut bauen.

`key.properties` darf nicht ins Repository.

## App verwenden

1. App installieren.
2. Tab `Server` oeffnen.
3. Server hinzufuegen:
   - Name
   - IP-Adresse oder Hostname
   - Port
   - Favorit optional
4. `Host starten` antippen.
5. Minecraft Bedrock im gleichen Netzwerk oeffnen.
6. Bereich `Freunde -> LAN-Spiele` pruefen.
7. Erwarteter Name: `HostConnect - <Servername>`.

## Netzwerkhinweise

- Android und Minecraft-Client muessen im gleichen lokalen Netzwerk sein.
- Router duerfen UDP-Broadcast/Multicast nicht blockieren.
- Port `19132/udp` darf auf dem Android-Geraet nicht von einer anderen App belegt sein.
- VPNs, Gast-WLANs und Client-Isolation koennen LAN-Erkennung verhindern.
