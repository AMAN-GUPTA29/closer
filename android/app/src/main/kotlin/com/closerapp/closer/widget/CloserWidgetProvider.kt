package com.closerapp.closer.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import com.closerapp.closer.R
import org.json.JSONObject
import java.io.File

/**
 * Closer home-screen widget. Every instance is configured independently with
 * one group (see [CloserWidgetConfigureActivity]); several widgets may show
 * different groups, or the same group.
 *
 * Data comes from the Flutter app through home_widget's shared preferences
 * (keys documented in docs/widget-implementation.md). The widget never talks
 * to the network itself.
 */
class CloserWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { render(context, manager, it) }
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        ids.forEach { WidgetConfigStore.clear(context, it) }
    }

    companion object {
        private const val HOME_WIDGET_PREFS = "HomeWidgetPreferences"
        private const val MAX_IMAGE_PX = 600

        /** Redraws widgets showing [groupId], or all widgets when null. */
        fun refresh(context: Context, groupId: String?) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, CloserWidgetProvider::class.java))
            ids.filter { groupId == null || WidgetConfigStore.groupFor(context, it) == groupId }
                .forEach { render(context, manager, it) }
        }

        fun render(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_closer)
            val prefs = context.getSharedPreferences(HOME_WIDGET_PREFS, Context.MODE_PRIVATE)
            val signedIn = prefs.getString("closer.signedIn", null) == "true"
            val groupId = WidgetConfigStore.groupFor(context, widgetId)
            val snapshot = groupId?.let { prefs.getString("closer.group.$it", null) }
                ?.let { runCatching { JSONObject(it) }.getOrNull() }

            when {
                !signedIn -> showMessage(
                    context, views, widgetId,
                    context.getString(R.string.widget_sign_in),
                    openApp(context, widgetId),
                )
                groupId == null -> showMessage(
                    context, views, widgetId,
                    context.getString(R.string.widget_choose_group),
                    configure(context, widgetId),
                )
                snapshot == null -> showMessage(
                    context, views, widgetId,
                    // Access revoked or group deleted: no stale private photo.
                    context.getString(R.string.widget_group_unavailable),
                    configure(context, widgetId),
                )
                else -> showGroup(context, views, widgetId, snapshot)
            }
            manager.updateAppWidget(widgetId, views)
        }

        private fun showGroup(context: Context, views: RemoteViews, widgetId: Int, s: JSONObject) {
            views.setViewVisibility(R.id.widget_message, View.GONE)
            views.setViewVisibility(R.id.widget_content, View.VISIBLE)
            views.setTextViewText(R.id.widget_title, s.optString("name"))
            views.setTextViewText(R.id.widget_subtitle, s.optString("subtitle"))
            views.setViewVisibility(
                R.id.widget_heart,
                if (s.optString("type") == "couple") View.VISIBLE else View.GONE,
            )
            val bitmap = s.optString("imagePath").takeIf { it.isNotEmpty() }?.let { decode(it) }
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_image, bitmap)
            } else {
                views.setImageViewResource(R.id.widget_image, R.drawable.widget_placeholder)
            }
            views.setContentDescription(
                R.id.widget_root,
                "${s.optString("name")}, ${s.optString("subtitle")}",
            )
            val open = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("com.closerapp.closer://group/${s.optString("id")}"),
            ).setPackage(context.packageName)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                PendingIntent.getActivity(
                    context, widgetId, open,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
        }

        private fun showMessage(
            context: Context,
            views: RemoteViews,
            widgetId: Int,
            text: String,
            tap: PendingIntent,
        ) {
            views.setViewVisibility(R.id.widget_content, View.GONE)
            views.setViewVisibility(R.id.widget_message, View.VISIBLE)
            views.setTextViewText(R.id.widget_message, text)
            views.setImageViewResource(R.id.widget_image, R.drawable.widget_placeholder)
            views.setContentDescription(R.id.widget_root, text)
            views.setOnClickPendingIntent(R.id.widget_root, tap)
        }

        private fun openApp(context: Context, widgetId: Int): PendingIntent {
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent()
            return PendingIntent.getActivity(
                context, 10_000 + widgetId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun configure(context: Context, widgetId: Int): PendingIntent {
            val intent = Intent(context, CloserWidgetConfigureActivity::class.java)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            return PendingIntent.getActivity(
                context, 20_000 + widgetId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        /** Downsamples so the bitmap stays well under the RemoteViews limit. */
        private fun decode(path: String): Bitmap? {
            val file = File(path)
            if (!file.exists()) return null
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            var sample = 1
            while (bounds.outWidth / sample > MAX_IMAGE_PX || bounds.outHeight / sample > MAX_IMAGE_PX) {
                sample *= 2
            }
            return BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
        }
    }
}

/** Per-instance configuration: which group each widget id shows. */
object WidgetConfigStore {
    private const val PREFS = "closer_widget_config"

    fun groupFor(context: Context, widgetId: Int): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("widget_$widgetId", null)

    fun set(context: Context, widgetId: Int, groupId: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("widget_$widgetId", groupId).apply()
    }

    fun clear(context: Context, widgetId: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .remove("widget_$widgetId").apply()
    }
}
