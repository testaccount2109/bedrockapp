# HostConnect - Technische Analyse

Stand: 2026-06-01

Diese Datei ist bewusst eine Analyse- und Planungsunterlage. Sie enthaelt keine Implementierung. Ziel ist, vor dem Schreiben von Flutter/Dart-Code die minimal notwendige Minecraft-Bedrock-Netzwerkstrecke fuer HostConnect zu verstehen.

## Kurzfazit

HostConnect sollte fuer Version 1 als **Minimalserver mit Transfer-Packet** gebaut werden, nicht als vollwertiger Proxy.

Begruendung:

- Das Produktziel ist kein permanentes Mitspielen ueber HostConnect, sondern ein einmaliger Einstieg ueber den LAN-Tab und anschliessende Weiterleitung.
- LAN-Sichtbarkeit braucht nur RakNet-Unconnected-Pong-Antworten auf lokale UDP-Pings.
- Die Weiterleitung ist ein existierendes clientbound Bedrock-Paket: `packet_transfer` / Netzwerk-ID `0x55`, mit `server address`, `port` und `reload world`.
- Ein Proxy muesste Authentifizierung, Verschluesselung, Kompression, Ressourcenpakete, Spawn, Welt-/Chunkdaten, Movement, Inventar und Versionsdrift dauerhaft korrekt vermitteln. Das ist erheblich groesser und stoeranfaelliger.
- Der Transfer-Weg braucht dennoch einen echten lokalen Bedrock-Verbindungsaufbau bis mindestens nach Login/Ressourcenpaket-Phase. Ein reiner UDP-Advertiser reicht nicht.

Wichtiger Risiko-Hinweis: Mojang/Microsoft dokumentiert den Bedrock-Netzwerk-Protocol-Stack als nicht unterstuetzte API fuer Endnutzer. Das Protokoll aendert sich zwischen Releases und kann inoffizielle Implementierungen regelmaessig brechen.

## Quellen

- Microsoft Learn: Netzwerkprotokoll ist nicht als stabile Endnutzer-API unterstuetzt; Mojang pflegt Protocol Docs fuer Serverpartner: https://learn.microsoft.com/en-us/minecraft/creator/documents/moreinfosources?view=minecraft-bedrock-stable
- Mojang Bedrock Protocol Docs, Paketindex: https://mojang.github.io/bedrock-protocol-docs/html/packets.html
- Mojang `NetworkSettingsPacket`: https://mojang.github.io/bedrock-protocol-docs/html/NetworkSettingsPacket.html
- Mojang `LoginPacket`: https://mojang.github.io/bedrock-protocol-docs/html/LoginPacket.html
- Bedrock Wiki RakNet: https://wiki.bedrock.dev/servers/raknet
- Bedrock Wiki Bedrock Protocol/Login: https://wiki.bedrock.dev/servers/bedrock
- PrismarineJS `minecraft-data` Bedrock 1.21.130 Protocol: https://prismarinejs.github.io/minecraft-data/protocol/bedrock/1.21.130/
- PrismarineJS Protocol Versions: https://prismarinejs.github.io/minecraft-data/protocol/
- PocketMine-MP `TransferPacket`: https://apidoc.pmmp.io/dc/def/_transfer_packet_8php_source.html
- gophertunnel Repository/API: https://github.com/sandertv/gophertunnel und https://pkg.go.dev/github.com/sandertv/gophertunnel@v1.56.2/minecraft

## Protokollschichten

HostConnect muss drei Schichten unterscheiden:

1. **LAN Discovery / Server List Ping**
   UDP/RakNet unconnected messages. Das macht den Eintrag unter "Freunde -> LAN-Spiele" sichtbar.

2. **RakNet Session**
   Verbindungsaufbau ueber UDP: Open Connection Request/Reply, Connection Request, Frame Sets, ACK/NACK, Ordering/Reliability.

3. **Bedrock Game Protocol**
   Game-Pakete nach RakNet-Session: NetworkSettings, Login, Resource Packs, PlayStatus, optional Spawn, Transfer.

## LAN Discovery

### Ports

- Standard IPv4: UDP `19132`
- Standard IPv6: UDP `19133`
- Der Port kann fuer direkte Server geaendert werden, LAN-Discovery/Bedrock-Konventionen erwarten aber in der Praxis sehr oft diese Standardports. Fuer Konsolen ist Sichtbarkeit ueber LAN besonders wichtig.

### Client -> Server: Unconnected Ping

Format laut Bedrock Wiki:

```text
0x01 | client alive time in ms (u64) | magic | client GUID
```

`magic` ist:

```text
00 ff ff 00 fe fe fe fe fd fd fd fd 12 34 56 78
```

### Server -> Client: Unconnected Pong

Format:

```text
0x1c | client alive time from ping | server GUID | magic | string length | MOTD string
```

MOTD-String:

```text
MCPE;MOTD line 1;Protocol Version;Version Name;Player Count;Max Player Count;Server Unique ID;MOTD line 2;Game mode;Game mode numeric;IPv4 Port;IPv6 Port;
```

Beispiel fuer HostConnect:

```text
MCPE;HostConnect - DonutSMP;818;1.21.130;0;1;1234567890123456789;HostConnect;Survival;1;19132;19133;
```

Hinweise:

- `MOTD line 1` ist der sichtbare Servername.
- `Protocol Version` und `Version Name` muessen zur Minecraft-Clientversion passen, sonst kann der Client den Eintrag als inkompatibel markieren oder nicht verbinden.
- `Server Unique ID` sollte pro HostConnect-Installation stabil sein, damit Clients den Server nicht bei jedem Start als anderen Host sehen.
- `Player Count`/`Max Player Count` duerfen klein sein, z. B. `0`/`1`, weil HostConnect nur Transfer-Gateway ist.
- `Game mode` scheint fuer Discovery weniger entscheidend zu sein, sollte aber plausibel gesetzt werden.

### Broadcast-Mechanik

Der Bedrock-Client sendet Unconnected Pings an eingetragene Server und in das lokale Netzwerk. HostConnect muss deshalb:

- UDP-Socket auf `0.0.0.0:19132` binden.
- Broadcast/Multicast-Empfang zulassen, soweit Android und Netzwerk es erlauben.
- Auf jedes valide Unconnected Ping mit einem Unconnected Pong an die Absenderadresse antworten.
- Fuer IPv6 separat `19133` pruefen, spaeter optional in Phase 2.

Android-Risiken:

- Android kann Hintergrunddienste, WLAN-Multicast/Broadcast und lange laufende UDP-Sockets einschraenken.
- Fuer verlaessliche Sichtbarkeit ist ein Foreground Service mit sichtbarer Notification wahrscheinlich noetig.
- WLAN-MulticastLock kann erforderlich sein.

## RakNet Handshake

### Recherche-Update: packetId 132 / 0x84

`packetId=132` ist dezimal `0x84`. Das ist kein Bedrock-Game-Paket,
sondern ein RakNet Frame Set Datagramm. RakNet verwendet den Bereich
`0x80..0x8f` fuer Frame Sets; die eigentlichen verbundenen RakNet- oder
Bedrock-Payloads liegen erst innerhalb der Frames.

Damit ist die Ursache des Fehlers:

- HostConnect antwortet korrekt auf Discovery und Open Connection Request 1/2.
- Danach sendet Minecraft ein RakNet Frame Set wie `0x84`.
- HostConnect behandelt dieses Datagramm bisher als unbekannt, statt die
  Sequenznummer zu ACKen und die eingebetteten Frames zu verarbeiten.
- In diesem Frame Set steckt nach Open Connection Reply 2 typischerweise
  `Connection Request (0x09)`.
- Der Client erwartet darauf ein ACK fuer die Datagramm-Sequenz und ein
  zuverlaessig geordnetes Frame Set mit `Connection Request Accepted (0x10)`.

Vergleich mit echten Servern:

- Bedrock Wiki RakNet beschreibt Frame Sets `0x80..0x8f`, ACK `0xc0`,
  NACK `0xa0`, `Connection Request (0x09)`,
  `Connection Request Accepted (0x10)` und
  `New Incoming Connection (0x13)`.
- PocketMine-MP/RakLib trennt Offline-Pakete, ACK/NACK und Frame-Set-
  Verarbeitung; verbundene Nachrichten werden als Frames decodiert.
- Nukkit/Cloudburst RakNet nutzt denselben Ablauf mit Offline-Handshake,
  Encapsulated/Frame-Paketen, Reliability, Order Index und ACK/NACK.
- gophertunnel erstellt eine RakNet-Session, bevor Bedrock `Login` und die
  Resource-Pack-Phase verarbeitet werden.
- PrismarineJS Bedrock Protocol legt Bedrock oberhalb von RakNet; Login,
  Resource Packs und StartGame werden erst nach der RakNet-Verbindung
  relevant.

HostConnect hatte deshalb keine falsche Bedrock-Protokollversion als erstes
Problem. Der beobachtete Wert `132` zeigt eine fehlende RakNet-Online-Schicht:
MTU/Reply 2 waren weit genug, um Minecraft in den verbundenen RakNet-Pfad zu
bringen, aber nicht weit genug, um die Session zu akzeptieren.

Minimal notwendige Reihenfolge:

1. Client sendet `Open Connection Request 1`:

```text
0x05 | magic | RakNet protocol version | null padding
```

2. Server antwortet `Open Connection Reply 1`:

```text
0x06 | magic | server GUID | security=false | MTU size
```

3. Client sendet `Open Connection Request 2`:

```text
0x07 | magic | server address | MTU size | client GUID
```

4. Server antwortet `Open Connection Reply 2`:

```text
0x08 | magic | server GUID | client address | MTU size | security=false
```

5. Danach laufen RakNet Frame Set Packets mit Reliability, Ordering, ACK/NACK.

6. Client sendet `Connection Request`:

```text
0x09 | client GUID | request timestamp | secure=false
```

7. Server antwortet `Connection Request Accepted`:

```text
0x10 | client address | system index | system addresses | ping time | pong time
```

8. Client sendet `New Incoming Connection`.

9. Client sendet die erste Bedrock-Nachricht als RakNet Game Packet
   `0xfe`. Moderne Clients beginnen danach mit `NetworkSettingsRequest` und
   `Login`.

10. Server und Client durchlaufen die Resource-Pack-Phase. Auch wenn keine
    Ressourcenpakete angeboten werden, muessen die entsprechenden
    Bedrock-Pakete und Client-Responses korrekt beantwortet werden.

11. Server sendet PlayStatus/StartGame und weitere initiale Bedrock-Pakete.
    Erst wenn diese Phase stabil genug ist, kann HostConnect das
    Transfer-Paket zum Zielserver senden.

Wichtig fuer Implementierung:

- Ein eigener RakNet-Stack ist machbar, aber fehlertraechtig. ACK/NACK, MTU, Sequencing und Ordering muessen korrekt sein.
- Fuer Dart/Flutter gibt es wahrscheinlich keine ausgereifte Bedrock-RakNet-Library. Architektur sollte eine austauschbare Native-Core-Schicht erlauben.
- Fuer Android ist ein kleiner nativer Rust/Go-Core oder ein portierter, getesteter RakNet-Core realistischer als alles direkt in Dart neu zu schreiben.

## Bedrock Login

Seit Protokollversion `554` / Minecraft `1.19.20` beginnt die Bedrock-Phase mit `NetworkSettingsRequest`.

Minimaler Login-Ablauf fuer moderne Clients:

1. Client -> Server: `NetworkSettingsRequest`
   - Enthaelt die Client-Protokollversion.

2. Server -> Client: `NetworkSettings`
   - Setzt Kompression.
   - Zlib ist die konservative Wahl.
   - Keine Kompression ist fuer Debugging nuetzlich, aber nicht als Produktionsannahme geeignet.

3. Client -> Server: `Login`
   - Enthaelt Protocol Version und JWT-basierte Identity-/Clientdaten.
   - Bei Online-Clients koennen Xbox-Live-verifizierte JWTs vorhanden sein.
   - Ein lokales Gateway sollte diese Daten nicht faelschen. Fuer den Transfer muss HostConnect nur den lokalen Client akzeptieren, nicht den Zielserver authentifizieren.

4. Optional: Server -> Client `ServerToClientHandshake`
   - Aktiviert Encryption.

5. Optional: Client -> Server `ClientToServerHandshake`
   - Bestaetigt Encryption.

6. Server -> Client: `ResourcePacksInfo`

7. Client -> Server: `ResourcePackClientResponse`

8. Server -> Client: `ResourcePackStack`

9. Client -> Server: `ResourcePackClientResponse`

10. Server -> Client: `PlayStatus(LoginSuccess)`

Danach beginnt normalerweise Spawn:

11. Server -> Client: `StartGame`

12. Server -> Client: `CreativeContent`

13. Server -> Client: `BiomeDefinitionList`

14. Server -> Client: Chunks/Inventory/etc.

15. Server -> Client: `PlayStatus(PlayerSpawn)`

Fuer HostConnect ist der offene Punkt, ob `Transfer` bereits direkt nach `LoginSuccess` stabil funktioniert oder ob einzelne Clients erst nach `StartGame`/Spawn Transfer akzeptieren. Die konservative technische Annahme fuer Version 1:

- Ziel: Transfer **nach abgeschlossener Resource-Pack-Phase und `PlayStatus(LoginSuccess)`** senden.
- Falls Clients haengen oder ignorieren: Minimal-Spawn-Pfad implementieren und Transfer nach `StartGame`/initialer Spawn-Freigabe senden.

## Transfer-System

### Paket

PrismarineJS dokumentiert `packet_transfer` als clientbound `0x55` mit:

```text
server address: string
port: lu16
reload world: bool
```

PocketMine-MP bestaetigt dieselben Felder:

```text
address: string
port: unsigned short little endian
reloadWorld: bool
```

### Reihenfolge fuer HostConnect

Empfohlene Minimalreihenfolge:

1. LAN-Discovery aktiv.
2. Client verbindet sich per RakNet.
3. Bedrock PreLogin/Login bis `PlayStatus(LoginSuccess)`.
4. `TransferPacket(address=zielHost, port=zielPort, reloadWorld=false oder true)` senden.
5. Paket flushen.
6. Verbindung nach kurzer Frist geordnet schliessen, falls Client nicht selbst trennt.

`reloadWorld`:

- Fuer Transfer in einen komplett anderen Server ist `true` vermutlich sicherer, weil der Client lokale Welt-/Ressourcenzustaende neu laden soll.
- Falls Tests zeigen, dass `true` laengere Ladebildschirme oder Fehler verursacht, auf `false` wechseln.

### Braucht Transfer einen vollstaendigen Login?

Nicht fuer LAN-Discovery. Aber fuer das Transfer-Paket selbst ja: Der Client muss eine Bedrock-Game-Session haben, in der clientbound GamePackets akzeptiert werden.

Praktische Schlussfolgerung:

- Ein reiner Advertiser, der nur Pongs sendet, genuegt nicht.
- Ein Minimalserver genuegt wahrscheinlich, wenn er moderne NetworkSettings, Login, ResourcePacks und PlayStatus korrekt behandelt.
- Ein vollstaendiger Weltserver ist nur dann notwendig, wenn bestimmte Plattformen Transfer erst nach Spawn akzeptieren.

## Architekturentscheidung: Minimalserver + Transfer vs Proxy

### Option A: Minimalserver + Transfer Packet

Vorteile:

- Kleinere Protokolloberflaeche.
- Passt exakt zum Nutzerfluss.
- Keine dauerhafte Weiterleitung von verschluesseltem/komprimiertem Game-Traffic.
- Zielserver bleibt fuer Auth, Gameplay, Ressourcenpakete und Versionseigenheiten verantwortlich.
- Einfachere Logs: Discovery, Login, Transfer, Disconnect.

Nachteile:

- Transfer-Packet-Verhalten kann je Clientversion/Plattform unterschiedlich sein.
- Minimalserver muss trotzdem RakNet + Login korrekt sprechen.
- Bei Protokollaenderungen bricht Login/NetworkSettings schnell.

### Option B: Proxy-System

Vorteile:

- Kann theoretisch ohne Transfer-Packet funktionieren.
- Erlaubt komplexere Funktionen wie Serverauswahl im Spiel, Traffic-Inspection oder Fallbacks.

Nachteile:

- Sehr grosser Scope.
- Auth, Encryption, Compression, Resource Packs, Spawn, Movement, Inventar, Chunks und Packet-Versioning muessen dauerhaft korrekt laufen.
- Zielserver-Protokollversionen und Clientversionen muessen gemappt werden.
- Hoeheres Risiko fuer Latenz, Disconnects und Anti-Cheat-/Server-Kompatibilitaetsprobleme.

Entscheidung:

**Option A ist fuer HostConnect Version 1 die richtige Architektur.** Proxy bleibt ein spaeteres Forschungsprojekt, falls Transfer auf wichtigen Plattformen nicht mehr funktioniert.

## Relevante Open-Source-Projekte

### gophertunnel

- Go-Library fuer Bedrock-Software.
- Enthaelt Dial/Listen, RakNet, Bedrock-Packets, Auth und Server-/Proxy-Beispiele.
- Unterstuetzt in der Regel die aktuelle offizielle Minecraft-Version, nicht beliebig viele Versionen parallel.
- Gute Referenz fuer Listener-Status/Pong-Daten, Login-Flow und moegliche Proxy-Struktur.

### PocketMine-MP / PMMP BedrockProtocol

- PHP-Serverstack fuer Bedrock.
- Sehr nuetzlich fuer konkrete Packet-Felddefinitionen.
- `TransferPacket` ist ein direkter Beleg fuer Adresse/Port/ReloadWorld.

### PrismarineJS bedrock-protocol / minecraft-data

- Sehr wertvoll fuer maschinenlesbare Packet-IDs und Feldtypen ueber viele Versionen.
- Gut geeignet als Version-Matrix fuer HostConnect.

### Nukkit / Cloudburst

- Java-basierte Serverfamilie.
- Als Konzept- und Verhaltenreferenz nuetzlich, aber Legacy-/Wartungsstand genau pruefen.

## Minimal notwendige Implementierung fuer Phase 1

### Networking Core

- UDP bind IPv4 `0.0.0.0:19132`.
- Optional IPv6 `[::]:19133`.
- Unconnected Ping erkennen.
- Unconnected Pong mit korrektem MOTD senden.
- RakNet Server Handshake.
- RakNet Frame Set, ACK/NACK, reliable ordered frames.
- Bedrock packet framing, batching, compression.
- NetworkSettings/Login/ResourcePack/PlayStatus-Flow.
- TransferPacket senden.

### Flutter App

- Serverprofile lokal speichern:
  - Name
  - IP/Hostname
  - Port
  - Favorit
- Zwei Tabs:
  - Server
  - Optionen
- Dark Material 3.
- Optionen nur Sprache: Deutsch/Englisch.
- Host starten/stoppen.
- Status:
  - Online/Offline
  - Aktiver Server
  - Erfolgreiche Transfers
  - Laufzeit
- Logs sichtbar oder exportierbar.

### Android

- Foreground Service fuer aktiven Host.
- WLAN-/Netzwerkberechtigungen pruefen.
- MulticastLock/Broadcast-Kompatibilitaet pruefen.
- Akku-Optimierungen dokumentieren.

## Testplan vor UI-Implementierung

1. **LAN Discovery Harness**
   - UDP-Ping-Pong lokal mit PCAP/Wireshark pruefen.
   - Minecraft Windows/Android muss LAN-Eintrag sehen.
   - Variieren: Protocol Version, Version Name, Server GUID, Ports.

2. **RakNet Handshake Test**
   - Client verbindet sich bis RakNet Session.
   - ACK/NACK und MTU stabil.

3. **Bedrock Login Test**
   - NetworkSettingsRequest empfangen.
   - NetworkSettings senden.
   - Login lesen und dekodieren.
   - ResourcePack-Flow ohne Packs abschliessen.
   - LoginSuccess senden.

4. **Transfer Test**
   - Transfer zu `play.donutsmp.net:19132`.
   - Transfer zu lokalem Bedrock Dedicated Server.
   - Testmatrix:
     - Android Client
     - Windows Client
     - Xbox
     - PlayStation
     - Nintendo Switch
     - iOS

5. **Fallback Test**
   - Falls Transfer nach LoginSuccess nicht ausreicht: Minimal-StartGame und Transfer nach Spawn testen.

## Offene technische Fragen

- Akzeptieren alle Zielplattformen `TransferPacket` vor `StartGame`, oder brauchen manche Clients Spawn?
- Welcher `reloadWorld`-Wert ist fuer aktuelle Clients am stabilsten?
- Wie streng pruefen Konsolen die Protokollversion im Pong gegen die tatsaechliche Login-Protokollversion?
- Ist Androids UDP-Broadcast-Empfang im Foreground Service auf typischen Heimroutern stabil genug?
- Welche Bedrock-Version soll Version 1 zuerst targeten? Am 2026-06-01 zeigt PrismarineJS `1.21.130` als dokumentierte aktuelle Bedrock-Protokollseite.

## Empfohlene naechste Entwicklungsreihenfolge

1. Protocol-Version-Matrix fuer `1.21.130` anlegen.
2. Kleinen nativen/isolierten Networking-Prototyp bauen, noch ohne Flutter-UI.
3. LAN Discovery auf Android testen.
4. RakNet/Login bis `LoginSuccess` testen.
5. TransferPacket testen.
6. Erst danach Flutter-App-Struktur, Speicherung und UI bauen.

## Go/No-Go-Kriterien vor Implementierung der App-UI

Go:

- Minecraft zeigt HostConnect im LAN-Tab.
- Mindestens Windows oder Android Client verbindet sich zum lokalen HostConnect.
- Transfer zu lokalem BDS oder bekanntem Zielserver funktioniert reproduzierbar.
- Logs zeigen Discovery, Login und Transfer eindeutig.

No-Go / Architektur neu bewerten:

- TransferPacket wird von aktuellen Clients ignoriert.
- Transfer funktioniert nur nach grossem Spawn-/Welt-Setup.
- Android blockiert LAN-Discovery unzuverlaessig trotz Foreground Service.
- Konsolen akzeptieren den LAN-Minimalserver nicht.
