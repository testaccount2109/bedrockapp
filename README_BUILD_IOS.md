# iOS Build

Dieses Projekt wurde als Flutter-App erkannt. Es war bereits ein Android-Target vorhanden, aber kein iOS-Target. Deshalb wurde die native Flutter-iOS-Ausgabe ergaenzt statt ein WebView-, Capacitor- oder React-Native-Wrapper zu verwenden.

Das iOS-Target liegt unter `ios/` und nutzt den Bundle Identifier `de.hostconnect.app`.

## GitHub Actions

Der Workflow `.github/workflows/build-ios.yml` startet manuell ueber `workflow_dispatch`. Er laeuft auf einem macOS-Runner, installiert Flutter/CocoaPods, baut die iOS-App und laedt am Ende eine IPA als Artifact `hostconnect-ios-ipa` hoch.

Ohne Apple-Signing-Secrets erzeugt der Workflow `HostConnect-unsigned.ipa`. Mit vollstaendigen Apple-Secrets erzeugt er eine signierte `HostConnect.ipa` und legt die verwendete `ExportOptions.plist` als zweites Artifact ab.

## Benötigte GitHub Secrets für signierte IPAs

- `APPLE_CERTIFICATE_BASE64`: Base64-kodierte `.p12`-Datei mit iOS Distribution oder Development Certificate.
- `APPLE_CERTIFICATE_PASSWORD`: Passwort der `.p12`-Datei.
- `APPLE_PROVISIONING_PROFILE_BASE64`: Base64-kodiertes `.mobileprovision` Provisioning Profile fuer `de.hostconnect.app`.
- `APPLE_TEAM_ID`: Apple Developer Team ID.
- `APPLE_KEYCHAIN_PASSWORD`: Frei waehlbares Passwort fuer den temporaeren CI-Keychain.

Wenn eines dieser Secrets fehlt, baut die Pipeline absichtlich unsigniert.

Wichtig: HostConnect nutzt UDP Broadcast fuer Bedrock LAN Discovery. Signierte iOS-Builds benoetigen deshalb ein Provisioning Profile, das die Apple-Entitlement `com.apple.developer.networking.multicast` enthaelt. Ohne dieses Profil kann Xcode die App nicht korrekt fuer Broadcast/Multicast signieren.

## Manuell lokal auf macOS bauen

```bash
flutter pub get
cd ios
pod install --repo-update
cd ..
flutter build ios --release --no-codesign
mkdir -p build/ios-ci/unsigned-ipa/Payload
cp -R build/ios/iphoneos/Runner.app build/ios-ci/unsigned-ipa/Payload/
cd build/ios-ci/unsigned-ipa
zip -qry ../HostConnect-unsigned.ipa Payload
```

## Unsigned IPA mit AltStore oder Sideloadly signieren

1. Workflow ausfuehren und das Artifact `hostconnect-ios-ipa` herunterladen.
2. Die Datei `HostConnect-unsigned.ipa` lokal entpacken oder direkt in AltStore/Sideloadly auswaehlen.
3. Mit einer Apple ID signieren lassen.
4. Die signierte App auf ein registriertes iPhone installieren.

Hinweis: Kostenlos signierte Apps laufen ueblicherweise nur wenige Tage und muessen danach erneut signiert werden. Fuer laengere Laufzeiten wird ein Apple Developer Account mit passendem Provisioning Profile empfohlen.

## Wichtige Dateien

- `ios/Runner.xcodeproj`: Xcode-Projekt.
- `ios/Runner.xcworkspace`: Workspace fuer CocoaPods.
- `ios/Runner/Assets.xcassets/AppIcon.appiconset`: App Icons.
- `ios/Runner/Base.lproj/LaunchScreen.storyboard`: Launch Screen.
- `scripts/build_ios_ci.sh`: Build- und Signing-Logik fuer GitHub Actions.
- `.github/workflows/build-ios.yml`: Automatischer IPA-Workflow.
