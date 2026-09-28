#!/bin/bash
# Manual APK builder for Hisab — no Gradle.
# The sandbox kills all TCP from JVM processes, so Gradle's client<->daemon
# handshake can never work here. This script replicates what the Flutter
# Gradle plugin does, using only local tools:
#   flutter assemble (Dart AOT, pure Dart) -> aapt2/javac/d8/zipalign/apksigner
# Repeatable: just re-run for every update.
set -euo pipefail

export JAVA_HOME="$HOME/jdk"
export ANDROID_HOME="$HOME/android-sdk"
export ANDROID_SDK_ROOT="$HOME/android-sdk"
export GRADLE_USER_HOME="$HOME/.gradle"
export PATH="$HOME/flutter/bin:$HOME/jdk/bin:$PATH"

APP_DIR="$HOME/workspace/hisab"
BUILD="$APP_DIR/build/manual"
AOT="$BUILD/aot"
BT="$ANDROID_HOME/build-tools/35.0.0"
AAPT_BT="$ANDROID_HOME/build-tools/34.0.0"
ANDROID_JAR="$ANDROID_HOME/platforms/android-34/android.jar"
FLUTTER_JAR="$HOME/flutter/bin/cache/artifacts/engine/android-arm64-release/flutter.jar"
PKG="com.hisab.finance"
VERSION_CODE=7
VERSION_NAME="1.2.3"
# Persistent signing key: build/manual is wiped at step 1/9, so the keystore
# lives in manual_build/ and is copied into the build tree for signing.
KEYSTORE_SRC="$APP_DIR/manual_build/hisab.keystore"

echo "==> 0/9 fetch deps (dl.google.com maven + repo1 for kotlin)"
mkdir -p "$APP_DIR/manual_build/libs"
(
  cd "$APP_DIR/manual_build/libs"
  B="https://dl.google.com/dl/android/maven2"
  dl() { [ -s "$2" ] || curl -sSL -o "$2" "$B/$1"; }
  dl "androidx/annotation/annotation/1.3.0/annotation-1.3.0.jar" annotation-1.3.0.jar
  dl "androidx/lifecycle/lifecycle-common/2.7.0/lifecycle-common-2.7.0.jar" lifecycle-common-2.7.0.jar
  [ -s kotlin-stdlib-1.9.24.jar ] || curl -sSL -o kotlin-stdlib-1.9.24.jar \
    "https://repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-stdlib/1.9.24/kotlin-stdlib-1.9.24.jar"
)
# AndroidX AARs (classes.jar extracted) — the Flutter embedding needs these
# at RUNTIME on the launch path: lifecycle-runtime (LifecycleRegistry, which
# FlutterActivity instantiates in its constructor — missing it = instant
# "keeps stopping" crash), core (ContextCompat/ViewCompat/WindowInsetsCompat
# used by FlutterView), activity (OnBackPressedDispatcher), window +
# window-java (WindowInfoTracker used by FlutterView), tracing (Trace).
# NOTE: these ship as .aar, not .jar.
(
  cd "$APP_DIR/manual_build/libs/aar"
  B="https://dl.google.com/dl/android/maven2"
  aar() {
    local n="$1" p="$2"
    [ -s "$n.aar" ] || curl -sSL -o "$n.aar" "$B/$p.aar"
    if [ ! -s "$n/classes.jar" ]; then
      mkdir -p "$n" && ( cd "$n" && unzip -q -o "../$n.aar" classes.jar )
    fi
  }
  aar "lifecycle-runtime-2.7.0" "androidx/lifecycle/lifecycle-runtime/2.7.0/lifecycle-runtime-2.7.0"
  aar "core-1.12.0"             "androidx/core/core/1.12.0/core-1.12.0"
  aar "activity-1.8.2"          "androidx/activity/activity/1.8.2/activity-1.8.2"
  aar "window-1.2.0"            "androidx/window/window/1.2.0/window-1.2.0"
  aar "window-java-1.2.0"       "androidx/window/window-java/1.2.0/window-java-1.2.0"
  aar "tracing-1.2.0"           "androidx/tracing/tracing/1.2.0/tracing-1.2.0"
)
# build-tools 35 (d8 8.4.x; 34.0.0's d8 crashes on flutter.jar classes)
if [ ! -x "$ANDROID_HOME/build-tools/35.0.0/d8" ]; then
  echo "    fetching build-tools 35..."
  mkdir -p /tmp/bt35dl && cd /tmp/bt35dl
  curl -sSL -o bt35.zip "https://dl.google.com/android/repository/build-tools_r35-rc1-linux.zip"
  unzip -q -o bt35.zip
  mkdir -p "$ANDROID_HOME/build-tools/35.0.0"
  cp -r android-VanillaIceCream/* "$ANDROID_HOME/build-tools/35.0.0/"
  cd "$APP_DIR"
fi

echo "==> 1/9 clean + flutter pub get + assemble (Dart AOT)"
rm -rf "$BUILD"
mkdir -p "$BUILD"
cd "$APP_DIR"
flutter pub get >/dev/null 2>&1
flutter assemble --output="$AOT" \
  -dTargetPlatform=android-arm64 \
  -dBuildMode=release \
  android_aot_bundle_release_android-arm64 2>&1 | tail -2
test -f "$AOT/arm64-v8a/app.so" || { echo "FATAL: app.so missing"; exit 1; }
echo "    app.so OK: $(du -h "$AOT/arm64-v8a/app.so" | cut -f1)"

echo "==> 2/9 manifest"
mkdir -p "$BUILD/manifest"
sed -e 's|\${applicationName}|android.app.Application|' \
    -e 's|<manifest |<manifest package="com.hisab.finance" |' \
    "$APP_DIR/android/app/src/main/AndroidManifest.xml" \
    > "$BUILD/manifest/AndroidManifest.xml"
grep -q 'package="com.hisab.finance"' "$BUILD/manifest/AndroidManifest.xml"

echo "==> 3/9 java sources"
SRC="$BUILD/src/com/hisab/finance"
mkdir -p "$SRC"
cat > "$SRC/MainActivity.java" <<'EOF'
package com.hisab.finance;
import io.flutter.embedding.android.FlutterActivity;
public class MainActivity extends FlutterActivity {}
EOF
cat > "$SRC/GeneratedPluginRegistrant.java" <<'EOF'
package com.hisab.finance;
import io.flutter.embedding.engine.FlutterEngine;
/** No native plugins in this build: path_provider is FFI-based,
 *  firebase plugins stay dormant (Dart try/catch -> local-only mode). */
public final class GeneratedPluginRegistrant {
  public static void registerWith(FlutterEngine flutterEngine) {}
}
EOF

echo "==> 4/9 aapt2 compile res + link (base apk + R.java)"
mkdir -p "$BUILD/gen" "$BUILD/apkbase" "$BUILD/res_compiled"
"$BT/aapt2" compile --dir "$APP_DIR/android/app/src/main/res" \
  -o "$BUILD/res_compiled/compiled_res.zip" 2>&1 | grep -vi "^$" || true
"$BT/aapt2" link -o "$BUILD/apkbase/base.apk" \
  -I "$ANDROID_JAR" \
  -R "$BUILD/res_compiled/compiled_res.zip" \
  --auto-add-overlay \
  --manifest "$BUILD/manifest/AndroidManifest.xml" \
  --min-sdk-version 23 --target-sdk-version 34 \
  --version-code "$VERSION_CODE" --version-name "$VERSION_NAME" \
  --java "$BUILD/gen" 2>&1 | grep -vi "^$" || true
test -f "$BUILD/apkbase/base.apk"

echo "==> 5/9 extract flutter embedding + androidx classes"
mkdir -p "$BUILD/flutter_classes" "$BUILD/androidx_classes"
cd "$BUILD/flutter_classes"
unzip -q -o "$FLUTTER_JAR" 'io/flutter/**/*.class'
cd "$BUILD/androidx_classes"
for j in "$APP_DIR/manual_build/libs"/*.jar; do
  unzip -q -o "$j" '*.class' -x 'META-INF/*'
done
for j in "$APP_DIR/manual_build/libs"/aar/*/classes.jar; do
  unzip -q -o "$j" '*.class' -x 'META-INF/*'
done
cd "$APP_DIR"

echo "==> 6/9 javac + d8"
mkdir -p "$BUILD/classes" "$BUILD/dex"
CP="$FLUTTER_JAR:$ANDROID_JAR:$(ls "$APP_DIR/manual_build/libs"/*.jar | tr '\n' ':')"
"$JAVA_HOME/bin/javac" -nowarn \
  -cp "$CP" \
  -d "$BUILD/classes" \
  $(find "$BUILD/gen" "$SRC" -name "*.java")
"$BT/d8" --release --min-api 23 \
  --lib "$ANDROID_JAR" \
  --output "$BUILD/dex" \
  $(find "$BUILD/classes" "$BUILD/flutter_classes" "$BUILD/androidx_classes" -name "*.class") \
  > "$BUILD/d8.log" 2>&1 || { tail -20 "$BUILD/d8.log"; echo "FATAL: d8 failed"; exit 1; }
grep -v "^Type .* was not found" "$BUILD/d8.log" | tail -5
test -f "$BUILD/dex/classes.dex" && echo "    classes.dex OK"

echo "==> 7/9 assemble apk tree"
rm -rf "$BUILD/apk" && mkdir -p "$BUILD/apk/lib/arm64-v8a" "$BUILD/apk/assets/flutter_assets"
cd "$BUILD/apk"
unzip -q -o "$BUILD/apkbase/base.apk" -x 'META-INF/*'
cp "$BUILD/dex/classes.dex" ./classes.dex
cp "$AOT/arm64-v8a/app.so" ./lib/arm64-v8a/libapp.so
unzip -q -p "$FLUTTER_JAR" 'lib/arm64-v8a/libflutter.so' > ./lib/arm64-v8a/libflutter.so
# strip debug info (engine ships unstripped: 158M -> ~12M)
python3 "$APP_DIR/manual_build/strip_so.py" \
  ./lib/arm64-v8a/libflutter.so ./lib/arm64-v8a/libflutter.so.tmp
mv ./lib/arm64-v8a/libflutter.so.tmp ./lib/arm64-v8a/libflutter.so
python3 "$APP_DIR/manual_build/strip_so.py" \
  ./lib/arm64-v8a/libapp.so ./lib/arm64-v8a/libapp.so.tmp
mv ./lib/arm64-v8a/libapp.so.tmp ./lib/arm64-v8a/libapp.so
# NOTE: engine requires assets under assets/flutter_assets/
cp -r "$AOT/flutter_assets/." ./assets/flutter_assets/
ls lib/arm64-v8a/ && ls assets/flutter_assets/ && du -sh .

echo "==> 8/9 zip + zipalign"
cd "$BUILD/apk"
# .so files MUST be stored uncompressed for page alignment
"$BT/zipalign" >/dev/null 2>&1 || true
zip -q -X -0 "$BUILD/unsigned.apk" lib/arm64-v8a/libflutter.so lib/arm64-v8a/libapp.so
zip -q -X -9 -r "$BUILD/unsigned.apk" AndroidManifest.xml resources.arsc res assets classes.dex
"$BT/zipalign" -p -f 4 "$BUILD/unsigned.apk" "$BUILD/aligned.apk" && echo "    zipalign OK"

echo "==> 9/9 sign"
KS="$BUILD/hisab.keystore"
if [ -f "$KEYSTORE_SRC" ]; then
  cp "$KEYSTORE_SRC" "$KS"
elif [ ! -f "$KS" ]; then
  "$JAVA_HOME/bin/keytool" -genkeypair -keystore "$KS" \
    -alias hisab -keyalg RSA -keysize 2048 -validity 10950 \
    -storepass hisab123 -keypass hisab123 \
    -dname "CN=Hisab, OU=Personal, O=Personal, C=PK" 2>/dev/null
  cp "$KS" "$KEYSTORE_SRC"
fi
OUT="$APP_DIR/build/hisab-v1.2.2.apk"
mkdir -p "$APP_DIR/build"
"$BT/apksigner" sign --ks "$BUILD/hisab.keystore" \
  --ks-pass=pass:hisab123 --key-pass=pass:hisab123 \
  --out "$OUT" "$BUILD/aligned.apk"
"$BT/apksigner" verify --print-certs "$OUT" | head -4
echo ""
echo "APK READY: $OUT ($(du -h "$OUT" | cut -f1))"
"$BT/aapt" dump badging "$OUT" 2>/dev/null | head -3 || true
