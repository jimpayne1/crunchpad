#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Builds Crunchpad.app: the upstream SpeedCrunch engine (CMake, QtCore only), the
# SwiftUI front end (SwiftPM), then bundles QtCore and its Homebrew dylibs so
# the app runs on machines without Homebrew.
#
#   macos/build.sh            # release build -> build/Crunchpad.app
#   macos/build.sh --debug    # debug build
#   macos/build.sh --run      # build and launch
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
CONFIG=release
RUN=0
for arg in "$@"; do
    case "$arg" in
        --debug) CONFIG=debug ;;
        --run) RUN=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

QT_PREFIX="${QT_PREFIX:-$(brew --prefix qtbase 2>/dev/null || true)}"
if [[ -z "$QT_PREFIX" || ! -d "$QT_PREFIX/lib/QtCore.framework" ]]; then
    echo "QtCore not found. Install it with: brew install qtbase cmake" >&2
    exit 1
fi

BUILD="$ROOT/build"
APP="$BUILD/Crunchpad.app"
VERSION="$(git -C "$ROOT" describe --tags --always 2>/dev/null || echo dev)"

echo "==> Engine (CMake)"
cmake -S "$HERE/Engine" -B "$BUILD/engine" -G "Unix Makefiles" \
    -DCMAKE_BUILD_TYPE="$([[ $CONFIG == debug ]] && echo Debug || echo Release)" \
    -DCMAKE_PREFIX_PATH="$QT_PREFIX" >/dev/null
cmake --build "$BUILD/engine" --target scengine -j"$(sysctl -n hw.ncpu)"

echo "==> App (SwiftPM)"
export SC_ENGINE_LIB_DIR="$BUILD/engine" SC_QT_LIB_DIR="$QT_PREFIX/lib"
swift build --package-path "$HERE/App" -c "$CONFIG"
BIN="$(swift build --package-path "$HERE/App" -c "$CONFIG" --show-bin-path)/Crunchpad"

echo "==> Bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN" "$APP/Contents/MacOS/Crunchpad"
sed "s/__VERSION__/${VERSION#release-}/g" "$HERE/Resources/Info.plist" > "$APP/Contents/Info.plist"

if [[ ! -f "$BUILD/AppIcon.icns" || "$HERE/Resources/make-icon.swift" -nt "$BUILD/AppIcon.icns" ]]; then
    swift "$HERE/Resources/make-icon.swift" "$BUILD/AppIcon.iconset"
    iconutil -c icns "$BUILD/AppIcon.iconset" -o "$BUILD/AppIcon.icns"
fi
cp "$BUILD/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

FW="$APP/Contents/Frameworks"

# QtCore as a minimal framework.
QTFW="$FW/QtCore.framework"
mkdir -p "$QTFW/Versions/A/Resources"
cp "$QT_PREFIX/lib/QtCore.framework/Versions/A/QtCore" "$QTFW/Versions/A/"
cp "$QT_PREFIX/lib/QtCore.framework/Versions/A/Resources/Info.plist" "$QTFW/Versions/A/Resources/"
ln -s A "$QTFW/Versions/Current"
ln -s Versions/Current/QtCore "$QTFW/QtCore"
ln -s Versions/Current/Resources "$QTFW/Resources"
chmod u+w "$QTFW/Versions/A/QtCore"
install_name_tool -id @rpath/QtCore.framework/Versions/A/QtCore "$QTFW/Versions/A/QtCore" 2>/dev/null

# Copy every non-system dylib reachable from QtCore and point references at
# @rpath (= Contents/Frameworks).
is_external() { [[ "$1" == /opt/homebrew/* || "$1" == /usr/local/* || "$1" == @rpath/lib* ]]; }
resolve() {
    local dep="$1" from="$2"
    if [[ "$dep" == @rpath/* ]]; then
        local name="${dep#@rpath/}"
        for dir in "$(dirname "$from")" /opt/homebrew/lib; do
            [[ -f "$dir/$name" ]] && { echo "$dir/$name"; return; }
        done
    elif [[ "$dep" == @loader_path/* ]]; then
        echo "$(dirname "$from")/${dep#@loader_path/}"
    else
        echo "$dep"
    fi
}
queue=("$QTFW/Versions/A/QtCore")
origins=("$QT_PREFIX/lib/QtCore.framework/Versions/A/QtCore")
while ((${#queue[@]})); do
    target="${queue[0]}"; origin="${origins[0]}"
    queue=("${queue[@]:1}"); origins=("${origins[@]:1}")
    while read -r dep; do
        is_external "$dep" || continue
        src="$(resolve "$dep" "$origin")"
        [[ -n "$src" && -f "$src" ]] || { echo "cannot resolve $dep" >&2; exit 1; }
        name="$(basename "$src")"
        install_name_tool -change "$dep" "@rpath/$name" "$target" 2>/dev/null
        if [[ ! -f "$FW/$name" ]]; then
            cp -L "$src" "$FW/$name"
            chmod u+w "$FW/$name"
            install_name_tool -id "@rpath/$name" "$FW/$name" 2>/dev/null
            install_name_tool -add_rpath @loader_path "$FW/$name" 2>/dev/null || true
            queue+=("$FW/$name"); origins+=("$(realpath "$src")")
        fi
    done < <(otool -L "$target" | tail -n +2 | awk '{print $1}' | grep -v "^$(basename "$target"):")
done
install_name_tool -add_rpath @loader_path/../.. "$QTFW/Versions/A/QtCore" 2>/dev/null || true

# Executable: only look inside the bundle.
install_name_tool -change "$QT_PREFIX/lib/QtCore.framework/Versions/A/QtCore" \
    @rpath/QtCore.framework/Versions/A/QtCore "$APP/Contents/MacOS/Crunchpad" 2>/dev/null || true
install_name_tool -delete_rpath "$QT_PREFIX/lib" "$APP/Contents/MacOS/Crunchpad" 2>/dev/null || true

if otool -L "$APP/Contents/MacOS/Crunchpad" "$FW"/*.dylib "$QTFW/Versions/A/QtCore" | grep -q "/opt/homebrew"; then
    echo "warning: bundle still references Homebrew paths" >&2
fi

echo "==> Sign (ad hoc)"
find "$FW" -name "*.dylib" -exec codesign --force --sign - {} \; 2>/dev/null
codesign --force --sign - "$QTFW" 2>/dev/null
codesign --force --sign - "$APP"

echo "Built $APP ($(du -sh "$APP" | cut -f1))"
[[ $RUN == 1 ]] && open "$APP"
exit 0
