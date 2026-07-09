package com.space_chicken

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ComponentCallbacks2
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.webkit.CookieManager
import android.webkit.WebViewDatabase
import android.webkit.WebStorage
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val vibrationChannel = "space_chicken/vibration"
    private val linksChannel = "space_chicken/links"
    private val systemUiChannel = "space_chicken/system_ui"
    private val notificationPermissionChannel = "space_chicken/notification_permission"
    private val fcmNotificationChannelId = "high_importance_channel_v3"
    private val notificationPermissionRequestCode = 41033
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        trimAppStorage(clearPersistentWebViewData = true)
        createNotificationChannel()
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        if (level >= ComponentCallbacks2.TRIM_MEMORY_BACKGROUND) {
            trimAppStorage(clearPersistentWebViewData = true)
        } else if (level >= ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW) {
            trimAppStorage(clearPersistentWebViewData = false)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun onStop() {
        trimAppStorage(clearPersistentWebViewData = true)
        super.onStop()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            vibrationChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "crash" -> {
                    vibrateCrash()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            linksChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    try {
                        if (url.startsWith("intent:")) {
                            val intent = Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
                            if (intent != null) {
                                val info = packageManager.resolveActivity(intent, android.content.pm.PackageManager.MATCH_DEFAULT_ONLY)
                                if (info != null) {
                                    startActivity(intent)
                                    result.success(true)
                                    return@setMethodCallHandler
                                } else {
                                    val fallbackUrl = intent.getStringExtra("browser_fallback_url")
                                    if (!fallbackUrl.isNullOrBlank()) {
                                        val fallbackIntent = Intent(Intent.ACTION_VIEW, Uri.parse(fallbackUrl))
                                        startActivity(fallbackIntent)
                                        result.success(true)
                                        return@setMethodCallHandler
                                    }
                                }
                            }
                            result.success(false)
                        } else {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            startActivity(intent)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("OPEN_FAILED", e.message, null)
                    }
                }
                "getDefaultUserAgent" -> {
                    try {
                        val userAgent = android.webkit.WebSettings.getDefaultUserAgent(this)
                        result.success(userAgent)
                    } catch (e: Exception) {
                        result.error("FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            systemUiChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setDecorFitsSystemWindows" -> {
                    val decorFits = call.arguments as? Boolean ?: true
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        window.setDecorFitsSystemWindows(decorFits)
                    }
                    result.success(true)
                }
                "trimWebViewStorage" -> {
                    val clearPersistentData = call.argument<Boolean>("clearPersistentData") ?: false
                    trimAppStorage(clearPersistentData)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notificationPermissionChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStatus" -> result.success(notificationPermissionStatus())
                "request" -> requestNotificationPermission(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == notificationPermissionRequestCode) {
            val result = pendingNotificationPermissionResult
            pendingNotificationPermissionResult = null
            val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
            result?.success(if (granted) "authorized" else "denied")
            return
        }

        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success("authorized")
            return
        }

        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            result.success("authorized")
            return
        }

        if (pendingNotificationPermissionResult != null) {
            result.error("REQUEST_IN_PROGRESS", "Notification permission request is already running.", null)
            return
        }

        pendingNotificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationPermissionRequestCode
        )
    }

    private fun notificationPermissionStatus(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return "authorized"
        }

        return if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            "authorized"
        } else {
            "denied"
        }
    }

    private fun vibrateCrash() {
        val vibrator = getDeviceVibrator() ?: return
        if (!vibrator.hasVibrator()) {
            return
        }

        val timings = longArrayOf(0, 180, 70, 260)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val amplitudes = intArrayOf(0, 255, 0, 230)
            vibrator.vibrate(
                VibrationEffect.createWaveform(timings, amplitudes, -1)
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(timings, -1)
        }
    }

    private fun getDeviceVibrator(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    private fun trimAppStorage(clearPersistentWebViewData: Boolean) {
        trimTransientAppCache()
        trimWebViewStorage(clearPersistentWebViewData)
    }

    private fun trimTransientAppCache() {
        deleteDirectoryContents(cacheDir)
        deleteDirectoryContents(codeCacheDir)
        externalCacheDir?.let { deleteDirectoryContents(it) }
    }

    private fun trimWebViewStorage(clearPersistentWebViewData: Boolean) {
        if (clearPersistentWebViewData) {
            try {
                CookieManager.getInstance().removeAllCookies(null)
                CookieManager.getInstance().flush()
            } catch (_: Exception) {
            }

            try {
                WebStorage.getInstance().deleteAllData()
            } catch (_: Exception) {
            }

            try {
                WebViewDatabase.getInstance(this).clearHttpAuthUsernamePassword()
                WebViewDatabase.getInstance(this).clearFormData()
            } catch (_: Exception) {
            }
        }

        val dataRoot = File(applicationInfo.dataDir)
        val cacheRoot = cacheDir
        val codeCacheRoot = codeCacheDir

        val cacheDataPaths = listOf(
            "app_webview/Default/Cache",
            "app_webview/Default/Code Cache",
            "app_webview/Default/GPUCache",
            "app_webview/Default/DawnGraphiteCache",
            "app_webview/Default/DawnWebGPUCache",
            "app_webview/Default/GrShaderCache",
            "app_webview/Default/ShaderCache",
            "app_webview/Default/Shared Dictionary/cache",
            "app_webview/Default/Service Worker/CacheStorage",
            "app_webview/Default/Service Worker/ScriptCache",
            "app_webview/Default/blob_storage",
            "app_webview/BrowserMetrics",
            "app_webview/Crashpad"
        )

        val persistentDataPaths = listOf(
            "app_webview/Default/File System",
            "app_webview/Default/IndexedDB",
            "app_webview/Default/Local Storage",
            "app_webview/Default/Session Storage",
            "app_webview/Default/Service Worker",
            "app_webview/Default/Shared Dictionary",
            "app_webview/Default/WebStorage",
            "app_webview/Default/databases",
            "app_webview/Default/QuotaManager",
            "app_webview/Default/QuotaManager-journal",
            "app_webview/Default/Network Persistent State",
            "app_webview/Default/Trust Tokens",
            "app_webview/Default/Cookies",
            "app_webview/Default/Cookies-journal"
        )

        val cachePaths = listOf(
            "WebView",
            "webview",
            "org.chromium.android_webview",
            "com.android.webview",
            "com.google.android.webview"
        )

        cacheDataPaths.forEach { relativePath ->
            deleteIfInsideRoot(dataRoot, File(dataRoot, relativePath))
        }
        if (clearPersistentWebViewData) {
            persistentDataPaths.forEach { relativePath ->
                deleteIfInsideRoot(dataRoot, File(dataRoot, relativePath))
            }
        }
        cachePaths.forEach { relativePath ->
            deleteIfInsideRoot(cacheRoot, File(cacheRoot, relativePath))
        }
        deleteDirectoryContents(codeCacheRoot)
        externalCacheDir?.let { deleteDirectoryContents(it) }
        pruneWebViewCacheDirectories(File(dataRoot, "app_webview"))
    }

    private fun pruneWebViewCacheDirectories(root: File) {
        if (!root.exists()) {
            return
        }

        val cacheDirectoryNames = setOf(
            "Cache",
            "Code Cache",
            "GPUCache",
            "DawnGraphiteCache",
            "DawnWebGPUCache",
            "GrShaderCache",
            "ShaderCache",
            "CacheStorage",
            "ScriptCache",
            "blob_storage",
            "BrowserMetrics",
            "Crashpad"
        )

        val directoriesToDelete = root.walkTopDown()
            .maxDepth(6)
            .filter { it.isDirectory && it.name in cacheDirectoryNames }
            .toList()

        directoriesToDelete.forEach { deleteIfInsideRoot(root, it) }
    }

    private fun deleteDirectoryContents(root: File?) {
        if (root == null || !root.exists() || !root.isDirectory) {
            return
        }

        root.listFiles()?.forEach { child ->
            deleteIfInsideRoot(root, child)
        }
    }

    private fun deleteIfInsideRoot(root: File, target: File) {
        try {
            val rootPath = root.canonicalFile.path
            val targetFile = target.canonicalFile
            val targetPath = targetFile.path

            if (targetPath != rootPath && !targetPath.startsWith("$rootPath${File.separator}")) {
                return
            }

            if (targetFile.exists()) {
                targetFile.deleteRecursively()
            }
        } catch (_: Exception) {
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            fcmNotificationChannelId,
            "High importance notifications",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Notifications with offers and app updates"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 250, 120, 250)
            setShowBadge(true)
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
}
