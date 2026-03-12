package com.hash.prism

import android.app.DownloadManager
import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
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
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import java.util.concurrent.ExecutionException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class PrismMediaHostApiImpl(private val context: Context) : PrismMediaHostApi {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    override fun saveMedia(request: SaveMediaRequest): OperationResult {
        return try {
            ioExecutor.submit<OperationResult> { saveMediaInternal(request) }.get()
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
            createErrorResult("INTERRUPTED", "Save media task interrupted")
        } catch (e: ExecutionException) {
            val message = e.cause?.message ?: e.message
            createErrorResult("EXCEPTION", message)
        }
    }

    private fun saveMediaInternal(request: SaveMediaRequest): OperationResult {
        val link = request.link
        val isLocalFile = request.isLocalFile
        val kind = request.kind
        return try {
            val bitmap = if (isLocalFile) {
                loadBitmapFromFile(link)
            } else {
                loadBitmapFromUrl(link)
            }

            if (bitmap == null) {
                return createErrorResult("FAILED_TO_LOAD_BITMAP", "Could not load image from source")
            }

            val folderName = if (kind == SaveMediaKind.SETUP) "Prism Setups" else "Prism"
            val saved = saveBitmapToPictures(bitmap, folderName)

            if (saved) {
                showToastOnMainThread("Saved in Pictures/$folderName!")
                createSuccessResult()
            } else {
                createErrorResult("SAVE_FAILED", "Failed to save image")
            }
        } catch (e: Exception) {
            e.printStackTrace()
            createErrorResult("EXCEPTION", e.message)
        }
    }

    override fun enqueueDownload(request: DownloadRequest): OperationResult {
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
                    File.separator + "Prism" + File.separator + filename + ".jpg",
                )

            dm.enqueue(downloadRequest)
            showToastOnMainThread("Download started")
            createSuccessResult()
        } catch (e: Exception) {
            e.printStackTrace()
            createErrorResult("DOWNLOAD_FAILED", e.message)
        }
    }

    override fun listDownloads(): DownloadItemsResult {
        return try {
            ioExecutor.submit<DownloadItemsResult> { listDownloadsInternal() }.get()
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
            createDownloadItemsError("INTERRUPTED", "List downloads task interrupted")
        } catch (e: ExecutionException) {
            val message = e.cause?.message ?: e.message
            createDownloadItemsError("EXCEPTION", message)
        }
    }

    override fun clearDownloads(): OperationResult {
        return try {
            ioExecutor.submit<OperationResult> { clearDownloadsInternal() }.get()
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
            createErrorResult("INTERRUPTED", "Clear downloads task interrupted")
        } catch (e: ExecutionException) {
            val message = e.cause?.message ?: e.message
            createErrorResult("EXCEPTION", message)
        }
    }

    private fun loadBitmapFromFile(path: String): Bitmap? {
        return try {
            val resolvedPath = if (path.startsWith("file://")) path.substring(7) else path
            BitmapFactory.decodeFile(resolvedPath)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun loadBitmapFromUrl(urlString: String): Bitmap? {
        var connection: HttpURLConnection? = null
        var inputStream: InputStream? = null
        return try {
            val url = URL(urlString)
            connection = url.openConnection() as HttpURLConnection
            connection.doInput = true
            connection.connect()
            inputStream = connection.inputStream
            BitmapFactory.decodeStream(inputStream)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        } finally {
            try {
                inputStream?.close()
            } catch (e: IOException) {
                e.printStackTrace()
            }
            connection?.disconnect()
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
                    Environment.DIRECTORY_PICTURES + "/Prism/%",
                    "Prism/%",
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
                val prismLegacy = File("storage/emulated/0/Prism/")
                val prismPictures = File("storage/emulated/0/Pictures/Prism/")
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
                    Environment.DIRECTORY_PICTURES + "/Prism/%",
                    "Prism/%",
                )
                deleted += context.contentResolver.delete(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    selection,
                    selectionArgs,
                )
            }
        } catch (_: Exception) {
        }

        deleted += deleteDirectory(File("storage/emulated/0/Pictures/Prism/"))
        deleted += deleteDirectory(File("storage/emulated/0/Prism/"))

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

    private fun saveBitmapToPictures(bitmap: Bitmap, folderName: String): Boolean {
        val resolver: ContentResolver = context.contentResolver
        val filename = "default_" + System.currentTimeMillis()

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, "$filename.jpg")
                    put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + File.separator + folderName)
                }

                val imageUri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
                    ?: return false

                resolver.openOutputStream(imageUri)?.use { fos ->
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 100, fos)
                }
                true
            } else {
                val imagesDir = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_PICTURES + File.separator + folderName,
                ).toString()
                val image = File(imagesDir, "$filename.jpg")
                FileOutputStream(image).use { fos ->
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 100, fos)
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
}
