package com.mohamed_helicopter.squad

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode

class MainActivity : FlutterActivity() {
    override fun getRenderMode(): RenderMode {
        return RenderMode.surface  // ← back to surface, texture causes other issues
    }
}