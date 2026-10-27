package com.hash.prism

import android.app.Activity
import android.content.Intent
import androidx.core.content.FileProvider
import com.hash.prism.pigeon.InstagramStoryTarget
import com.hash.prism.pigeon.PrismShareHostApi
import java.io.File

/** Opens Instagram's story composer with a rendered share card as the background. */
internal class PrismShareHostApiImpl(private val activity: Activity) : PrismShareHostApi {
    override fun canShareInstagramStory(target: InstagramStoryTarget): Boolean =
        activity.packageManager.resolveActivity(storyIntent(target).setType(target.mimeType), 0) != null

    override fun shareInstagramStory(target: InstagramStoryTarget, imagePath: String, callback: (Result<Boolean>) -> Unit) {
        try {
            val cache = activity.cacheDir.canonicalFile
            val source = File(imagePath).canonicalFile
            if (!source.isFile || !source.path.startsWith(cache.path + File.separator)) {
                callback(Result.success(false))
                return
            }
            val dir = File(cache, "share_cards").apply { mkdirs() }
            val copy = source.copyTo(File(dir, "story.png"), overwrite = true)
            val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.wallpaper_crop", copy)
            val intent = storyIntent(target)
                .setDataAndType(uri, target.mimeType)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                .putExtra(target.androidAppIdExtra, target.appId)
            if (activity.packageManager.resolveActivity(intent, 0) == null) {
                callback(Result.success(false))
                return
            }
            activity.grantUriPermission(target.androidPackage, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            activity.startActivityForResult(intent, 0)
            callback(Result.success(true))
        } catch (error: Exception) {
            callback(Result.success(false))
        }
    }

    private fun storyIntent(target: InstagramStoryTarget) = Intent(target.androidAction).setPackage(target.androidPackage)
}
