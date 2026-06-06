# HostConnect - Architektur- und Implementierungsplan

Stand: 2026-06-01

Dieses Dokument baut auf `docs/technical-analysis.md` auf. Es ist ein Planungsdokument und enthaelt bewusst keinen vollstaendigen Produktcode.

## 1. Finale Architektur

### Architekturentscheidung

HostConnect wird als **lokaler Minimalserver mit Transfer-Packet** gebaut.

Die App startet auf Android einen lokalen Bedrock-kompatiblen UDP-Dienst. Minecraft sieht diesen Dienst als LAN-Spiel. Wenn ein Spieler verbindet, akzeptiert HostConnect die minimale RakNet-/Bedrock-Session und sendet danach ein Bedrock-Transfer-Packet zum gewaehlten Zielserver.

Nicht Teil der Version-1-Architektur:

- Kein vollstaendiger Proxy.
- Kein eigener Zielserver.
- Keine Cloud.
- Keine Accounts.
- Kein In-Game-Menue.

### Komponenten

#### Flutter UI

Aufgaben:

- Serverprofile anzeigen.
- Serverprofil erstellen, bearbeiten und loeschen.
- Favoritenstatus setzen.
- Zielserver auswaehlen.
- Host starten und stoppen.
- Status anzeigen:
  - Offline/Online
  - Aktiver Server
  - Erfolgreiche Transfers
  - Laufzeit
  - Letzte Fehler
- Sprache anzeigen und wechseln.

Die UI kennt keine Paketdetails. Sie spricht nur mit Application-Controllern/Use-Cases.

#### Lokale Datenbank

Aufgaben:

- Serverprofile lokal speichern.
- App-Einstellungen speichern:
  - Sprache
  - stabile HostConnect Server-GUID
  - optional zuletzt aktiver Server
- Keine Cloud-Synchronisierung.
- Keine personenbezogenen Accounts.

Empfohlene Daten:

```text
ServerProfile
- id
- name
- host
- port
- isFavorite
- createdAt
- updatedAt

AppSettings
- languageCode
- localServerGuid
- lastSelectedServerId
```

#### LAN Discovery Service

Aufgaben:

- UDP-Socket auf IPv4 `0.0.0.0:19132` starten.
- Optional spaeter IPv6 `[::]:19133` starten.
- RakNet Unconnected Ping erkennen.
- Unconnected Pong mit HostConnect-MOTD senden.
- Sichtbaren Servernamen bilden:
  - `HostConnect`
  - `HostConnect - <Servername>`
- Protocol Version und Version Name aus der Bedrock-Version-Matrix verwenden.
- Discovery-Events loggen.

Dieser Service macht HostConnect sichtbar, akzeptiert aber noch keine komplette Verbindung.

#### Bedrock Server Service

Aufgaben:

- RakNet-Verbindungen akzeptieren.
- Open Connection Request/Reply verarbeiten.
- RakNet Frame Sets, ACK/NACK, Reliability und Ordering abwickeln.
- Bedrock NetworkSettings/Login/Resource-Pack-Flow minimal beantworten.
- Status an Application Layer melden:
  - Spieler erkannt
  - RakNet verbunden
  - Login gestartet
  - Login erfolgreich
  - Fehler

Dieser Service ist die riskanteste technische Komponente. Er muss isoliert, testbar und austauschbar gebaut werden.

#### Transfer Service

Aufgaben:

- Nach erfolgreichem Minimal-Login das Bedrock Transfer-Packet erzeugen.
- Zielhost und Zielport aus dem aktiven Serverprofil lesen.
- `reloadWorld` konfigurierbar intern setzen, Startwert: `true`.
- Paket ueber die aktive Bedrock-Session senden.
- Erfolg/Fehler an Logging und Status melden.
- Verbindung nach Transfer sauber auslaufen lassen.

Der Transfer Service entscheidet nicht, welcher Server aktiv ist. Er bekommt ein bereits ausgewaehltes Ziel.

#### Logging Service

Aufgaben:

- Strukturierte Logs aufnehmen.
- Logs in Speicher halten fuer UI-Status.
- Optional Logs lokal persistieren.
- Log-Kategorien:
  - `app`
  - `database`
  - `discovery`
  - `raknet`
  - `bedrock_login`
  - `transfer`
  - `android_service`
  - `error`
- Wichtige Events:
  - LAN Broadcast/Discovery gestartet
  - Unconnected Ping empfangen
  - Unconnected Pong gesendet
  - Spieler erkannt
  - RakNet-Verbindung hergestellt
  - NetworkSettingsRequest empfangen
  - Login empfangen
  - Resource-Pack-Phase abgeschlossen
  - Transfer gesendet
  - Transfer erfolgreich gezaehlt
  - Socket-/Permission-/Protocol-Fehler

### Datenfluss

#### Server speichern

```text
Flutter UI
  -> ServerProfileController
  -> SaveServerProfileUseCase
  -> ServerRepository
  -> Local Database
  -> ServerRepository
  -> ServerProfileController
  -> Flutter UI aktualisiert Liste
```

#### Host starten

```text
Flutter UI
  -> HostController.start(serverId)
  -> LoadServerProfileUseCase
  -> ServerRepository
  -> HostSessionManager
  -> LAN Discovery Service startet
  -> Bedrock Server Service startet
  -> Logging Service schreibt Status
  -> HostController streamt Online-Status zur UI
```

#### LAN-Spiel sichtbar machen

```text
Minecraft Client
  -> UDP Unconnected Ping an LAN
  -> LAN Discovery Service
  -> MOTD aus aktivem Serverprofil + Version-Matrix
  -> UDP Unconnected Pong
  -> Minecraft Client zeigt "HostConnect - Servername"
```

#### Verbindung und Login

```text
Minecraft Client
  -> RakNet Open Connection
  -> Bedrock Server Service
  -> RakNet Session
  -> NetworkSettingsRequest
  -> NetworkSettings
  -> Login
  -> ResourcePacksInfo / ResourcePackStack
  -> PlayStatus(LoginSuccess)
  -> Bedrock Server Service meldet LoginReady
```

#### Transfer

```text
Bedrock Server Service
  -> LoginReady Event
  -> Transfer Service
  -> aktives Serverprofil
  -> TransferPacket(host, port, reloadWorld)
  -> Bedrock Session sendet Paket
  -> Logging Service
  -> TransferCounter erhoehen
  -> Flutter UI aktualisiert Status
```

#### Host stoppen

```text
Flutter UI
  -> HostController.stop()
  -> HostSessionManager
  -> LAN Discovery Service stoppt
  -> Bedrock Server Service schliesst Sessions und Socket
  -> Logging Service schreibt Stop-Event
  -> Flutter UI zeigt Offline
```

### Laufzeitgrenzen

Die Flutter UI darf nie direkt UDP-Pakete bauen. Netzwerkprotokolle liegen in `services/networking` oder in einer spaeteren nativen Core-Schicht. Dadurch bleibt ein Wechsel von Dart-Implementierung zu Go/Rust/Native moeglich.

## 2. MVP Definition

### Ziel des MVP

Der MVP beweist nur einen einzigen End-to-End-Pfad:

Ein Nutzer speichert einen Zielserver, startet HostConnect, sieht HostConnect in Minecraft als LAN-Spiel, verbindet sich und wird automatisch auf den Zielserver transferiert.

### Muss-Anforderungen

1. Einen Server speichern
   - Name
   - Host/IP
   - Port
   - Favorit optional fuer Datenmodell, aber UI-Funktion kann nachrangig sein

2. Einen Server auswaehlen
   - Liste zeigt gespeicherten Server.
   - Tippen oeffnet Detail oder setzt aktive Auswahl.

3. Host starten
   - Startbutton startet lokalen Dienst.
   - UI zeigt Online-Status.

4. LAN-Spiel sichtbar machen
   - Minecraft zeigt `HostConnect - <Servername>` unter LAN-Spiele.

5. Verbindung akzeptieren
   - RakNet-Verbindung wird angenommen.
   - Minimaler Bedrock Login wird abgeschlossen.

6. Spieler erfolgreich transferieren
   - TransferPacket wird an Client gesendet.
   - Client verbindet zum Zielserver.
   - TransferCounter wird erhoeht.

### Nicht Teil des MVP

- Mehrere gleichzeitige Spieler.
- Vollstaendiger Proxy.
- iOS-Build.
- Cloud-Sync.
- Accounts.
- Import/Export.
- Log-Viewer mit Filter UI.
- Erweiterte Einstellungen.
- Server-Ping des Zielservers.
- Automatische Bedrock-Versionserkennung.
- Vollstaendige Spawn-Welt, solange Transfer vor Spawn funktioniert.

### MVP-Erfolgskriterium

Der MVP ist erfolgreich, wenn mindestens ein aktueller Android- oder Windows-Bedrock-Client HostConnect im LAN-Tab sieht, verbindet und reproduzierbar zu einem lokalen Bedrock Dedicated Server oder oeffentlichen Zielserver transferiert wird.

## 3. Projektstruktur

Empfohlene Flutter-Struktur:

```text
lib/
  main.dart
  app/
    host_connect_app.dart
    app_router.dart
    app_theme.dart
    localization/
      app_localizations.dart
      supported_locales.dart
  core/
    config/
      bedrock_protocol_config.dart
      app_constants.dart
    errors/
      app_failure.dart
      network_failure.dart
      protocol_failure.dart
    logging/
      log_event.dart
      log_level.dart
      logging_service.dart
    time/
      clock.dart
    utils/
      validators.dart
  data/
    local/
      local_database.dart
      hive_adapters.dart
      settings_local_data_source.dart
      server_profile_local_data_source.dart
    models/
      server_profile_model.dart
      app_settings_model.dart
    repositories/
      server_repository_impl.dart
      settings_repository_impl.dart
  domain/
    entities/
      server_profile.dart
      app_settings.dart
      host_status.dart
      transfer_result.dart
    repositories/
      server_repository.dart
      settings_repository.dart
    use_cases/
      add_server_profile.dart
      update_server_profile.dart
      delete_server_profile.dart
      list_server_profiles.dart
      get_server_profile.dart
      set_favorite_server.dart
      start_host.dart
      stop_host.dart
      observe_host_status.dart
      update_language.dart
  features/
    servers/
      presentation/
        server_list_page.dart
        server_detail_page.dart
        server_form_page.dart
        widgets/
          server_card.dart
          host_status_panel.dart
          server_form.dart
      application/
        server_list_controller.dart
        server_detail_controller.dart
        server_form_controller.dart
    options/
      presentation/
        options_page.dart
        widgets/
          language_selector.dart
      application/
        options_controller.dart
    shell/
      presentation/
        home_shell.dart
        bottom_tabs.dart
  services/
    host/
      host_session_manager.dart
      host_session_state.dart
      host_session_events.dart
    discovery/
      lan_discovery_service.dart
      raknet_ping_parser.dart
      raknet_pong_builder.dart
      motd_builder.dart
    bedrock/
      bedrock_server_service.dart
      bedrock_session.dart
      bedrock_packet_codec.dart
      bedrock_login_flow.dart
      resource_pack_flow.dart
      protocol_version.dart
    raknet/
      raknet_server.dart
      raknet_packet_codec.dart
      raknet_session.dart
      raknet_reliability.dart
      raknet_ack_nack.dart
    transfer/
      transfer_service.dart
      transfer_packet_builder.dart
    android/
      android_foreground_service.dart
      android_network_lock.dart
  presentation/
    common/
      widgets/
        app_scaffold.dart
        status_badge.dart
        primary_action_button.dart
        empty_state.dart
      formatters/
        duration_formatter.dart
test/
  unit/
    motd_builder_test.dart
    raknet_ping_parser_test.dart
    transfer_packet_builder_test.dart
    server_repository_test.dart
  integration/
    discovery_socket_test.dart
    host_session_manager_test.dart
  fixtures/
    packets/
android/
  app/
    src/main/
      AndroidManifest.xml
      kotlin/
        ... foreground service integration ...
docs/
  technical-analysis.md
  architecture-and-implementation-plan.md
```

### Verantwortlichkeiten

#### `lib/main.dart`

Startet Flutter, initialisiert Datenbank, Provider und App.

#### `lib/app/`

App-weite Huelle:

- Routing.
- Theme.
- Lokalisierung.
- Root Widget.

#### `lib/core/`

Querschnittsthemen ohne Feature-Abhaengigkeit:

- Fehlerklassen.
- Logging-Typen.
- globale Konstanten.
- Validatoren.
- Protocol-Konfiguration.

#### `lib/data/`

Persistenz und Repository-Implementierungen:

- Hive/SQLite Zugriff.
- Mapping zwischen Datenbankmodellen und Domain-Entities.
- Keine UI.
- Keine UDP-Protokolllogik.

#### `lib/domain/`

Reine Geschaeftslogik:

- Entities.
- Repository-Interfaces.
- Use-Cases.
- Keine Flutter Widgets.
- Keine konkreten Datenbankklassen.

#### `lib/features/`

UI-nahe Feature-Struktur:

- Serverliste.
- Serverdetails.
- Optionen.
- Navigation Shell.

Controller verwenden Use-Cases und stellen UI-State bereit.

#### `lib/services/host/`

Orchestriert aktive Host-Sitzung:

- Start/Stop.
- aktives Serverprofil.
- Statusstream.
- TransferCounter.
- Verbindung zwischen Discovery, Bedrock Server und Transfer.

#### `lib/services/discovery/`

Nur LAN-Discovery:

- Unconnected Ping parsen.
- MOTD bauen.
- Unconnected Pong senden.

#### `lib/services/raknet/`

RakNet-Grundlage:

- Handshake.
- Reliability.
- ACK/NACK.
- Frame Sets.

Dieser Ordner bleibt bewusst getrennt von Bedrock-Paketen.

#### `lib/services/bedrock/`

Bedrock Game Protocol:

- Packet Codec.
- NetworkSettings.
- Login.
- Resource-Pack-Flow.
- PlayStatus.

#### `lib/services/transfer/`

Transfer-Paket:

- Feldkodierung.
- Senden ueber aktive Session.
- Transfer-Ergebnis.

#### `lib/services/android/`

Android-spezifische Laufzeit:

- Foreground Service.
- Notification.
- Netzwerk-/MulticastLock.
- Plattformkanal oder Plugin-Bridge.

## 4. Technische Risiken

| Risiko | Bewertung | Auswirkung | Gegenmassnahme |
|---|---:|---|---|
| Bedrock Versionsaenderungen | Hoch | Login oder Packet-IDs brechen nach Minecraft-Update. | Version-Matrix pflegen, Protocol Config isolieren, Tests mit Fixtures. |
| TransferPacket wird vor Spawn ignoriert | Hoch | MVP-Transfer funktioniert nicht nach Minimal-Login. | Fallback: Minimal-StartGame/Spawn-Pfad implementieren. |
| Konsolenkompatibilitaet | Hoch | Xbox/PlayStation/Switch zeigen LAN-Spiel nicht oder akzeptieren Transfer nicht. | Fruehe manuelle Testmatrix, LAN-MOTD strikt kompatibel halten. |
| Android UDP Broadcast Einschraenkungen | Hoch | Minecraft findet HostConnect nicht. | Foreground Service, MulticastLock, WLAN-Testplan, klare Fehlerlogs. |
| Android Hintergrunddienst-Limits | Mittel | Host stoppt bei Screen-Off oder App-Wechsel. | Foreground Service mit Notification und Lifecycle Tests. |
| Port `19132` belegt | Mittel | Discovery/Server kann nicht starten. | Fehler sichtbar machen, Stop anderer Instanz, spaeter alternativer Port mit Risiko-Hinweis. |
| RakNet ACK/NACK Fehler | Hoch | Verbindung instabil oder Login startet nie. | Kleine testbare RakNet-Schicht, PCAP-Vergleich, Open-Source-Referenzen. |
| Kompression/Framing falsch | Hoch | Bedrock-Pakete werden ignoriert. | Codec-Unit-Tests mit PrismarineJS-/PMMP-Felddefinitionen. |
| Encryption/Handshake-Anforderungen | Mittel | Login bricht bei bestimmten Clients. | Erst offline/minimal testen, dann Encryption-Fallback evaluieren. |
| Zielserver blockiert Transfer | Mittel | Client erreicht Ziel nicht oder wird abgewiesen. | Zuerst lokaler BDS-Test, dann oeffentliche Server testen, Logs trennen zwischen HostConnect und Zielserver. |
| DNS-Aufloesung auf Clientseite | Mittel | Transfer zu Domain funktioniert nicht auf allen Plattformen. | Hostname unveraendert senden, IP-Fallback dokumentieren. |
| Mehrere Clients gleichzeitig | Niedrig fuer MVP, Mittel spaeter | Sessions kollidieren oder Counter falsch. | MVP auf eine Session begrenzen, spaeter Session-Map. |
| Lokale Datenbankmigrationen | Niedrig | gespeicherte Server gehen bei Updates verloren. | Schema-Versionierung, einfache Models. |
| App Store / Plattformrichtlinien | Mittel | Verteilung kann wegen Netzwerk-/Minecraft-Bezug schwierig sein. | Keine Markenverletzung, klare lokale Netzwerkfunktion, keine Mojang-Assets. |
| Rechtliche/ToS-Kompatibilitaet | Mittel | Inoffizielle Protokollnutzung kann problematisch sein. | Keine Auth-Umgehung, keine Markenverwendung im Namen ausser beschreibend, Hinweise dokumentieren. |

## 5. Entwicklungsreihenfolge

Jeder Schritt muss einzeln testbar sein. Code wird erst nach Freigabe dieser Planungsphase geschrieben.

### Schritt 1: Flutter-Projektgeruest

Ergebnis:

- Flutter-App startet.
- Material 3 Dark Theme.
- Zwei Tabs: Server, Optionen.
- Noch kein echtes Netzwerk.

Test:

- `flutter test`.
- App startet auf Android Emulator/Geraet.

### Schritt 2: Lokale Datenbank und Serverprofile

Ergebnis:

- Server speichern, anzeigen, bearbeiten, loeschen.
- Favoriten im Datenmodell.
- Spracheinstellung speicherbar.

Test:

- Repository-Unit-Tests.
- Manuelles Speichern/Neustart/App oeffnen.

### Schritt 3: Host Session Manager mit Fake-Networking

Ergebnis:

- Host starten/stoppen im UI.
- Status Online/Offline.
- Laufzeitzaehler.
- Fake-TransferCounter fuer UI.

Test:

- Controller-Tests.
- Manuelle UI-Pruefung.

### Schritt 4: LAN Discovery Prototyp

Ergebnis:

- UDP Socket auf `19132`.
- Unconnected Ping parsen.
- Pong mit MOTD senden.
- Minecraft zeigt LAN-Spiel.

Test:

- Unit-Test fuer Ping Parser und Pong Builder.
- Lokaler UDP-Test mit Fixture.
- Manuell: Minecraft LAN-Liste pruefen.
- Optional: Wireshark/PCAP.

### Schritt 5: RakNet Minimalserver

Ergebnis:

- Open Connection Request/Reply.
- RakNet Session entsteht.
- ACK/NACK und Frame Sets ausreichend fuer Login-Start.

Test:

- Unit-Tests fuer Packet Codec.
- Integrationstest mit kleinem RakNet-Client oder Minecraft-Client.
- Logs zeigen RakNet-Verbindung.

### Schritt 6: Bedrock NetworkSettings und Login

Ergebnis:

- NetworkSettingsRequest empfangen.
- NetworkSettings senden.
- Login empfangen und dekodieren.
- Resource-Pack-Flow ohne Packs abschliessen.
- PlayStatus(LoginSuccess) senden.

Test:

- Packet Codec Tests.
- Minecraft-Client verbindet bis LoginSuccess.
- Logs zeigen Bedrock Login Ready.

### Schritt 7: Transfer Packet

Ergebnis:

- TransferPacket wird nach LoginSuccess gesendet.
- Zielhost/Zielport kommen aus Serverprofil.
- TransferCounter erhoeht sich.

Test:

- Unit-Test fuer TransferPacket-Felder.
- Manuell: Client wird zu lokalem BDS transferiert.
- Danach Test mit oeffentlichem Server.

### Schritt 8: Android Foreground Service

Ergebnis:

- Host laeuft stabil, wenn App im Hintergrund ist.
- Notification sichtbar.
- Netzwerklock aktiv, falls erforderlich.

Test:

- Screen-Off.
- App-Wechsel.
- Akkuoptimierung Standard.
- Mehrere WLANs/Router.

### Schritt 9: MVP-Haertung

Ergebnis:

- Fehler werden in UI angezeigt.
- Start blockiert bei belegtem Port.
- Sauberer Stop.
- Logs exportierbar oder kopierbar.

Test:

- Port-belegt-Test.
- Netzwerk-Aus-Test.
- Zielhost-unerreichbar-Test.
- Mehrfach Start/Stop.

### Schritt 10: Plattform-Testmatrix

Ergebnis:

- Android Client getestet.
- Windows Client getestet.
- Konsolen soweit verfuegbar getestet.

Test:

- Dokumentierte Ergebnisse pro Plattform:
  - LAN sichtbar
  - Verbindung akzeptiert
  - Transfer erfolgreich
  - Besonderheiten

## 6. Teststrategie

### LAN-Spiel sichtbar

Technische Pruefung:

- UDP-Socket startet ohne Fehler auf `19132`.
- HostConnect empfaengt Unconnected Ping.
- HostConnect sendet Unconnected Pong mit korrekter Magic und MOTD.
- Logs enthalten:
  - `discovery_started`
  - `unconnected_ping_received`
  - `unconnected_pong_sent`

Manuelle Pruefung:

- Minecraft Bedrock oeffnen.
- Tab `Freunde`.
- Bereich `LAN-Spiele`.
- Erwarteter Eintrag: `HostConnect - <Servername>`.

Netzwerk-Pruefung:

- Wireshark/PCAP auf UDP `19132`.
- Ping/Pong vergleichen:
  - Packet ID `0x01` rein.
  - Packet ID `0x1c` raus.
  - Magic stimmt.
  - MOTD-Felder plausibel.

Bestanden wenn:

- Der Eintrag innerhalb von 10 Sekunden sichtbar wird.
- Der Eintrag den richtigen Servernamen zeigt.
- Keine wiederkehrenden Socket-Fehler auftreten.

### Login funktioniert

Technische Pruefung:

- RakNet Handshake vollstaendig.
- `NetworkSettingsRequest` empfangen.
- `NetworkSettings` gesendet.
- `Login` empfangen.
- Resource-Pack-Flow abgeschlossen.
- `PlayStatus(LoginSuccess)` gesendet.

Logs muessen Reihenfolge zeigen:

```text
raknet_open_connection_1
raknet_open_connection_2
raknet_session_created
bedrock_network_settings_request
bedrock_network_settings_sent
bedrock_login_received
bedrock_resource_pack_flow_complete
bedrock_login_success_sent
```

Bestanden wenn:

- Minecraft trennt nicht vor `LoginSuccess`.
- HostConnect meldet `LoginReady`.
- Keine Decoder-Fehler oder unerkannte Pflichtpakete auftreten.

### Transfer funktioniert

Technische Pruefung:

- `TransferPacket` wird nach `LoginReady` gesendet.
- Felder:
  - `address` = Zielhost.
  - `port` = Zielport, little endian unsigned short.
  - `reloadWorld` = Startwert `true`.
- Paket wird ueber aktive Bedrock Session geflusht.

Manuelle Pruefung:

- Ziel 1: lokaler Bedrock Dedicated Server im gleichen LAN.
- Ziel 2: oeffentlicher Server, z. B. gespeichertes Profil.
- Minecraft zeigt nach Klick auf HostConnect den Lade-/Verbindungsprozess zum Zielserver.
- Spieler landet auf Zielserver oder bekommt eine Zielserver-spezifische Fehlermeldung.

Bestanden wenn:

- HostConnect sendet Transfer.
- Client versucht erkennbar die Verbindung zum Zielserver.
- Bei gueltigem Zielserver landet der Spieler reproduzierbar dort.
- TransferCounter steigt erst nach gesendetem Transfer.

### Android kompatibel

Geraetepruefung:

- Android physisches Geraet im WLAN.
- Optional Android Emulator nur fuer UI/Datenbank, nicht als finaler UDP-Broadcast-Beweis.

Pruefungen:

- App frisch installieren.
- Server speichern.
- Host starten.
- Minecraft auf anderem Geraet sieht LAN-Spiel.
- Minecraft auf gleichem Android-Geraet testen, falls moeglich.
- App in Hintergrund senden.
- Bildschirm ausschalten.
- Nach 2, 5 und 10 Minuten erneut LAN-Sichtbarkeit pruefen.

Android-spezifische Logs:

```text
foreground_service_started
notification_visible
wifi_multicast_lock_acquired
udp_socket_bound
foreground_service_stopped
wifi_multicast_lock_released
```

Bestanden wenn:

- UDP-Socket bleibt aktiv.
- Discovery funktioniert im Vordergrund.
- Discovery funktioniert im Hintergrund mit Foreground Service.
- Stop entfernt den LAN-Eintrag nach kurzer Zeit.

## 7. Bibliotheken

### Flutter State Management: Riverpod

Empfehlung:

- `flutter_riverpod`

Begruendung:

- Passt gut zu Clean Architecture.
- Controller/Provider lassen sich einfach testen.
- Streams fuer HostStatus und Logs sind sauber abbildbar.
- Weniger BuildContext-Kopplung als klassische Provider-Nutzung.

### Lokale Datenbank: Hive CE oder Isar/SQLite

Primaere Empfehlung fuer MVP:

- Hive-kompatibler Key-Value Store, falls aktiv gepflegte Variante verfuegbar.

Alternative:

- `sqflite` fuer klassisches SQLite.

Begruendung:

- Datenmodell ist klein.
- Serverprofile und Settings brauchen keine komplexen Relationen.
- SQLite ist robuster fuer lange App-Lebensdauer und Migrationen.
- Hive ist schneller fuer MVP und weniger Boilerplate.

Entscheidung fuer MVP:

- Wenn maximale Einfachheit zaehlt: Hive.
- Wenn langfristige Wartbarkeit zaehlt: SQLite mit `drift`.

Empfohlene finale Wahl:

- `drift` + SQLite, weil Schema, Migrationen und Tests sauberer sind.

### Routing: go_router

Empfehlung:

- `go_router`

Begruendung:

- Stabiler Flutter-Standard fuer deklaratives Routing.
- Gut fuer zwei Tabs plus Detail-/Formseiten.
- Spaeter erweiterbar ohne Architekturbruch.

### Internationalisierung

Empfehlung:

- Flutter `gen_l10n`

Begruendung:

- Offizieller Flutter-Weg.
- Deutsch/Englisch reichen fuer MVP.
- Keine externe Runtime noetig.

### Logging

Empfehlung:

- Eigener strukturierter Logging Service plus optional `logging` Package.

Begruendung:

- HostConnect braucht domaenenspezifische Log-Events, nicht nur Textzeilen.
- UI soll Status aus Events ableiten koennen.
- Spaeter Export als JSON/Text moeglich.

### Android Foreground Service

Empfehlung:

- Flutter Plugin fuer Foreground Service evaluieren, z. B. `flutter_foreground_task`, oder eigene Android/Kotlin-Schicht.

Begruendung:

- UDP-Hosting muss weiterlaufen, wenn UI nicht im Vordergrund ist.
- Eigene Kotlin-Schicht gibt mehr Kontrolle ueber Notification, Lifecycle und MulticastLock.

Empfohlene MVP-Strategie:

- Erst Flutter/Dart-Prototyp im Vordergrund.
- Danach Android-native Foreground-Service-Bridge stabilisieren.

### Netzwerk / UDP

Empfehlung fuer fruehen Prototyp:

- Dart `dart:io` `RawDatagramSocket`.

Begruendung:

- Schnellster Weg fuer Discovery.
- Gut testbar.
- Keine native Bridge fuer erstes LAN-Pong noetig.

Empfehlung fuer RakNet/Bedrock-Core:

- Erst isolierter Dart-Prototyp nur, wenn Umfang klein bleibt.
- Parallel Go/Rust Native-Core evaluieren, falls RakNet in Dart zu instabil wird.

### Open-Source-Wiederverwendung

#### gophertunnel

Empfehlung:

- Als Referenz stark nutzen.
- Direkte Wiederverwendung als Native-Core pruefen.

Moeglicher Einsatz:

- Go-Core fuer Android via gomobile oder native Binary/Library evaluieren.
- Referenz fuer RakNet Listener, Bedrock Login und Transfer.

Bewertung:

- Technisch wertvoll.
- Integration in Flutter/Android ist komplexer als reine Dart-Library.
- Gut als Fallback, wenn eigener Dart-RakNet-Core zu teuer wird.

#### PrismarineJS bedrock-protocol / minecraft-data

Empfehlung:

- Nicht als Runtime in Flutter verwenden.
- Als Daten- und Testreferenz verwenden.

Moeglicher Einsatz:

- Packet-IDs und Feldtypen fuer Version-Matrix.
- Fixture-Generierung fuer Tests.
- Vergleich mit TransferPacket-Definitionen.

Bewertung:

- Sehr wertvoll fuer Versionierung.
- Node.js Runtime passt nicht sauber in Android-Flutter-MVP.

#### PocketMine-MP / BedrockProtocol

Empfehlung:

- Als Packet-Feldreferenz verwenden.
- Nicht direkt in App verwenden.

Moeglicher Einsatz:

- TransferPacket-Felder bestaetigen.
- Login-/PlayStatus-/ResourcePack-Paketdetails vergleichen.

Bewertung:

- Gut lesbare Referenz.
- PHP-Code ist keine sinnvolle Android-Runtime-Komponente.

#### Nukkit / Cloudburst

Empfehlung:

- Als Verhaltenreferenz heranziehen, nicht als Runtime.

Moeglicher Einsatz:

- Vergleich von Server-Login-Flows.
- Hinweise fuer StartGame-Fallback.

Bewertung:

- Nuetzlich, aber Wartungsstand und Versionsnaehe kritisch pruefen.

## Freigabepunkt vor Implementierung

Implementierung sollte erst starten, wenn diese Punkte akzeptiert sind:

- Architektur Minimalserver + Transfer ist bestaetigt.
- MVP-Scope ist bestaetigt.
- Netzwerk-Core darf zunaechst isoliert/prototypisch gebaut werden.
- Erste Zielversion fuer Bedrock-Protokoll ist festgelegt.
- Entscheidung fuer lokale Datenbank ist getroffen: empfohlen `drift`/SQLite.
- Android Foreground Service wird als eigener Schritt nach Discovery/Login geplant.
