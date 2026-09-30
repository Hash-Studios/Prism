#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <release.apk>" >&2
  exit 2
fi

apk=$1
analyzer=${APKANALYZER:-apkanalyzer}
if ! command -v "$analyzer" >/dev/null 2>&1; then
  echo "apkanalyzer not found; set APKANALYZER to its path" >&2
  exit 2
fi

require_code() {
  local class=$1
  local pattern=$2
  local description=$3
  local code

  if ! code=$("$analyzer" dex code --class "$class" "$apk" 2>/dev/null); then
    echo "FAIL: cannot inspect $class in $apk" >&2
    exit 1
  fi
  if ! rg -q -- "$pattern" <<<"$code"; then
    echo "FAIL: $description ($class)" >&2
    exit 1
  fi
}

require_code androidx.work.impl.WorkDatabase_Impl \
  '^\.method public constructor <init>\(\)V$' \
  'Room-generated WorkDatabase constructor was removed'

if ! manifest=$("$analyzer" manifest print "$apk" 2>/dev/null); then
  echo "FAIL: cannot inspect manifest in $apk" >&2
  exit 1
fi
registrars=$(sed -nE 's/.*android:name="com\.google\.firebase\.components:([^"]+)".*/\1/p' <<<"$manifest")
if [[ -z $registrars ]]; then
  echo "FAIL: no Firebase component registrars found in APK manifest" >&2
  exit 1
fi
while IFS= read -r registrar; do
  [[ -z $registrar ]] && continue
  require_code "$registrar" '^\.method public constructor <init>\(\)V$' \
    'Firebase registrar needs its reflective no-arg constructor'
done <<<"$registrars"

require_code io.flutter.plugins.GeneratedPluginRegistrant \
  '^\.method public static registerWith\(.*\)V$' \
  'Flutter plugin registrant method was removed or renamed'

for service in MyTileService WotdTileService FavsTileService; do
  require_code "com.hash.prism.$service" '^\.method public constructor <init>\(\)V$' \
    'Manifest-declared Quick Settings tile constructor was removed'
done

require_code com.dexterous.flutterlocalnotifications.models.NotificationDetails \
  '^\.field public payload:Ljava/lang/String;$' \
  'Scheduled-notification Gson payload field was removed or renamed'
require_code com.dexterous.flutterlocalnotifications.models.NotificationDetails \
  '^\.field public scheduleMode:Lcom/dexterous/flutterlocalnotifications/models/ScheduleMode;$' \
  'Scheduled-notification Gson scheduleMode field was removed or renamed'
require_code com.dexterous.flutterlocalnotifications.models.ScheduleMode \
  '^\.field public static final enum exactAllowWhileIdle:' \
  'ScheduleMode enum constant used by valueOf was removed or renamed'
require_code com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver \
  '^\.method public onReceive\(Landroid/content/Context;Landroid/content/Intent;\)V$' \
  'Manifest-declared scheduled-notification receiver was removed'

require_code io.sentry.ndk.SentryNdk \
  '^\.method private static native initSentryNative\(' \
  'Sentry JNI entry point was removed or renamed'
require_code io.sentry.ndk.SentryNdk \
  '^\.method private static native shutdown\(\)V$' \
  'Sentry JNI shutdown entry point was removed or renamed'

if ! strings=$("$analyzer" resources names --type string --config default "$apk" 2>/dev/null); then
  echo "FAIL: cannot inspect string resources in $apk" >&2
  exit 1
fi
if ! drawables=$("$analyzer" resources names --type drawable --config mdpi "$apk" 2>/dev/null); then
  echo "FAIL: cannot inspect drawable resources in $apk" >&2
  exit 1
fi
for resource in ic_feed ic_collections ic_downloads; do
  if ! rg -Fxq -- "$resource" <<<"$drawables"; then
    echo "FAIL: dynamically looked-up Android resource was removed (drawable/$resource)" >&2
    exit 1
  fi
done
if ! rg -Fxq default_web_client_id <<<"$strings"; then
  echo "FAIL: dynamically looked-up Android resource was removed (string/default_web_client_id)" >&2
  exit 1
fi

echo "R8 reflection checks passed: $apk"
