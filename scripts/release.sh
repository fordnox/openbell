#!/usr/bin/env bash
# OpenBell release pipeline.
#
#   scripts/release.sh appstore   Archive + export a signed .pkg for the Mac App Store
#   scripts/release.sh upload     Archive + upload the build to App Store Connect
#   scripts/release.sh notarize   Archive + export Developer ID app, build DMG, notarize, staple
#
# Environment:
#   VERSION   marketing version (default: MARKETING_VERSION from project.yml)
#   BUILD     build number, must increase for every upload (default: YYYYMMDDHHMM)
#   NOTARY_PROFILE  notarytool keychain profile (default: OpenBell-notary)
#
# Signing uses the Apple account signed into Xcode (team VBTQQJK27C);
# -allowProvisioningUpdates lets Xcode create certificates/profiles as needed.
set -euo pipefail

cd "$(dirname "$0")/.."

CMD="${1:-}"
SCHEME="OpenBell"
PROJECT="OpenBell.xcodeproj"
OUT="build/release"
ARCHIVE="$OUT/OpenBell.xcarchive"
VERSION="${VERSION:-$(awk -F'"' '/MARKETING_VERSION/ {print $2; exit}' project.yml)}"
BUILD="${BUILD:-$(date +%Y%m%d%H%M)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-OpenBell-notary}"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

archive() {
    log "Archiving OpenBell $VERSION ($BUILD)"
    command -v xcodegen >/dev/null && xcodegen generate --quiet
    rm -rf "$ARCHIVE"
    xcodebuild archive \
        -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
        -destination 'generic/platform=macOS' \
        -archivePath "$ARCHIVE" \
        -allowProvisioningUpdates \
        MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" \
        | xcbeautify_or_cat
}

export_archive() { # $1 = options plist, $2 = output dir
    log "Exporting with $(basename "$1")"
    rm -rf "$2"
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE" \
        -exportOptionsPlist "$1" \
        -exportPath "$2" \
        -allowProvisioningUpdates \
        | xcbeautify_or_cat
}

xcbeautify_or_cat() {
    if command -v xcbeautify >/dev/null; then xcbeautify --quiet; else grep -E 'error|warning: .*(sign|provision)|\*\* .* \*\*' || true; fi
}

case "$CMD" in
appstore)
    archive
    export_archive Release/ExportOptions-AppStore.plist "$OUT/appstore"
    log "App Store package ready: $OUT/appstore/OpenBell.pkg"
    echo "Upload it with: scripts/release.sh upload   (or drag it into Transporter.app)"
    ;;

upload)
    archive
    tmp="$(mktemp -t openbell-export).plist"
    sed 's#<string>export</string>#<string>upload</string>#' Release/ExportOptions-AppStore.plist > "$tmp"
    export_archive "$tmp" "$OUT/upload"
    rm -f "$tmp"
    log "Uploaded build $BUILD to App Store Connect."
    echo "It appears under TestFlight / the app's build list after processing (5–30 min)."
    ;;

notarize)
    archive
    export_archive Release/ExportOptions-DeveloperID.plist "$OUT/developer-id"
    APP="$OUT/developer-id/OpenBell.app"
    DMG="$OUT/OpenBell-$VERSION.dmg"

    log "Building DMG"
    stage="$(mktemp -d)"
    cp -R "$APP" "$stage/"
    ln -s /Applications "$stage/Applications"
    rm -f "$DMG"
    hdiutil create -volname "OpenBell" -srcfolder "$stage" -ov -format UDZO "$DMG" >/dev/null
    rm -rf "$stage"

    IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ {print $2; exit}')"
    if [[ -n "$IDENTITY" ]]; then
        codesign --sign "$IDENTITY" --timestamp "$DMG"
    else
        # The app inside is already Developer ID signed (Xcode cloud signing);
        # an unsigned DMG still notarizes and staples fine.
        echo "No local 'Developer ID Application' certificate; leaving the DMG itself unsigned."
    fi

    log "Submitting to Apple notary service (profile: $NOTARY_PROFILE)"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

    log "Stapling ticket"
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
    spctl --assess --type open --context context:primary-signature -v "$DMG"

    log "Notarized DMG ready: $DMG"
    ;;

*)
    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
