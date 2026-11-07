package com.hash.prism

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Receives a share from another app and hands MainActivity a `prism://share-in` deep link. A share opens in the
 * sender's task, so taking it here keeps Prism to one Flutter engine in its own task.
 */
class ShareTargetActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) {
            val source = referrer?.takeIf { it.scheme == "android-app" }?.host
            SharedInbox.linkIntent(this, intent, source)?.let { startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
        }
        finish()
    }
}
