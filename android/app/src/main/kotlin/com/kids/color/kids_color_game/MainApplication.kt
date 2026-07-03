package com.kids.color.kids_color_game

import io.flutter.app.FlutterApplication
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugins.GeneratedPluginRegistrant

class MainApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        GeneratedPluginRegistrant.registerWith(this)
    }
}
