package com.monora.monora

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.KeyEvent
import android.widget.RemoteViews
import com.ryanheise.audioservice.MediaButtonReceiver

/**
 * 4x1 home screen widget: app mark, current song, and transport buttons.
 *
 * Buttons never need the Flutter engine to be alive — each one broadcasts a
 * media-button KeyEvent to audio_service's [MediaButtonReceiver], which the
 * foreground service handles exactly like a wired headset click. Only the
 * title/artist/play-pause icon comes from Dart via the `monora/widget`
 * channel, so the widget keeps its last state even when the app is swiped
 * away (and the music keeps playing, as designed).
 */
class MonoraWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) {
            manager.updateAppWidget(id, buildViews(context, "Monora", "Nothing playing", false))
        }
    }

    companion object {
        private const val RC_PREVIOUS = 1001
        private const val RC_PLAY_PAUSE = 1002
        private const val RC_NEXT = 1003

        fun update(context: Context, title: String, artist: String, playing: Boolean) {
            val manager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, MonoraWidgetProvider::class.java)
            manager.updateAppWidget(componentName, buildViews(context, title, artist, playing))
        }

        private fun buildViews(
            context: Context,
            title: String,
            artist: String,
            playing: Boolean,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.monora_widget)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_artist, artist)
            views.setImageViewResource(
                R.id.widget_play,
                if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
            )
            views.setOnClickPendingIntent(
                R.id.widget_previous,
                mediaButton(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS, RC_PREVIOUS),
            )
            views.setOnClickPendingIntent(
                R.id.widget_play,
                mediaButton(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, RC_PLAY_PAUSE),
            )
            views.setOnClickPendingIntent(
                R.id.widget_next,
                mediaButton(context, KeyEvent.KEYCODE_MEDIA_NEXT, RC_NEXT),
            )
            // Opening the widget body lands on the app itself.
            views.setOnClickPendingIntent(
                R.id.widget_root,
                PendingIntent.getActivity(
                    context,
                    0,
                    context.packageManager.getLaunchIntentForPackage(context.packageName),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            return views
        }

        private fun mediaButton(context: Context, keyCode: Int, requestCode: Int): PendingIntent {
            val intent = Intent(context, MediaButtonReceiver::class.java).apply {
                action = Intent.ACTION_MEDIA_BUTTON
                putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
            }
            return PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
