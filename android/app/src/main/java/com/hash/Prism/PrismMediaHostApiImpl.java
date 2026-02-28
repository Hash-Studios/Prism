package com.hash.prism;

import android.app.DownloadManager;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import android.os.Handler;
import android.os.Looper;
import android.widget.Toast;

import androidx.annotation.NonNull;

import com.hash.prism.pigeon.PrismMediaApi;
import com.hash.prism.pigeon.PrismMediaApi.DownloadRequest;
import com.hash.prism.pigeon.PrismMediaApi.OperationResult;
import com.hash.prism.pigeon.PrismMediaApi.PrismMediaHostApi;
import com.hash.prism.pigeon.PrismMediaApi.SaveMediaKind;
import com.hash.prism.pigeon.PrismMediaApi.SaveMediaRequest;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Objects;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class PrismMediaHostApiImpl implements PrismMediaHostApi {
    private final Context context;
    private final Handler mainHandler;
    private final ExecutorService ioExecutor;

    public PrismMediaHostApiImpl(Context context) {
        this.context = context;
        this.mainHandler = new Handler(Looper.getMainLooper());
        this.ioExecutor = Executors.newSingleThreadExecutor();
    }

    @Override
    @NonNull
    public OperationResult saveMedia(@NonNull SaveMediaRequest request) {
        try {
            return ioExecutor.submit(() -> saveMediaInternal(request)).get();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return createErrorResult("INTERRUPTED", "Save media task interrupted");
        } catch (ExecutionException e) {
            Throwable cause = e.getCause();
            String message = cause != null && cause.getMessage() != null ? cause.getMessage() : e.getMessage();
            return createErrorResult("EXCEPTION", message);
        }
    }

    @NonNull
    private OperationResult saveMediaInternal(@NonNull SaveMediaRequest request) {
        String link = request.getLink();
        boolean isLocalFile = request.getIsLocalFile();
        SaveMediaKind kind = request.getKind();
        try {
            Bitmap bitmap;
            if (isLocalFile) {
                bitmap = loadBitmapFromFile(link);
            } else {
                bitmap = loadBitmapFromUrl(link);
            }

            if (bitmap == null) {
                return createErrorResult("FAILED_TO_LOAD_BITMAP", "Could not load image from source");
            }

            String folderName = (kind == SaveMediaKind.SETUP) ? "Prism Setups" : "Prism";
            boolean saved = saveBitmapToPictures(bitmap, folderName);

            if (saved) {
                showToastOnMainThread("Saved in Pictures/" + folderName + "!");
                return createSuccessResult();
            } else {
                return createErrorResult("SAVE_FAILED", "Failed to save image");
            }
        } catch (Exception e) {
            e.printStackTrace();
            return createErrorResult("EXCEPTION", e.getMessage());
        }
    }

    @Override
    @NonNull
    public OperationResult enqueueDownload(@NonNull DownloadRequest request) {
        String link = request.getLink();
        String filename = request.getFilenameWithoutExtension();

        try {
            DownloadManager dm = (DownloadManager) context.getSystemService(Context.DOWNLOAD_SERVICE);
            if (dm == null) {
                return createErrorResult("DOWNLOAD_MANAGER_UNAVAILABLE", "Download manager not available");
            }

            Uri downloadUri = Uri.parse(link);
            DownloadManager.Request downloadRequest = new DownloadManager.Request(downloadUri);
            downloadRequest.setAllowedNetworkTypes(DownloadManager.Request.NETWORK_WIFI | DownloadManager.Request.NETWORK_MOBILE)
                    .setAllowedOverRoaming(false)
                    .setTitle(filename)
                    .setDescription("Downloading wallpaper")
                    .setMimeType("image/jpeg")
                    .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                    .setDestinationInExternalPublicDir(Environment.DIRECTORY_PICTURES, 
                            File.separator + "Prism" + File.separator + filename + ".jpg");

            dm.enqueue(downloadRequest);
            showToastOnMainThread("Download started");
            return createSuccessResult();
        } catch (Exception e) {
            e.printStackTrace();
            return createErrorResult("DOWNLOAD_FAILED", e.getMessage());
        }
    }

    private Bitmap loadBitmapFromFile(String path) {
        try {
            String resolvedPath = path;
            if (resolvedPath.startsWith("file://")) {
                resolvedPath = resolvedPath.substring(7);
            }
            return BitmapFactory.decodeFile(resolvedPath);
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    private Bitmap loadBitmapFromUrl(String urlString) {
        HttpURLConnection connection = null;
        InputStream inputStream = null;
        try {
            URL url = new URL(urlString);
            connection = (HttpURLConnection) url.openConnection();
            connection.setDoInput(true);
            connection.connect();
            inputStream = connection.getInputStream();
            return BitmapFactory.decodeStream(inputStream);
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        } finally {
            if (inputStream != null) {
                try {
                    inputStream.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
            if (connection != null) {
                connection.disconnect();
            }
        }
    }

    private boolean saveBitmapToPictures(Bitmap bitmap, String folderName) {
        ContentResolver resolver = context.getContentResolver();
        String filename = "default_" + System.currentTimeMillis();

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ContentValues contentValues = new ContentValues();
                contentValues.put(MediaStore.MediaColumns.DISPLAY_NAME, filename + ".jpg");
                contentValues.put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg");
                contentValues.put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + File.separator + folderName);
                Uri imageUri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues);
                if (imageUri == null) {
                    return false;
                }
                OutputStream fos = resolver.openOutputStream(Objects.requireNonNull(imageUri));
                if (fos != null) {
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 100, fos);
                    fos.close();
                }
                return true;
            } else {
                String imagesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES + File.separator + folderName).toString();
                File image = new File(imagesDir, filename + ".jpg");
                FileOutputStream fos = new FileOutputStream(image);
                bitmap.compress(Bitmap.CompressFormat.JPEG, 100, fos);
                fos.close();
                return true;
            }
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    private OperationResult createSuccessResult() {
        return new OperationResult.Builder()
                .setSuccess(true)
                .build();
    }

    private OperationResult createErrorResult(String errorCode, String message) {
        return new OperationResult.Builder()
                .setSuccess(false)
                .setErrorCode(errorCode)
                .setMessage(message)
                .build();
    }

    private void showToastOnMainThread(String message) {
        mainHandler.post(() -> Toast.makeText(context, message, Toast.LENGTH_SHORT).show());
    }
}
