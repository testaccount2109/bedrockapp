# HostConnect - Entwicklerdokumentation

## Projektstruktur

```text
lib/
  app/
  core/
  data/
  domain/
  features/
  services/
test/
android/
docs/
```

## Clean Architecture

### Domain

`lib/domain` enthaelt reine App-Modelle und Repository-Schnittstellen.

Wichtige Dateien:

- `server_profile.dart`
- `host_status.dart`
- `app_settings.dart`
- `server_repository.dart`
- `settings_repository.dart`

### Data

`lib/data` implementiert lokale Persistenz mit SQLite.

Wichtige Datei:

- `local_database.dart`

### Features

`lib/features` enthaelt UI-nahe Controller und Widgets:

- `servers`: Serverliste, Suche, Favoriten, Formulare, Host-Aktionen.
- `options`: Spracheinstellung Deutsch/Englisch.
- `shell`: Zwei-Tab-Navigation.

### Services

`lib/services` enthaelt technische Dienste:

- `bedrock`: UDP-Dienst und Socket-Orchestrierung.
- `discovery`: MOTD und LAN Discovery.
- `raknet`: RakNet Magic, Paketcodec, Open Connection Replies.
- `transfer`: Transfer-Packet-Serialisierung.
- `host`: Start/Stop-Session-Manager.

## State Management

Riverpod wird verwendet fuer:

- Logging Service
- lokale Datenbank
- Serverliste
- Spracheinstellung
- Hoststatus
- Netzwerkdienste

## Lokalisierung

Die App verwendet eine kleine interne String-Schicht:

- `AppStrings('de')`
- `AppStrings('en')`

Es gibt exakt zwei Sprachen:

- Deutsch
- Englisch

## Netzwerkentwicklung

### LAN Discovery pruefen

1. App auf physischem Android-Geraet starten.
2. Server speichern.
3. Host starten.
4. Minecraft Bedrock im selben WLAN oeffnen.
5. LAN-Liste pruefen.
6. Logs in der App lesen.

Erwartete Logs:

```text
[network] Bedrock UDP service started
[discovery] Unconnected pong sent
```

### RakNet pruefen

Beim Verbindungsversuch sollte HostConnect Open Connection Replies loggen:

```text
[raknet] Open connection reply 1 sent
[raknet] Open connection reply 2 sent
```

### Transfer Packet pruefen

Unit-Test:

```bash
flutter test test/transfer_packet_builder_test.dart
```

## Qualitaetsbefehle

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## Performance- und Speicherregeln

- Logs werden im Speicher begrenzt gehalten.
- Serverprofile werden per SQLite geladen und sortiert.
- UDP-Datagramme werden sofort verarbeitet und nicht dauerhaft gepuffert.
- UI verwendet Streams/Provider statt Polling.
- Netzwerkfehler werden geloggt statt unkontrolliert zu werfen.

## Erweiterung des Bedrock-Login

Die naechsten Protokollkomponenten gehoeren in `lib/services/bedrock`:

- Packet batching
- Compression
- `NetworkSettingsRequest`
- `NetworkSettings`
- `Login`
- Resource-Pack-Flow
- `PlayStatus(LoginSuccess)`

Felddefinitionen und Sequenz stehen in `docs/technical-analysis.md`.
