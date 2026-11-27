// Neon Gölgeler — Android GeckoView kabuğu (şablon)
// app/src/main/assets/game/ klasörüne game/ içeriğini (vendor dahil) kopyalayın.
// Oyun, cihaz içinde 127.0.0.1:48219 adresindeki yerel sunucudan açılır.
package com.neongolgeler.game

import android.app.Activity
import android.content.Intent
import android.net.Uri
import org.mozilla.geckoview.AllowOrDeny
import org.mozilla.geckoview.GeckoResult
import android.content.res.AssetManager
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import org.mozilla.geckoview.GeckoRuntime
import org.mozilla.geckoview.GeckoRuntimeSettings
import org.mozilla.geckoview.GeckoSession
import org.mozilla.geckoview.GeckoView
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.URLDecoder
import kotlin.concurrent.thread

class MainActivity : Activity() {
    private lateinit var session: GeckoSession
    private var server: LocalAssetServer? = null

    companion object { private var runtime: GeckoRuntime? = null; const val PORT = 48219; const val SHELL_VERSION = "1.1.0" }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.decorView.systemUiVisibility = (View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
        server = LocalAssetServer(assets, PORT).also { it.start() }
        val view = GeckoView(this)
        setContentView(view)
        session = GeckoSession()
        if (runtime == null) {
            val settings = GeckoRuntimeSettings.Builder()
                .javaScriptEnabled(true)
                .remoteDebuggingEnabled(true) // about:debugging ile masaüstü Firefox'tan hata ayıklama
                .build()
            runtime = GeckoRuntime.create(this, settings)
        }
        // dış bağlantılar (APK güncellemesi, Releases) sistem tarayıcısında açılır
        session.navigationDelegate = object : GeckoSession.NavigationDelegate {
            override fun onLoadRequest(session: GeckoSession, request: GeckoSession.NavigationDelegate.LoadRequest): GeckoResult<AllowOrDeny>? {
                return if (request.uri.startsWith("http://127.0.0.1")) GeckoResult.fromValue(AllowOrDeny.ALLOW)
                else { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(request.uri))); GeckoResult.fromValue(AllowOrDeny.DENY) }
            }
        }
        session.open(runtime!!)
        view.setSession(session)
        session.loadUri("http://127.0.0.1:$PORT/index.html?shell=apk-" + SHELL_VERSION)
    }

    override fun onDestroy() { server?.stop(); session.close(); super.onDestroy() }
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() { session.goBack() }
}

/** assets/game/ klasörünü yalnızca 127.0.0.1 üzerinden sunan küçük HTTP sunucusu */
class LocalAssetServer(private val assets: AssetManager, private val port: Int) {
    @Volatile private var running = false
    private var socket: ServerSocket? = null
    private val types = mapOf("html" to "text/html; charset=utf-8", "js" to "text/javascript; charset=utf-8", "json" to "application/json",
        "png" to "image/png", "jpg" to "image/jpeg", "webp" to "image/webp", "glb" to "model/gltf-binary", "obj" to "text/plain", "css" to "text/css", "wasm" to "application/wasm")

    fun start() {
        running = true
        socket = ServerSocket(port, 50, InetAddress.getByName("127.0.0.1"))
        thread(isDaemon = true) { while (running) { try { val c = socket!!.accept(); thread(isDaemon = true) { handle(c) } } catch (_: Exception) { } } }
    }
    fun stop() { running = false; try { socket?.close() } catch (_: Exception) { } }

    private fun handle(c: Socket) {
        c.use { s ->
            val reader = BufferedReader(InputStreamReader(s.getInputStream()))
            val line = reader.readLine() ?: return
            var path = URLDecoder.decode(line.split(" ").getOrElse(1) { "/" }.substringBefore("?"), "UTF-8")
            if (path == "/") path = "/index.html"
            if (path.contains("..")) { s.getOutputStream().write("HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\n\r\n".toByteArray()); return }
            val out = s.getOutputStream()
            try {
                val bytes = assets.open("game$path").use { it.readBytes() }
                val type = types[path.substringAfterLast('.', "").lowercase()] ?: "application/octet-stream"
                out.write("HTTP/1.1 200 OK\r\nContent-Type: $type\r\nContent-Length: ${bytes.size}\r\nCache-Control: no-cache\r\nConnection: close\r\n\r\n".toByteArray())
                out.write(bytes)
            } catch (e: Exception) {
                out.write("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".toByteArray())
            }
            out.flush()
        }
    }
}
