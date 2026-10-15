package com.closerapp.closer.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.ListView
import android.widget.TextView
import com.closerapp.closer.R
import org.json.JSONArray

/**
 * Lets the user pick which group a newly added (or reconfigured) widget shows.
 * The list comes from the groups the app last synced, so no network or
 * credentials are needed here.
 */
class CloserWidgetConfigureActivity : Activity() {

    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    private data class GroupItem(val id: String, val name: String, val type: String)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Backing out cancels adding the widget.
        setResult(RESULT_CANCELED)
        widgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        setContentView(R.layout.widget_configure)

        val groups = loadGroups()
        val list = findViewById<ListView>(R.id.configure_list)
        val empty = findViewById<TextView>(R.id.configure_empty)
        if (groups.isEmpty()) {
            list.visibility = View.GONE
            empty.visibility = View.VISIBLE
            return
        }
        list.adapter = object : BaseAdapter() {
            override fun getCount() = groups.size
            override fun getItem(position: Int) = groups[position]
            override fun getItemId(position: Int) = position.toLong()
            override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
                val view = convertView ?: LayoutInflater.from(parent.context)
                    .inflate(R.layout.widget_configure_item, parent, false)
                val g = groups[position]
                view.findViewById<TextView>(R.id.item_name).text = g.name
                view.findViewById<TextView>(R.id.item_type).text = when (g.type) {
                    "couple" -> getString(R.string.group_type_couple)
                    "family" -> getString(R.string.group_type_family)
                    else -> getString(R.string.group_type_friends)
                }
                view.contentDescription = "${g.name}, ${view.findViewById<TextView>(R.id.item_type).text}"
                return view
            }
        }
        list.setOnItemClickListener { _, _, position, _ -> choose(groups[position]) }
    }

    private fun loadGroups(): List<GroupItem> {
        val raw = getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE)
            .getString("closer.groups", null) ?: return emptyList()
        return runCatching {
            val arr = JSONArray(raw)
            (0 until arr.length()).map {
                val o = arr.getJSONObject(it)
                GroupItem(o.getString("id"), o.getString("name"), o.optString("type"))
            }
        }.getOrDefault(emptyList())
    }

    private fun choose(group: GroupItem) {
        WidgetConfigStore.set(this, widgetId, group.id)
        CloserWidgetProvider.render(this, AppWidgetManager.getInstance(this), widgetId)
        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
        finish()
    }
}
