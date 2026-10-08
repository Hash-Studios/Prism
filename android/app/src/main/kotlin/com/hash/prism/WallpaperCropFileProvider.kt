package com.hash.prism

import androidx.core.content.FileProvider

/** Shares the image for the system crop-and-set flow. A subclass keeps it apart from plugin providers. */
class WallpaperCropFileProvider : FileProvider()
