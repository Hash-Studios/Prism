package com.hash.prism

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import android.webkit.MimeTypeMap
import android.widget.Toast
import com.hash.prism.pigeon.DownloadItemsResult
import com.hash.prism.pigeon.DownloadRequest
import com.hash.prism.pigeon.OperationResult
import com.hash.prism.pigeon.PrismMediaHostApi
import com.hash.prism.pigeon.SaveMediaKind
import com.hash.prism.pigeon.SaveMediaRequest
import java.io.File
import java.io.IOException
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

internal class PrismMediaHostApiImpl(
    context: Context,
    requestStoragePermission: ((Boolean) -> Unit) -> Unit,
) : PrismMediaHostApi, AutoCloseable {
    private val context = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private var requestStoragePermission: (((Boolean) -> Unit) -> Unit)? = requestStoragePermission
    @Volatile private var closed = false
    private val executor = ThreadPoolExecutor(1, 1, 0, TimeUnit.SECONDS, ArrayBlockingQueue<Runnable>(2))

    override fun saveMedia(request: SaveMediaRequest, callback: (Result<OperationResult>) -> Unit) {
        withWritePermission(callback) {
            runInBackground(callback, { operationError("SAVE_FAILED", it) }) {
                withImage(request.link, request.isLocalFile) { image ->
                    val folder = if (request.kind == SaveMediaKind.SETUP) "Prism Setups" else "Prism"
                    publish(image, folder, "prism_${UUID.randomUUID()}")
                    mainHandler.post { Toast.makeText(context, "Saved in Pictures/$folder!", Toast.LENGTH_SHORT).show() }
                    OperationResult(success = true)
                }
            }
        }
    }

    override fun enqueueDownload(request: DownloadRequest, callback: (Result<OperationResult>) -> Unit) {
        try {
            PrismImageTransfer.validateFilename(request.filenameWithoutExtension)
        } catch (error: IllegalArgumentException) {
            callback(Result.success(operationError("INVALID_FILENAME", error)))
            return
        }
        withWritePermission(callback) {
            // ponytail: in-process transfer; use WorkManager if downloads must survive process death.
            runInBackground(callback, { operationError("DOWNLOAD_FAILED", it) }) {
                withImage(request.link, false) { image ->
                    publish(image, DOWNLOAD_FOLDER, request.filenameWithoutExtension)
                    OperationResult(success = true)
                }
            }
        }
    }

    private fun withWritePermission(callback: (Result<OperationResult>) -> Unit, task: () -> Unit) {
        if (closed) {
            callback(Result.success(OperationResult(success = false, errorCode = "ENGINE_DETACHED", message = ENGINE_DETACHED_MESSAGE)))
            return
        }
        if (hasStorageAccess()) task() else requestStoragePermission?.invoke { granted ->
            if (granted) task() else callback(Result.success(OperationResult(
                success = false,
                errorCode = "STORAGE_PERMISSION_REQUIRED",
                message = "Allow storage access to save wallpapers on this Android version",
            )))
        }
    }

    private fun hasStorageAccess(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ||
        context.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED

    private data class Image(val file: File, val mime: String, val extension: String)

    private fun <T> withImage(link: String, isLocal: Boolean, task: (Image) -> T): T {
        val uri = Uri.parse(link)
        val staged = !isLocal || uri.scheme == "content"
        val file = if (!staged) {
            require(uri.scheme == null || uri.scheme == "file") { "Unsupported local image URI" }
            require(uri.scheme != "file" || uri.authority.isNullOrEmpty() || uri.authority == "localhost") { "File URI must be local" }
            require(uri.scheme != null || File(link).isAbsolute) { "Local image path must be absolute" }
            File(if (uri.scheme == "file") uri.path ?: throw IOException("Invalid local image URI") else link)
        } else File.createTempFile("prism-image-", ".tmp", context.cacheDir)
        try {
            if (!isLocal) PrismImageTransfer.download(link, file)
            else if (staged) {
                copyFromUri(context, uri, file)
            }
            val mime = PrismImageValidation.mime(file)
            val extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime) ?: throw IOException("Unsupported image type")
            return task(Image(file, mime, extension))
        } finally {
            if (staged && !file.delete() && file.exists()) Log.w(TAG, "Could not remove staged image")
        }
    }

    private fun publish(image: Image, folder: String, basename: String) {
        check(!closed) { ENGINE_DETACHED_MESSAGE }
        val filename = "$basename.${image.extension}"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = context.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                put(MediaStore.MediaColumns.MIME_TYPE, image.mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/$folder/")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) ?: throw IOException("Could not create image")
            try {
                val output = resolver.openOutputStream(uri) ?: throw IOException("Could not open image")
                output.use { copyImage(image.file, it) }
                if (resolver.update(uri, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null) != 1) {
                    throw IOException("Could not publish image")
                }
            } catch (error: Exception) {
                try { resolver.delete(uri, null, null) } catch (cleanup: Exception) { error.addSuppressed(cleanup) }
                throw error
            }
        } else {
            val directory = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), folder)
            if (!directory.isDirectory && !directory.mkdirs()) throw IOException("Could not create image directory")
            var target = File(directory, filename)
            var suffix = 1
            while (target.exists()) target = File(directory, "$basename (${suffix++}).${image.extension}")
            try {
                target.outputStream().use { copyImage(image.file, it) }
                MediaScannerConnection.scanFile(context, arrayOf(target.absolutePath), arrayOf(image.mime), null)
            } catch (error: Exception) {
                if (!target.delete() && target.exists()) Log.w(TAG, "Could not remove incomplete image")
                throw error
            }
        }
    }

    override fun listDownloads(callback: (Result<DownloadItemsResult>) -> Unit) {
        runInBackground(callback, {
            DownloadItemsResult(success = false, items = emptyList(), errorCode = mediaFailureCode("LIST_FAILED", it), message = mediaFailureMessage(it))
        }) {
            check(hasStorageAccess()) { "Storage access is required to read legacy downloads" }
            val items = mutableListOf<String>()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val projection = arrayOf(MediaStore.Images.Media._ID, MediaStore.Images.Media.DISPLAY_NAME, MediaStore.Images.Media.DATA)
                context.contentResolver.query(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI, projection,
                    "$DOWNLOAD_SELECTION AND ${MediaStore.Images.Media.IS_PENDING}=0", downloadSelectionArgs,
                    "${MediaStore.Images.Media.DATE_ADDED} DESC",
                )?.use { cursor ->
                    val id = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
                    val name = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
                    val path = cursor.getColumnIndex(MediaStore.Images.Media.DATA)
                    while (cursor.moveToNext()) {
                        val direct = if (Build.VERSION.SDK_INT > Build.VERSION_CODES.Q && path >= 0) cursor.getString(path) else null
                        if (!direct.isNullOrEmpty() && File(direct).canRead()) items.add(direct)
                        else items.add(cacheDownload(cursor.getLong(id), cursor.getString(name)).absolutePath)
                    }
                } ?: throw IOException("Could not query downloads")
            } else {
                legacyDownloadDirectories().forEach { directory ->
                    directory.listFiles()?.filter { it.isFile && isImageName(it.name) }?.sortedByDescending { it.lastModified() }
                        ?.forEach { items.add(it.absolutePath) }
                }
            }
            DownloadItemsResult(success = true, items = items)
        }
    }

    override fun clearDownloads(callback: (Result<OperationResult>) -> Unit) {
        runInBackground(callback, { operationError("CLEAR_FAILED", it) }) {
            check(hasStorageAccess()) { "Storage access is required to clear legacy downloads" }
            var deleted = 0
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                deleted = context.contentResolver.delete(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    "$DOWNLOAD_SELECTION AND ${MediaStore.Images.Media.IS_PENDING}=0", downloadSelectionArgs)
                File(context.cacheDir, DOWNLOAD_CACHE_DIRECTORY).listFiles()?.forEach { idDirectory ->
                    if (!idDirectory.deleteRecursively()) throw IOException("Could not remove download cache")
                }
            } else {
                legacyDownloadDirectories().forEach { directory ->
                    directory.listFiles()?.filter { it.isFile && isImageName(it.name) }?.forEach {
                        if (!it.delete()) throw IOException("Could not delete downloaded image")
                        deleted++
                        MediaScannerConnection.scanFile(context, arrayOf(it.absolutePath), null, null)
                    }
                }
            }
            if (deleted > 0) OperationResult(success = true)
            else OperationResult(success = false, errorCode = "NO_DOWNLOADS", message = "No downloads found")
        }
    }

    override fun deleteDownload(path: String, callback: (Result<OperationResult>) -> Unit) {
        runInBackground(callback, { operationError("DELETE_FAILED", it) }) {
            check(hasStorageAccess()) { "Storage access is required to delete downloads" }
            val deleted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) deleteMediaStoreDownload(path) else deleteLegacyDownload(path)
            if (deleted) OperationResult(success = true)
            else OperationResult(success = false, errorCode = "NOT_FOUND", message = "Download not found")
        }
    }

    private fun deleteMediaStoreDownload(path: String): Boolean {
        val resolver = context.contentResolver
        val cacheRoot = File(context.cacheDir, DOWNLOAD_CACHE_DIRECTORY).canonicalFile
        val cached = File(path).canonicalFile
        val idDirectory = cached.parentFile
        val id = idDirectory?.name?.toLongOrNull()
        val deleted = if (idDirectory != null && id != null && idDirectory.parentFile == cacheRoot) {
            val rows = resolver.delete(
                ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id),
                "$DOWNLOAD_SELECTION AND ${MediaStore.Images.Media.IS_PENDING}=0", downloadSelectionArgs,
            )
            if (!idDirectory.deleteRecursively()) throw IOException("Could not remove download cache")
            rows
        } else {
            resolver.delete(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                "$DOWNLOAD_SELECTION AND ${MediaStore.Images.Media.IS_PENDING}=0 AND ${MediaStore.Images.Media.DATA}=?",
                downloadSelectionArgs + path,
            )
        }
        return deleted > 0
    }

    private fun deleteLegacyDownload(path: String): Boolean {
        val file = File(path).canonicalFile
        val inDownloads = legacyDownloadDirectories().any { it.canonicalFile == file.parentFile }
        require(inDownloads && isImageName(file.name)) { "Not a download" }
        if (!file.exists()) return false
        if (!file.delete()) throw IOException("Could not delete downloaded image")
        MediaScannerConnection.scanFile(context, arrayOf(file.absolutePath), null, null)
        return true
    }

    private fun cacheDownload(id: Long, name: String): File {
        PrismImageTransfer.validateStoredFilename(name)
        val directory = File(context.cacheDir, "$DOWNLOAD_CACHE_DIRECTORY/$id")
        if (!directory.isDirectory && !directory.mkdirs()) throw IOException("Could not create download cache")
        val file = File(directory, name)
        if (file.length() > 0) return file
        val temporary = File.createTempFile("image-", ".part", directory)
        try {
            val uri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
            copyFromUri(context, uri, temporary)
            if (!temporary.renameTo(file)) throw IOException("Could not cache download")
            return file
        } finally { temporary.delete() }
    }

    private fun <T> runInBackground(callback: (Result<T>) -> Unit, onError: (Exception) -> T, task: () -> T) {
        try {
            executor.execute {
                val result = try {
                    check(!closed) { ENGINE_DETACHED_MESSAGE }
                    // ponytail: a process-wide lock serializes engine reattachments; split by storage scope if throughput matters.
                    synchronized(storageLock) {
                        check(!closed) { ENGINE_DETACHED_MESSAGE }
                        task()
                    }
                } catch (error: Exception) { onError(error) }
                mainHandler.post { callback(Result.success(result)) }
            }
        } catch (error: RejectedExecutionException) {
            val failure = if (closed) IllegalStateException(ENGINE_DETACHED_MESSAGE) else error
            callback(Result.success(onError(failure)))
        }
    }

    override fun close() {
        closed = true
        requestStoragePermission = null
        executor.shutdownNow().forEach { it.run() }
    }

    private companion object {
        const val TAG = "PrismMedia"
        const val DOWNLOAD_CACHE_DIRECTORY = "prism_downloads"
        val storageLock = Any()
        const val DOWNLOAD_SELECTION = "(${MediaStore.Images.Media.RELATIVE_PATH}=? OR ${MediaStore.Images.Media.RELATIVE_PATH}=?)"
        val downloadSelectionArgs = arrayOf("Pictures/$DOWNLOAD_FOLDER/", "$DOWNLOAD_FOLDER/")
    }
}

private const val DOWNLOAD_FOLDER = "Prism/Downloads"
private const val ENGINE_DETACHED_MESSAGE = "App engine detached"

private fun legacyDownloadDirectories() = listOf(
    File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), DOWNLOAD_FOLDER),
    File(Environment.getExternalStorageDirectory(), DOWNLOAD_FOLDER),
)

private fun isImageName(name: String) =
    name.substringAfterLast('.', "").lowercase() in setOf("jpg", "jpeg", "png", "webp", "gif", "heic", "heif", "avif")

private fun copyImage(file: File, output: OutputStream) {
    file.inputStream().use { PrismImageTransfer.copy(it, output) }
}

private fun copyFromUri(context: Context, uri: Uri, file: File) {
    val input = context.contentResolver.openInputStream(uri) ?: throw IOException("Could not read image")
    input.use { source -> file.outputStream().use { PrismImageTransfer.copy(source, it) } }
}

internal fun mediaFailureCode(fallback: String, error: Exception): String =
    if (error is RejectedExecutionException) "MEDIA_BUSY" else fallback

internal fun mediaFailureMessage(error: Exception): String? =
    if (error is RejectedExecutionException) "Another media operation is in progress. Please try again." else error.message

private fun operationError(code: String, error: Exception) =
    OperationResult(success = false, errorCode = mediaFailureCode(code, error), message = mediaFailureMessage(error))
