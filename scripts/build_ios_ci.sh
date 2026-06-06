#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-HostConnect}"
SCHEME="${IOS_SCHEME:-Runner}"
WORKSPACE="${IOS_WORKSPACE:-ios/Runner.xcworkspace}"
PROJECT="${IOS_PROJECT:-ios/Runner.xcodeproj}"
CONFIGURATION="${IOS_CONFIGURATION:-Release}"
EXPORT_METHOD="${IOS_EXPORT_METHOD:-development}"
BUILD_DIR="${BUILD_DIR:-build/ios-ci}"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
UNSIGNED_IPA_DIR="$BUILD_DIR/unsigned-ipa"
UNSIGNED_IPA="$BUILD_DIR/${APP_NAME}-unsigned.ipa"
SIGNED_IPA="$EXPORT_PATH/$APP_NAME.ipa"
ARTIFACT_DIR="${ARTIFACT_DIR:-build/ios-artifacts}"
EXPORT_OPTIONS_PLIST="$BUILD_DIR/ExportOptions.plist"

mkdir -p "$BUILD_DIR" "$ARTIFACT_DIR"

has_signing=false
if [[ -n "${APPLE_CERTIFICATE_BASE64:-}" && -n "${APPLE_CERTIFICATE_PASSWORD:-}" && -n "${APPLE_PROVISIONING_PROFILE_BASE64:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_KEYCHAIN_PASSWORD:-}" ]]; then
  has_signing=true
fi

echo "Fetching Flutter dependencies"
flutter pub get

if [[ -d ios ]]; then
  echo "Installing CocoaPods dependencies"
  (cd ios && pod install --repo-update)
fi

if [[ "$has_signing" == "true" ]]; then
  echo "Apple signing material detected; building signed IPA"

  KEYCHAIN_PATH="$RUNNER_TEMP/ios-build.keychain-db"
  CERTIFICATE_PATH="$RUNNER_TEMP/apple_certificate.p12"
  PROFILE_PATH="$RUNNER_TEMP/profile.mobileprovision"

  echo "$APPLE_CERTIFICATE_BASE64" | base64 --decode > "$CERTIFICATE_PATH"
  echo "$APPLE_PROVISIONING_PROFILE_BASE64" | base64 --decode > "$PROFILE_PATH"

  security create-keychain -p "$APPLE_KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
  security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
  security unlock-keychain -p "$APPLE_KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
  security import "$CERTIFICATE_PATH" -P "$APPLE_CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
  security list-keychain -d user -s "$KEYCHAIN_PATH"
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$APPLE_KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

  mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
  PROFILE_PLIST="$(security cms -D -i "$PROFILE_PATH")"
  PROFILE_UUID="$(/usr/libexec/PlistBuddy -c 'Print UUID' /dev/stdin <<< "$PROFILE_PLIST")"
  PROFILE_NAME="$(/usr/libexec/PlistBuddy -c 'Print Name' /dev/stdin <<< "$PROFILE_PLIST")"
  cp "$PROFILE_PATH" "$HOME/Library/MobileDevice/Provisioning Profiles/$PROFILE_UUID.mobileprovision"

  cat > "$EXPORT_OPTIONS_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>$EXPORT_METHOD</string>
  <key>teamID</key>
  <string>$APPLE_TEAM_ID</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>de.hostconnect.app</key>
    <string>$PROFILE_NAME</string>
  </dict>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>compileBitcode</key>
  <false/>
</dict>
</plist>
PLIST

  flutter build ios --release --no-codesign --build-name="${FLUTTER_BUILD_NAME:-0.1.0}" --build-number="${FLUTTER_BUILD_NUMBER:-1}"

  xcodebuild archive \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
    PROVISIONING_PROFILE_SPECIFIER="$PROFILE_NAME" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGNING_ALLOWED=YES

  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

  if [[ ! -f "$SIGNED_IPA" ]]; then
    found_ipa="$(find "$EXPORT_PATH" -maxdepth 1 -name '*.ipa' -print -quit)"
    [[ -n "$found_ipa" ]] || { echo "Signed IPA was not produced"; exit 1; }
    cp "$found_ipa" "$SIGNED_IPA"
  fi

  cp "$SIGNED_IPA" "$ARTIFACT_DIR/$APP_NAME.ipa"
  cp "$EXPORT_OPTIONS_PLIST" "$ARTIFACT_DIR/ExportOptions.plist"
else
  echo "No complete Apple signing secrets detected; building unsigned IPA"

  flutter build ios --release --no-codesign --build-name="${FLUTTER_BUILD_NAME:-0.1.0}" --build-number="${FLUTTER_BUILD_NUMBER:-1}"

  APP_PATH="build/ios/iphoneos/Runner.app"
  [[ -d "$APP_PATH" ]] || { echo "Expected $APP_PATH to exist"; exit 1; }

  rm -rf "$UNSIGNED_IPA_DIR"
  mkdir -p "$UNSIGNED_IPA_DIR/Payload"
  cp -R "$APP_PATH" "$UNSIGNED_IPA_DIR/Payload/"
  (cd "$UNSIGNED_IPA_DIR" && zip -qry "../$(basename "$UNSIGNED_IPA")" Payload)

  cp "$UNSIGNED_IPA" "$ARTIFACT_DIR/$APP_NAME-unsigned.ipa"
fi

ls -lah "$ARTIFACT_DIR"
