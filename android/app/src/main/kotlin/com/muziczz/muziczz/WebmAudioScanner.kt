package com.muziczz.muziczz

import android.content.ContentUris
import android.content.Context
import android.media.MediaMetadataRetriever
import android.provider.MediaStore
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

object WebmAudioScanner {
    fun scan(context: Context): String {
        val result = JSONArray()
        val collection = MediaStore.Files.getContentUri("external")
        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.DATA,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.DATE_ADDED,
        )
        val selection =
            "${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ? OR " +
                "${MediaStore.Files.FileColumns.MIME_TYPE} = ?"
        val arguments = arrayOf("%.webm", "audio/webm")

        context.contentResolver.query(
            collection,
            projection,
            selection,
            arguments,
            "${MediaStore.Files.FileColumns.DATE_ADDED} DESC",
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
            val nameColumn = cursor.getColumnIndexOrThrow(
                MediaStore.Files.FileColumns.DISPLAY_NAME,
            )
            val dataColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)
            val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
            val dateColumn = cursor.getColumnIndexOrThrow(
                MediaStore.Files.FileColumns.DATE_ADDED,
            )

            while (cursor.moveToNext()) {
                val mediaStoreId = cursor.getLong(idColumn)
                val path = cursor.getString(dataColumn).orEmpty()
                if (path.isEmpty() || !File(path).isFile) continue

                val uri = ContentUris.withAppendedId(collection, mediaStoreId)
                val metadata = MediaMetadataRetriever()
                try {
                    metadata.setDataSource(context, uri)
                    val hasAudio = metadata.extractMetadata(
                        MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO,
                    )
                    val duration = metadata.extractMetadata(
                        MediaMetadataRetriever.METADATA_KEY_DURATION,
                    )?.toLongOrNull() ?: 0L
                    if (hasAudio == "no" || duration <= MIN_MUSIC_DURATION_MS) continue

                    val displayName = cursor.getString(nameColumn).orEmpty()
                    val fallbackTitle = displayName.substringBeforeLast('.', displayName)
                    result.put(JSONObject().apply {
                        put("id", -mediaStoreId - 1L)
                        put(
                            "title",
                            metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE)
                                ?.takeIf { it.isNotBlank() } ?: fallbackTitle,
                        )
                        put(
                            "artist",
                            metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST)
                                ?.takeIf { it.isNotBlank() } ?: "Unknown Artist",
                        )
                        put(
                            "album",
                            metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM)
                                ?.takeIf { it.isNotBlank() } ?: "Unknown Album",
                        )
                        put("albumId", 0)
                        put("artistId", 0)
                        put("data", path)
                        put("duration", duration)
                        put("size", cursor.getLong(sizeColumn))
                        put("track", JSONObject.NULL)
                        put("dateAdded", cursor.getLong(dateColumn) * 1000L)
                    })
                } catch (_: Exception) {
                    // One malformed/unsupported WebM must not abort the library scan.
                } finally {
                    metadata.release()
                }
            }
        }
        return result.toString()
    }

    private const val MIN_MUSIC_DURATION_MS = 30_000L
}
