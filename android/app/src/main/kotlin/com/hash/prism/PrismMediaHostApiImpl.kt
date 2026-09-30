package com.hash.prism

import android.app.DownloadManager
import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.widget.Toast
import com.hash.prism.pigeon.DownloadItemsResult
import com.hash.prism.pigeon.DownloadRequest
import com.hash.prism.pigeon.OperationResult
import com.hash.prism.pigeon.PrismMediaHostApi
import com.hash.prism.pigeon.SaveMediaKind
import com.hash.prism.pigeon.SaveMediaRequest
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class PrismMediaHostApiImpl(private val context: Context) : PrismMediaHostApi {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    override fun saveMedia(request: SaveMediaRequest, callback: (Result<OperationResult>) -> Unit) {
        runInBackground(callback, { createErrorResult("EXCEPTION", it.message) }) { saveMediaInternal(request) }
    }

    private fun saveMediaInternal(request: SaveMediaRequest): OperationResult {
        val link = request.link
        val isLocalFile = request.isLocalFile
        val kind = request.kind
        var connection: HttpURLConnection? = null
        return try {
            val input: InputStream
            val mime: String?
            if (isLocalFile) {
                val path = if (link.startsWith("file://")) link.substring(7) else link
                val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(path, options)
                mime = options.outMimeType
                if (mime == null || !mime.startsWith("image/")) {
                    return createErrorResult("FAILED_TO_LOAD_BITMAP", "Could not load image from source")
                }
                input = File(path).inputStream()
            } else {
                connection = URL(link).openConnection() as HttpURLConnection
                connection.connectTimeout = 30_000
                connection.readTimeout = 30_000
                connection.instanceFollowRedirects = true
                val code = connection.responseCode
                if (code !in 200..299) {
                    return createErrorResult("FAILED_TO_LOAD_BITMAP", "HTTP $code")
                }
                mime = connection.contentType?.substringBefore(';')?.trim()?.lowercase(Locale.US)
                    ?.takeIf { it.startsWith("image/") }
                    ?: mimeFromExtension(link)
                if (mime == null || !mime.startsWith("image/")) {
                    return createErrorResult("FAILED_TO_LOAD_BITMAP", "Could not load image from source")
                }
                input = connection.inputStream
            }

            val folderName = if (kind == SaveMediaKind.SETUP) "Prism Setups" else "Prism"
            val saved = input.use { writeToPictures(it, mime, folderName) }

            if (saved) {
                showToastOnMainThread("Saved in Pictures/$folderName!")
                createSuccessResult()
            } else {
                createErrorResult("SAVE_FAILED", "Failed to save image")
            }
        } catch (e: Exception) {
            e.printStackTrace()
            createErrorResult("EXCEPTION", e.message)
        } finally {
            connection?.disconnect()
        }
    }

    override fun enqueueDownload(request: DownloadRequest, callback: (Result<OperationResult>) -> Unit) {
        callback(Result.success(enqueueDownloadNow(request)))
    }

    private fun enqueueDownloadNow(request: DownloadRequest): OperationResult {
        val link = request.link
        val filename = request.filenameWithoutExtension

        return try {
            val dm = context.getSystemService(Context.DOWNLOAD_SERVICE) as? DownloadManager
                ?: return createErrorResult("DOWNLOAD_MANAGER_UNAVAILABLE", "Download manager not available")

            val downloadUri = Uri.parse(link)
            val downloadRequest = DownloadManager.Request(downloadUri)
                .setAllowedNetworkTypes(DownloadManager.Request.NETWORK_WIFI or DownloadManager.Request.NETWORK_MOBILE)
                .setAllowedOverRoaming(false)
                .setTitle(filename)
                .setDescription("Downloading wallpaper")
                .setMimeType("image/jpeg")
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                .setDestinationInExternalPublicDir(
                    Environment.DIRECTORY_PICTURES,
                    File.separator + "Prism" + File.separator + "Downloads" + File.separator + filename + ".jpg",
                )

            dm.enqueue(downloadRequest)
            showToastOnMainThread("Download started")
            createSuccessResult()
        } catch (e: Exception) {
            e.printStackTrace()
            createErrorResult("DOWNLOAD_FAILED", e.message)
        }
    }

    override fun listDownloads(callback: (Result<DownloadItemsResult>) -> Unit) {
        runInBackground(callback, { createDownloadItemsError("EXCEPTION", it.message) }) { listDownloadsInternal() }
    }

    override fun clearDownloads(callback: (Result<OperationResult>) -> Unit) {
        runInBackground(callback, { createErrorResult("EXCEPTION", it.message) }) { clearDownloadsInternal() }
    }

    private fun <T> runInBackground(callback: (Result<T>) -> Unit, onError: (Exception) -> T, task: () -> T) {
        ioExecutor.execute {
            val result = try {
                task()
            } catch (e: Exception) {
                onError(e)
            }
            mainHandler.post { callback(Result.success(result)) }
        }
    }

    private fun listDownloadsInternal(): DownloadItemsResult {
        return try {
            val items = ArrayList<String>()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val projection = arrayOf(
                    MediaStore.Images.Media.DATA,
                    MediaStore.Images.Media.RELATIVE_PATH,
                    MediaStore.Images.Media.DISPLAY_NAME,
                )
                val selection = "${MediaStore.Images.Media.RELATIVE_PATH} LIKE ? OR ${MediaStore.Images.Media.RELATIVE_PATH} LIKE ?"
                val selectionArgs = arrayOf(
                    Environment.DIRECTORY_PICTURES + "/Prism/Downloads/%",
                    "Prism/Downloads/%",
                )

                context.contentResolver.query(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    projection,
                    selection,
                    selectionArgs,
                    MediaStore.Images.Media.DATE_ADDED + " DESC",
                )?.use { cursor ->
                    val dataCol = cursor.getColumnIndex(MediaStore.Images.Media.DATA)
                    val relCol = cursor.getColumnIndex(MediaStore.Images.Media.RELATIVE_PATH)
                    val nameCol = cursor.getColumnIndex(MediaStore.Images.Media.DISPLAY_NAME)

                    while (cursor.moveToNext()) {
                        var path = if (dataCol >= 0) cursor.getString(dataCol) else null
                        if (path.isNullOrEmpty()) {
                            val rel = if (relCol >= 0) cursor.getString(relCol) else null
                            val name = if (nameCol >= 0) cursor.getString(nameCol) else null
                            if (!rel.isNullOrEmpty() && !name.isNullOrEmpty()) {
                                path = Environment.getExternalStorageDirectory().toString() + "/" + rel + name
                            }
                        }

                        if (!path.isNullOrEmpty()) {
                            items.add(path)
                        }
                    }
                }
            }

            if (items.isEmpty()) {
                val prismLegacy = File("storage/emulated/0/Prism/Downloads/")
                val prismPictures = File("storage/emulated/0/Pictures/Prism/Downloads/")
                appendFiles(items, prismPictures)
                appendFiles(items, prismLegacy)
            }

            DownloadItemsResult(success = true, items = items)
        } catch (e: Exception) {
            createDownloadItemsError("LIST_FAILED", e.message)
        }
    }

    private fun clearDownloadsInternal(): OperationResult {
        var deleted = 0
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val selection = "${MediaStore.Images.Media.RELATIVE_PATH} LIKE ? OR ${MediaStore.Images.Media.RELATIVE_PATH} LIKE ?"
                val selectionArgs = arrayOf(
                    Environment.DIRECTORY_PICTURES + "/Prism/Downloads/%",
                    "Prism/Downloads/%",
                )
                deleted += context.contentResolver.delete(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    selection,
                    selectionArgs,
                )
            }
        } catch (_: Exception) {
        }

        deleted += deleteDirectory(File("storage/emulated/0/Pictures/Prism/Downloads/"))
        deleted += deleteDirectory(File("storage/emulated/0/Prism/Downloads/"))

        return if (deleted > 0) {
            createSuccessResult()
        } else {
            createErrorResult("NO_DOWNLOADS", "No downloads found to delete")
        }
    }

    private fun appendFiles(out: MutableList<String>, directory: File) {
        try {
            val list = directory.listFiles() ?: return
            for (file in list) {
                if (file.isFile) {
                    val lower = file.name.lowercase(Locale.US)
                    if (lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.endsWith(".png") || lower.endsWith(".webp")) {
                        out.add(file.absolutePath)
                    }
                }
            }
        } catch (_: Exception) {
        }
    }

    private fun deleteDirectory(directory: File): Int {
        var deleted = 0
        try {
            val list = directory.listFiles()
            if (list != null) {
                for (file in list) {
                    if (file.isDirectory) {
                        deleted += deleteDirectory(file)
                    } else if (file.delete()) {
                        deleted += 1
                    }
                }
            }
            directory.delete()
        } catch (_: Exception) {
        }
        return deleted
    }

    // Some CDNs serve images as application/octet-stream.
    private fun mimeFromExtension(link: String): String? {
        return when (Uri.parse(link).lastPathSegment?.substringAfterLast('.', "")?.lowercase(Locale.US)) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "webp" -> "image/webp"
            "gif" -> "image/gif"
            else -> null
        }
    }

    private fun writeToPictures(input: InputStream, mime: String, folderName: String): Boolean {
        val resolver: ContentResolver = context.contentResolver
        val ext = when (mime) {
            "image/png" -> "png"
            "image/webp" -> "webp"
            "image/gif" -> "gif"
            else -> "jpg"
        }
        val filename = "default_" + System.currentTimeMillis() + "." + ext

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                    put(MediaStore.MediaColumns.MIME_TYPE, mime)
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + File.separator + folderName)
                }

                val imageUri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
                    ?: return false

                try {
                    val out = resolver.openOutputStream(imageUri) ?: throw IOException("No output stream")
                    out.use { input.copyTo(it) }
                    true
                } catch (e: Exception) {
                    resolver.delete(imageUri, null, null)
                    throw e
                }
            } else {
                val imagesDir = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_PICTURES + File.separator + folderName,
                )
                imagesDir.mkdirs()
                FileOutputStream(File(imagesDir, filename)).use { input.copyTo(it) }
                true
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun createSuccessResult(): OperationResult {
        return OperationResult(success = true)
    }

    private fun createErrorResult(errorCode: String, message: String?): OperationResult {
        return OperationResult(success = false, errorCode = errorCode, message = message)
    }

    private fun createDownloadItemsError(errorCode: String, message: String?): DownloadItemsResult {
        return DownloadItemsResult(success = false, items = emptyList(), errorCode = errorCode, message = message)
    }

    private fun showToastOnMainThread(message: String) {
        mainHandler.post { Toast.makeText(context, message, Toast.LENGTH_SHORT).show() }
    }
}
