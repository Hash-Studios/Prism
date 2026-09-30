package com.hash.prism

import android.app.DownloadManager
import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.webkit.MimeTypeMap
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
    private val downloadExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    override fun saveMedia(request: SaveMediaRequest, callback: (Result<OperationResult>) -> Unit) {
        runInBackground(callback, { createErrorResult("EXCEPTION", it.message) }) { saveMediaInternal(request) }
    }

    private fun saveMediaInternal(request: SaveMediaRequest): OperationResult {
        val link = request.link
        val isLocalFile = request.isLocalFile
        val kind = request.kind
        var connection: HttpURLConnection? = null
        var input: InputStream? = null
        var downloadedFile: File? = null
        return try {
            val mime: String
            try {
                if (isLocalFile) {
                    val path = if (link.startsWith("file://")) {
                        Uri.parse(link).path ?: throw IOException("Invalid file URI")
                    } else {
                        link
                    }
                    val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    BitmapFactory.decodeFile(path, options)
                    mime = options.outMimeType ?: return createErrorResult(
                        "FAILED_TO_LOAD_BITMAP",
                        "Could not load image from source",
                    )
                    if (!mime.startsWith("image/") || options.outWidth <= 0 || options.outHeight <= 0) {
                        return createErrorResult("FAILED_TO_LOAD_BITMAP", "Could not load image from source")
                    }
                    input = File(path).inputStream()
                } else {
                    val httpConnection = openDownloadConnection(URL(link))
                    connection = httpConnection
                    val responseMime = httpConnection.contentType?.substringBefore(';')?.trim()?.lowercase(Locale.US)
                        ?.takeIf { it.startsWith("image/") }
                    val tempFile = File.createTempFile("prism-media-", ".tmp", context.cacheDir)
                    downloadedFile = tempFile
                    var downloadedBytes = 0L
                    httpConnection.inputStream.use { source ->
                        FileOutputStream(tempFile).use { downloadedBytes = source.copyTo(it) }
                    }
                    val contentLength = httpConnection.contentLengthLong
                    val contentEncoding = httpConnection.contentEncoding
                    val unencoded = contentEncoding.isNullOrBlank() || contentEncoding.trim().equals("identity", ignoreCase = true)
                    if (contentLength >= 0 && unencoded && downloadedBytes != contentLength) {
                        return createErrorResult("FAILED_TO_LOAD_BITMAP", "Incomplete image response")
                    }
                    val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    BitmapFactory.decodeFile(tempFile.path, options)
                    val detectedMime = options.outMimeType
                    if (options.outWidth <= 0 || options.outHeight <= 0 || detectedMime == null) {
                        return createErrorResult("FAILED_TO_LOAD_BITMAP", "Could not load image from source")
                    }
                    val finalUrl = httpConnection.url.toString()
                    val declaredMime = responseMime ?: mimeFromExtension(finalUrl) ?: mimeFromExtension(link)
                    mime = declaredMime?.takeIf { it == detectedMime } ?: detectedMime
                    input = tempFile.inputStream()
                }
            } catch (e: Exception) {
                return createErrorResult("FAILED_TO_LOAD_BITMAP", e.message)
            }

            val folderName = if (kind == SaveMediaKind.SETUP) "Prism Setups" else "Prism"
            val source = input
            input = null
            val saved = source?.use { writeToPictures(it, mime, folderName) } == true

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
            try {
                input?.close()
            } catch (_: Exception) {
            }
            downloadedFile?.delete()
            connection?.disconnect()
        }
    }

    override fun enqueueDownload(request: DownloadRequest, callback: (Result<OperationResult>) -> Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // DownloadManager owns the MediaStore rows it creates, and Prism has no media read permission, so
            // listDownloads could not see them. Writing through MediaStore makes Prism the owner.
            // ponytail: in-process transfer, stops if the app is killed. Move to WorkManager if that matters.
            runInBackground(callback, { createErrorResult("DOWNLOAD_FAILED", it.message) }, executor = downloadExecutor) {
                downloadToMediaStore(request)
            }
        } else {
            callback(Result.success(enqueueDownloadNow(request)))
        }
    }

    private fun downloadToMediaStore(request: DownloadRequest): OperationResult {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, request.filenameWithoutExtension + ".jpg")
            put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/Prism/Downloads")
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: return createErrorResult("DOWNLOAD_FAILED", "Could not create the file")

        var connection: HttpURLConnection? = null
        return try {
            val downloadConnection = openDownloadConnection(URL(request.link))
            connection = downloadConnection
            val output = resolver.openOutputStream(uri) ?: throw IOException("Could not open the file")
            val bytesWritten = output.use { stream ->
                downloadConnection.inputStream.use { input -> input.copyTo(stream) }
            }
            if (bytesWritten == 0L) throw IOException("Downloaded file is empty")
            val updated = resolver.update(uri, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null)
            if (updated != 1) throw IOException("Could not publish the file")
            createSuccessResult()
        } catch (e: Exception) {
            try {
                resolver.delete(uri, null, null)
            } catch (cleanupException: Exception) {
                e.addSuppressed(cleanupException)
                e.printStackTrace()
            }
            createErrorResult("DOWNLOAD_FAILED", e.message)
        } finally {
            connection?.disconnect()
        }
    }

    private fun openDownloadConnection(initialUrl: URL): HttpURLConnection {
        var url = initialUrl
        repeat(MAX_DOWNLOAD_REDIRECTS + 1) { redirectCount ->
            if (url.protocol != "http" && url.protocol != "https") {
                throw IOException("Unsupported download URL protocol")
            }

            val connection = url.openConnection() as HttpURLConnection
            try {
                connection.connectTimeout = DOWNLOAD_CONNECT_TIMEOUT_MS
                connection.readTimeout = DOWNLOAD_READ_TIMEOUT_MS
                connection.instanceFollowRedirects = false

                val responseCode = connection.responseCode
                if (responseCode in REDIRECT_CODES) {
                    val location = connection.getHeaderField("Location")
                        ?: throw IOException("Redirect did not include a location")
                    if (redirectCount == MAX_DOWNLOAD_REDIRECTS) {
                        throw IOException("Too many download redirects")
                    }
                    url = URL(url, location)
                    if (url.protocol != "http" && url.protocol != "https") {
                        throw IOException("Unsupported download redirect protocol")
                    }
                    connection.disconnect()
                } else if (responseCode !in 200..299) {
                    throw IOException("HTTP $responseCode")
                } else {
                    return connection
                }
            } catch (e: Exception) {
                connection.disconnect()
                throw e
            }
        }
        throw IOException("Too many download redirects")
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

    private fun <T> runInBackground(
        callback: (Result<T>) -> Unit,
        onError: (Exception) -> T,
        executor: ExecutorService = ioExecutor,
        task: () -> T,
    ) {
        executor.execute {
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
                val isApi29 = Build.VERSION.SDK_INT == Build.VERSION_CODES.Q
                val projection = arrayOf(
                    MediaStore.Images.Media._ID,
                    MediaStore.Images.Media.DATA,
                    MediaStore.Images.Media.RELATIVE_PATH,
                    MediaStore.Images.Media.DISPLAY_NAME,
                )
                val selection =
                    "(${MediaStore.Images.Media.RELATIVE_PATH} LIKE ? OR ${MediaStore.Images.Media.RELATIVE_PATH} LIKE ?) AND ${MediaStore.Images.Media.IS_PENDING}=0"
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
                    val idCol = cursor.getColumnIndex(MediaStore.Images.Media._ID)
                    val dataCol = cursor.getColumnIndex(MediaStore.Images.Media.DATA)
                    val relCol = cursor.getColumnIndex(MediaStore.Images.Media.RELATIVE_PATH)
                    val nameCol = cursor.getColumnIndex(MediaStore.Images.Media.DISPLAY_NAME)

                    while (cursor.moveToNext()) {
                        var path = if (isApi29 && idCol >= 0) {
                            // Android 10 blocks raw paths to shared media, so Dart gets a private copy.
                            runCatching { cacheDownload(cursor.getLong(idCol)).absolutePath }.getOrNull()
                        } else if (dataCol >= 0) {
                            cursor.getString(dataCol)
                        } else {
                            null
                        }
                        if (!isApi29 && path.isNullOrEmpty()) {
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

            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q && items.isEmpty()) {
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
                    MediaStore.setIncludePending(MediaStore.Images.Media.EXTERNAL_CONTENT_URI),
                    selection,
                    selectionArgs,
                )
            }
        } catch (e: Exception) {
            return createErrorResult("CLEAR_FAILED", e.message)
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            deleted += deleteDirectory(File("storage/emulated/0/Pictures/Prism/Downloads/"))
            deleted += deleteDirectory(File("storage/emulated/0/Prism/Downloads/"))
        } else if (Build.VERSION.SDK_INT == Build.VERSION_CODES.Q) {
            deleteDirectory(File(context.cacheDir, DOWNLOAD_CACHE_DIRECTORY))
        }

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

    private fun cacheDownload(id: Long): File {
        val directory = File(context.cacheDir, DOWNLOAD_CACHE_DIRECTORY)
        if (!directory.exists() && !directory.mkdirs()) throw IOException("Could not create download cache")

        val file = File(directory, "$id.jpg")
        if (file.length() > 0) return file
        val temporaryFile = File(directory, "$id.jpg.part")
        return try {
            val uri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
            val input = context.contentResolver.openInputStream(uri) ?: throw IOException("Could not open the cached file")
            val bytesWritten = input.use { source ->
                FileOutputStream(temporaryFile).use { target -> source.copyTo(target) }
            }
            if (bytesWritten == 0L) throw IOException("Downloaded file is empty")
            if (!temporaryFile.renameTo(file)) throw IOException("Could not cache downloaded file")
            file
        } catch (e: Exception) {
            try {
                temporaryFile.delete()
            } catch (cleanupException: Exception) {
                e.addSuppressed(cleanupException)
            }
            throw e
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
        val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime) ?: "jpg"
        val filename = "default_" + System.currentTimeMillis() + "." + ext

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                    put(MediaStore.MediaColumns.MIME_TYPE, mime)
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + File.separator + folderName)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }

                val imageUri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
                    ?: return false

                try {
                    val out = resolver.openOutputStream(imageUri) ?: throw IOException("No output stream")
                    out.use { input.copyTo(it) }
                    val published = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
                    if (resolver.update(imageUri, published, null, null) != 1) {
                        throw IOException("Could not publish image")
                    }
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
                val imageFile = File(imagesDir, filename)
                try {
                    FileOutputStream(imageFile).use { input.copyTo(it) }
                } catch (e: Exception) {
                    imageFile.delete()
                    throw e
                }
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

    private companion object {
        const val DOWNLOAD_CONNECT_TIMEOUT_MS = 10_000
        const val DOWNLOAD_READ_TIMEOUT_MS = 20_000
        const val MAX_DOWNLOAD_REDIRECTS = 5
        const val DOWNLOAD_CACHE_DIRECTORY = "prism_downloads"
        val REDIRECT_CODES = setOf(
            HttpURLConnection.HTTP_MOVED_PERM,
            HttpURLConnection.HTTP_MOVED_TEMP,
            HttpURLConnection.HTTP_SEE_OTHER,
            307,
            308,
        )
    }
}
