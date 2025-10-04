package com.example.flutter_application_1

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        PythonRuntimeHooks.ensureInitialized(applicationContext)
        super.onCreate(savedInstanceState)
    }
}
