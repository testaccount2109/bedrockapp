# HostConnect - Technische Release-Dokumentation

Stand: 2026-06-01

## Zweck

HostConnect stellt auf Android einen lokalen Minecraft-Bedrock-LAN-Eintrag bereit. Die App speichert Zielserver lokal und startet einen UDP-Dienst, der von Minecraft Bedrock im Bereich LAN-Spiele erkannt werden kann.

## Architektur

Die App besteht aus diesen Schichten:

- `app`: Theme, App-Root und einfache Lokalisierung.
- `core`: Konfiguration, Fehlerklassen, Logging und Hilfsfunktionen.
- `data`: SQLite-basierte lokale Persistenz.
- `domain`: Entities und Repository-Schnittstellen.
- `features`: UI und Controller fuer Server, Optionen und Shell.
- `services`: Netzwerkdienste fuer LAN Discovery, RakNet-Basis und Transfer-Packet-Serialisierung.

## Persistenz

Datei:

- `host_connect.sqlite` im Application Documents Directory.

Tabellen:

- `server_profiles`
  - `id`
  - `name`
  - `host`
  - `port`
  - `is_favorite`
- `app_settings`
  - `language_code`
  - `local_server_guid`

Es werden keine Cloud-Dienste, Accounts oder externen APIs verwendet.

## LAN Discovery

HostConnect bindet einen UDP-Socket auf:

```text
0.0.0.0:19132
```

Der Dienst verarbeitet RakNet Unconnected Ping:

```text
0x01 | ping time | magic | client guid
```

Antwort:

```text
0x1c | ping time | server guid | magic | MOTD string
```

Der MOTD-String wird dynamisch aus dem aktiven Serverprofil erzeugt:

```text
MCPE;HostConnect - <Servername>;818;1.21.130;0;1;<guid>;HostConnect;Survival;1;19132;19133;
```

## RakNet Handshake

Die aktuelle Basis beantwortet:

- `Open Connection Request 1` mit `Open Connection Reply 1`
- `Open Connection Request 2` mit `Open Connection Reply 2`

Fehlerbehandlung:

- Ungueltige Magic wird ignoriert.
- Partielle UDP-Sends werden geloggt.
- Datagramm-Verarbeitungsfehler werden abgefangen und protokolliert.
- Socket-Bind-Fehler werden als Host-Fehler in der UI angezeigt.

## Bedrock Login

Der Release-Code trennt RakNet-Discovery, RakNet-Open-Connection und Bedrock-Packet-Serialisierung sauber. Die vollstaendige Bedrock-Login-Sequenz ist in der technischen Analyse beschrieben und als naechster Protokollausbau vorgesehen.

Pruefpunkte fuer den Login-Ausbau:

- `NetworkSettingsRequest`
- `NetworkSettings`
- `Login`
- Resource-Pack-Flow ohne Packs
- `PlayStatus(LoginSuccess)`

## Transfer Packet

Der Transfer-Packet-Builder serialisiert Bedrock `packet_transfer`:

```text
packet id: 0x55
server address: string
port: little-endian uint16
reload world: bool
```

Der Builder ist durch Unit-Test abgedeckt.

## Logging

Logging ist strukturiert und in der UI sichtbar. Kategorien:

- `network`
- `discovery`
- `raknet`
- `host`
- `transfer`

Beispiele:

- UDP-Dienst gestartet
- Unconnected Pong gesendet
- Open Connection Reply gesendet
- Socket- oder Datagramm-Fehler

## Android Netzwerkkompatibilitaet

Manifest-Berechtigungen:

- `INTERNET`
- `ACCESS_NETWORK_STATE`
- `ACCESS_WIFI_STATE`
- `CHANGE_WIFI_MULTICAST_STATE`

Die App setzt `broadcastEnabled` fuer den UDP-Socket. Fuer LAN-Tests sollte ein physisches Android-Geraet im gleichen WLAN wie der Minecraft-Client verwendet werden.

## Release-Grenzen

Diese Release-Basis ist fuer LAN-Sichtbarkeit und die HostConnect-App-Verwaltung vorbereitet. Vollstaendige Bedrock-Session mit Login und automatischem Transfer benoetigt den in `docs/technical-analysis.md` beschriebenen Protokollausbau.
