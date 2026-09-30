package com.hash.prism.pigeon

data class OperationResult(
    val success: Boolean,
    val errorCode: String? = null,
    val message: String? = null,
)
data class DownloadItemsResult(
    val success: Boolean,
    val items: List<String>,
    val errorCode: String? = null,
    val message: String? = null,
)
data class DownloadRequest(val link: String, val filenameWithoutExtension: String)
data class SaveMediaRequest(val link: String, val isLocalFile: Boolean, val kind: SaveMediaKind)
enum class SaveMediaKind { wallpaper, SETUP }
interface PrismMediaHostApi {
    fun saveMedia(request: SaveMediaRequest, callback: (Result<OperationResult>) -> Unit)
    fun enqueueDownload(request: DownloadRequest, callback: (Result<OperationResult>) -> Unit)
    fun listDownloads(callback: (Result<DownloadItemsResult>) -> Unit)
    fun clearDownloads(callback: (Result<OperationResult>) -> Unit)
}
