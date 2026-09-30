#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
activity_file="${1:-$repo_root/android/app/src/main/kotlin/com/hash/prism/MainActivity.kt}"
gradle_cache="${GRADLE_USER_HOME:-$HOME/.gradle-prism}/caches/modules-2/files-2.1"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

find_jar() {
  find "$gradle_cache/$1" -name '*.jar' -print -quit 2>/dev/null
}

compiler="$(find_jar org.jetbrains.kotlin/kotlin-compiler-embeddable/2.3.0)"
stdlib="$(find_jar org.jetbrains.kotlin/kotlin-stdlib/2.3.0)"
script_runtime="$(find_jar org.jetbrains.kotlin/kotlin-script-runtime/2.3.0)"
reflect="$(find_jar org.jetbrains.kotlin/kotlin-reflect/1.6.10)"
daemon="$(find_jar org.jetbrains.kotlin/kotlin-daemon-embeddable/2.3.0)"
coroutines="$(find_jar org.jetbrains.kotlinx/kotlinx-coroutines-core-jvm/1.8.0)"
trove="$(find_jar org.jetbrains.intellij.deps/trove4j/1.0.20200330)"
annotations="$(find_jar org.jetbrains/annotations)"
for dependency in "$compiler" "$stdlib" "$script_runtime" "$reflect" "$daemon" "$coroutines" "$trove" "$annotations"; do
  [[ -n "$dependency" ]] || { echo 'Cached Kotlin 2.3 compiler jars are required.' >&2; exit 1; }
done

mkdir -p "$tmp/src" "$tmp/classes"
activity_source="$(<"$activity_file")"
printf '%s\n' "$activity_source" >"$tmp/src/MainActivity.kt"
cat >"$tmp/src/AndroidOs.kt" <<'EOF'
package android.os

class Bundle

object Build {
    object VERSION {
        var SDK_INT: Int = 24
    }

    object VERSION_CODES {
        const val Q: Int = 29
    }
}
EOF
cat >"$tmp/src/AndroidView.kt" <<'EOF'
package android.view

class View {
    var systemUiVisibility: Int = 0

    companion object {
        const val SYSTEM_UI_FLAG_LAYOUT_STABLE = 0x100
        const val SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION = 0x200
        const val SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN = 0x400
        const val SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR = 0x10
        const val SYSTEM_UI_FLAG_LIGHT_STATUS_BAR = 0x2000
    }
}

class Window {
    val decorView = View()
}
EOF
cat >"$tmp/src/WindowCompat.kt" <<'EOF'
package androidx.core.view

import android.view.Window
import android.view.View

object WindowCompat {
    fun setDecorFitsSystemWindows(window: Window, decorFitsSystemWindows: Boolean) {
        val layoutFlags = View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
        val currentFlags = window.decorView.systemUiVisibility
        window.decorView.systemUiVisibility = if (decorFitsSystemWindows) {
            currentFlags and layoutFlags.inv()
        } else {
            currentFlags or layoutFlags
        }
    }
}
EOF
cat >"$tmp/src/ComponentActivity.kt" <<'EOF'
package androidx.activity

import android.os.Bundle
import android.view.Window
import androidx.core.view.WindowCompat

open class ComponentActivity {
    val window = Window()

    open fun onCreate(savedInstanceState: Bundle?) {}
    open fun onPostResume() {}
}

fun ComponentActivity.enableEdgeToEdge() {
    WindowCompat.setDecorFitsSystemWindows(window, false)
}
EOF
cat >"$tmp/src/FlutterFragmentActivity.kt" <<'EOF'
package io.flutter.embedding.android

import android.os.Bundle
import android.view.View
import androidx.activity.ComponentActivity
import io.flutter.embedding.engine.FlutterEngine

open class FlutterFragmentActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.decorView.systemUiVisibility = DEFAULT_SYSTEM_UI
    }

    override fun onPostResume() {
        // Flutter 3.47.5 PlatformPlugin reapplies DEFAULT_SYSTEM_UI, then the current Dart icon style.
        window.decorView.systemUiVisibility = DEFAULT_SYSTEM_UI or DART_LIGHT_ICON_FLAGS
    }

    open fun configureFlutterEngine(flutterEngine: FlutterEngine) {}

    companion object {
        private const val DEFAULT_SYSTEM_UI =
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        private const val DART_LIGHT_ICON_FLAGS =
            View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
    }
}
EOF
cat >"$tmp/src/FlutterEngine.kt" <<'EOF'
package io.flutter.embedding.engine

class FlutterEngine {
    val dartExecutor = DartExecutor()
}

class DartExecutor {
    val binaryMessenger = Any()
}
EOF
cat >"$tmp/src/PrismPigeon.kt" <<'EOF'
package com.hash.prism.pigeon

object PrismMediaHostApi {
    fun setUp(binaryMessenger: Any, api: Any) {}
}
EOF
cat >"$tmp/src/PrismMediaHostApiImpl.kt" <<'EOF'
package com.hash.prism

class PrismMediaHostApiImpl(context: Any)
EOF
cat >"$tmp/src/EdgeToEdgeLifecycleTest.kt" <<'EOF'
import android.os.Build
import android.os.Bundle
import android.view.View
import com.hash.prism.MainActivity

fun main(args: Array<String>) {
    val sdk = args.single().toInt()
    check(sdk == 24 || sdk == 28) { "Expected API 24 or 28, got $sdk" }
    Build.VERSION.SDK_INT = sdk

    val activity = MainActivity()
    activity.onCreate(Bundle())
    repeat(2) { resume ->
        activity.onPostResume()
        val flags = activity.window.decorView.systemUiVisibility
        check((flags and View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION) != 0) {
            "API $sdk resume ${resume + 1}: nav layout flag was lost: $flags"
        }
        check((flags and View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR) != 0) {
            "API $sdk resume ${resume + 1}: status icon style was lost: $flags"
        }
        check((flags and View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR) != 0) {
            "API $sdk resume ${resume + 1}: nav icon style was lost: $flags"
        }
    }
    println("API $sdk: edge-to-edge and Dart icon flags survive create and repeated resume")
}
EOF

compiler_classpath="$compiler:$stdlib:$script_runtime:$reflect:$daemon:$coroutines:$trove:$annotations"
java -cp "$compiler_classpath" org.jetbrains.kotlin.cli.jvm.K2JVMCompiler \
  -no-stdlib -no-reflect -classpath "$stdlib:$annotations" -d "$tmp/classes" \
  "$tmp/src/AndroidOs.kt" "$tmp/src/AndroidView.kt" "$tmp/src/WindowCompat.kt" \
  "$tmp/src/ComponentActivity.kt" "$tmp/src/FlutterFragmentActivity.kt" \
  "$tmp/src/FlutterEngine.kt" "$tmp/src/PrismPigeon.kt" "$tmp/src/PrismMediaHostApiImpl.kt" \
  "$tmp/src/EdgeToEdgeLifecycleTest.kt" "$tmp/src/MainActivity.kt"

for sdk in 24 28; do
  java -cp "$tmp/classes:$stdlib" EdgeToEdgeLifecycleTestKt "$sdk"
done
