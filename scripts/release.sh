#!/usr/bin/env bash
# OpenBell release pipeline.
#
#   scripts/release.sh appstore   Archive + export a signed .pkg for the Mac App Store
#   scripts/release.sh upload     Archive + upload the build to App Store Connect
#   scripts/release.sh notarize   Archive + export Developer ID app, build DMG, notarize, staple,
#                                 sign it for Sparkle and add it to appcast.xml
#
# Environment:
#   VERSION   marketing version (default: MARKETING_VERSION from project.yml)
#   BUILD     build number, must increase for every upload (default: YYYYMMDDHHMM)
#   NOTARY_PROFILE  notarytool keychain profile (default: OpenBell-notary)
#   DOWNLOAD_URL    where the DMG will be published (default: GitHub release v$VERSION)
#   RELEASE_NOTES   HTML for the appcast entry (default: "<p>OpenBell $VERSION</p>")
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

archive() { # extra args are passed to xcodebuild as build settings
    log "Archiving OpenBell $VERSION ($BUILD)"
    command -v xcodegen >/dev/null && xcodegen generate --quiet
    rm -rf "$ARCHIVE"
    xcodebuild archive \
        -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
        -destination 'generic/platform=macOS' \
        -archivePath "$ARCHIVE" \
        -allowProvisioningUpdates \
        MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" "$@" \
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

# Signs the DMG with the Sparkle EdDSA key from the Keychain and prepends an <item> to appcast.xml.
add_appcast_item() {
    local dmg="$1"
    local sign_update
    sign_update="$(find build ~/Library/Developer/Xcode/DerivedData -path '*artifacts/sparkle/Sparkle/bin/sign_update' -type f 2>/dev/null | head -1)"
    if [[ -z "$sign_update" ]]; then
        echo "sign_update not found; build the project once so SPM downloads Sparkle." >&2
        return 1
    fi

    log "Signing DMG for Sparkle"
    # Prints: sparkle:edSignature="..." length="..."
    local attrs
    attrs="$("$sign_update" "$dmg")"
    local url="${DOWNLOAD_URL:-https://github.com/fordnox/openbell/releases/download/v$VERSION/$(basename "$dmg")}"
    local notes="${RELEASE_NOTES:-<p>OpenBell $VERSION</p>}"
    local min_os
    min_os="$(awk -F'"' '/LSMinimumSystemVersion/ {print $2; exit}' project.yml)"

    local item
    item="    <item>
      <title>Version $VERSION ($BUILD)</title>
      <pubDate>$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$min_os</sparkle:minimumSystemVersion>
      <description><![CDATA[$notes]]></description>
      <enclosure url=\"$url\" type=\"application/octet-stream\" $attrs />
    </item>"

    # Newest first: insert right after <language>.
    ITEM="$item" perl -0pi -e 's#(<language>.*?</language>\n)#$1$ENV{ITEM}\n#' appcast.xml
    log "Added $VERSION ($BUILD) to appcast.xml"
    echo "Next: upload $dmg to $url, then commit and push appcast.xml."
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
    # Fail before the (slow) archive if notarytool can't find its credentials.
    if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
        cat >&2 <<EOF
No usable notarytool credentials for keychain profile "$NOTARY_PROFILE".
Store them once (prompts for an app-specific password from https://account.apple.com):

  xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <your-apple-id> --team-id VBTQQJK27C

Or point NOTARY_PROFILE at an existing profile.
EOF
        exit 1
    fi

    # Developer ID only: adds the sandbox exceptions Sparkle's installer needs.
    archive CODE_SIGN_ENTITLEMENTS=App/OpenBell-DeveloperID.entitlements
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

    add_appcast_item "$DMG"
    ;;

*)
    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
