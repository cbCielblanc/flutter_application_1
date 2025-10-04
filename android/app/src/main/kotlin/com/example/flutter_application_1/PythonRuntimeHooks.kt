package com.example.flutter_application_1

import android.content.Context
import java.io.File

object PythonRuntimeHooks {
    fun ensureInitialized(context: Context) {
        val libsDir = context.applicationInfo.nativeLibraryDir
        if (libsDir != null) {
            System.setProperty("PYTHONHOME", libsDir)
        }
        val pythonDir = File(context.filesDir, "python-runtime")
        if (!pythonDir.exists()) {
            pythonDir.mkdirs()
        }
        System.setProperty("PYTHONPATH", pythonDir.absolutePath)
    }
}
