package com.hash.prism

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class MainApplication : Application() {

    companion object {
        const val ENGINE_ID = "prism_main_engine"
    }

    override fun onCreate() {
        super.onCreate()
        // Pre-warm the Flutter engine so Dart's main() starts executing
        // on a background thread while Android sets up the Activity.
        // This overlaps Dart startup (Persistence + Sentry init) with
        // Activity.onCreate(), saving ~50–150ms on cold start.
        val engine = FlutterEngine(this)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }
}
