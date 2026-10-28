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
        var copy: File? = null
        var handedOff = false
        try {
            val cache = activity.cacheDir.canonicalFile
            val source = File(imagePath).canonicalFile
            if (!source.isFile || !source.path.startsWith(cache.path + File.separator)) {
                callback(Result.success(false))
                return
            }
            val dir = File(cache, "share_cards").apply { mkdirs() }
            val shareCopy = File.createTempFile("story_", ".png", dir)
            copy = shareCopy
            try {
                source.copyTo(shareCopy, overwrite = true)
            } catch (error: Exception) {
                shareCopy.delete()
                throw error
            }
            val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.wallpaper_crop", shareCopy)
            val intent = storyIntent(target)
                .setDataAndType(uri, target.mimeType)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                .putExtra(target.androidAppIdExtra, target.appId)
            if (activity.packageManager.resolveActivity(intent, 0) == null) {
                shareCopy.delete()
                callback(Result.success(false))
                return
            }
            activity.grantUriPermission(target.androidPackage, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            try {
                activity.startActivityForResult(intent, 0)
            } catch (error: Exception) {
                activity.revokeUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                shareCopy.delete()
                throw error
            }
            handedOff = true
            callback(Result.success(true))
        } catch (error: Exception) {
            if (!handedOff) copy?.delete()
            callback(Result.success(false))
        }
    }

    private fun storyIntent(target: InstagramStoryTarget) = Intent(target.androidAction).setPackage(target.androidPackage)
}
