# HostConnect

HostConnect is a Flutter Android app for exposing a local Minecraft Bedrock LAN entry named `HostConnect - <Servername>`.

The app stores Bedrock server profiles locally, starts and stops a UDP Bedrock LAN service, answers RakNet LAN discovery packets, logs network activity, and provides a minimal release UI with exactly two tabs:

- Server
- Optionen / Options

No cloud, accounts, analytics, or external APIs are used.

## Current Release Scope

HostConnect includes:

- Local SQLite persistence for server profiles and app settings.
- Material Design 3 dark UI.
- Server add, edit, delete, favorite, search, and favorite-first sorting.
- Start/stop control for the local Bedrock UDP service.
- LAN Discovery on UDP `19132`.
- Dynamic Bedrock MOTD: `HostConnect - <Servername>`.
- RakNet Unconnected Pong handling.
- RakNet Open Connection Reply 1 and Reply 2 foundation.
- Transfer packet serializer for Bedrock packet `0x55`.
- Structured in-app logging.

## Build

Install Flutter, then run:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

For an Android App Bundle:

```bash
flutter build appbundle --release
```

## Android Permissions

HostConnect declares only local network permissions needed by the implemented app:

- `INTERNET`
- `ACCESS_NETWORK_STATE`
- `ACCESS_WIFI_STATE`
- `CHANGE_WIFI_MULTICAST_STATE`

## Documentation

- [Technical documentation](docs/release-technical-documentation.md)
- [Installation guide](docs/installation-guide.md)
- [Android SDK fix](docs/android-sdk-fix.md)
- [Developer guide](docs/developer-guide.md)
- [Complete file list](docs/file-list.md)
- [Protocol analysis](docs/technical-analysis.md)
- [Architecture plan](docs/architecture-and-implementation-plan.md)
