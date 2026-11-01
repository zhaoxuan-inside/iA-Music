package com.hardstone.ia_music

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.ReturnCode
import dev.ffmpegkit_maintained.ytdlp.YtDlp
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * T9A（S6 Android 侧）：提取引擎通道 `ia_extract/engine` + 事件 `ia_extract/events`。
 *
 * 语义对齐桌面 Process 形态（DownloaderPort）：
 * * resolve = yt_dlp YoutubeDL(opts).extract_info(url, download=False)（=桌面 `-J`
 *   simulate 语义；yt-dlp-android 2.0.2 AAR 内嵌 CPython 3.13+yt_dlp+chaquopy_java
 *   17.0.0 运行时经 AAR libs/ 对消费方编译可见——实证 2026-10-19）。
 * * download = extract_info 取真实音频流 DASH URL（30216/30232/30280 枚举族选档）
 *   → HttpURLConnection 分段下载（Range 断点续传；bilibili CDN 必带 Referer=
 *   yt-dlp 同规则）→ ffmpeg-kit-full 8.1.7（MIT；libmp3lame 静态编入实证）转录
 *   mp3 + ID3 标签 + 封面嵌入。raw 中间件保留 .part 语义。
 * * Cookie：Dart 内存传值 → 应用私有 cacheDir 临时 Netscape 文件，任务终态即删
 *   （C50：不落日志/库）。
 * * 取消/暂停：协作标志（下载读循环逐步检查 + FFmpegKit.cancel 全局（单活动任务
 *   语义允许）），pause 保 .part，cancel 删半成品——终态记账全在队列 Dart 侧。
 */
class MainActivity : FlutterActivity() {
    companion object {
        const val TAG = "ia_extract"
        @Volatile private var engineInited = false
    }

    private val started = AtomicBoolean(false)
    private val canceled = AtomicBoolean(false)
    private var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())
    private val pool = Executors.newCachedThreadPool { r ->
        Thread(r, "ia-extract").apply { isDaemon = false }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ia_extract/engine")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "init" -> {
                        result.success(true) // init 延迟到首个 resolve/download 前（ensureEngine）
                    }
                    "resolve" -> {
                        val url = call.argument<String>("url")!!
                        val cookies = call.argument<String?>("cookies")
                        pool.execute {
                            try {
                                ensureEngine()
                                val json = ytDlpMetadataJson(url, cookies)
                                main.post { result.success(json) }
                            } catch (e: Exception) {
                                main.post { result.error(classifyPy(e), e.message, e.toString()) }
                            }
                        }
                    }
                    "resolveAll" -> {
                        val url = call.argument<String>("url")!!
                        val cookies = call.argument<String?>("cookies")
                        pool.execute {
                            try {
                                ensureEngine()
                                val json = ytDlpPlaylistJson(url, cookies)
                                main.post { result.success(json) }
                            } catch (e: Exception) {
                                main.post { result.error(classifyPy(e), e.message, e.toString()) }
                            }
                        }
                    }
                    "download" -> {
                        val url = call.argument<String>("url")!!
                        val outputDir = call.argument<String>("outputDir")!!
                        val quality = call.argument<String>("quality") ?: "k192"
                        val cookies = call.argument<String?>("cookies")
                        val notifTitle = call.argument<String>("notifTitle")
                            ?: ExtractionService.DEFAULT_TITLE
                        result.success(true) // 终态全经 events（staged/paused/failed）
                        // WS3/REQ-EXT-04：前台服务=下载期保持后台存活（离开页面不中断）
                        ExtractionService.start(this@MainActivity, notifTitle)
                        pool.execute {
                            try {
                                ensureEngine()
                                runDownload(url, outputDir, quality, cookies)
                            } catch (e: Exception) {
                                Log.e(TAG, "download failed", e)
                                if (canceled.get()) {
                                    emit(mapOf("type" to "paused", "reason" to "user"))
                                } else {
                                    emit(mapOf("type" to "failed", "code" to "network",
                                        "detail" to "${e::class.java.simpleName}: ${e.message}"))
                                }
                            } finally {
                                deleteTempCookies()
                                ExtractionService.stop(this@MainActivity)
                            }
                        }
                    }
                    "pause" -> {
                        canceled.set(true)
                        FFmpegKit.cancel() // 单活动任务语义：全局会话取消=当前任务
                        ExtractionService.stop(this@MainActivity)
                        result.success(true)
                    }
                    "cancel" -> {
                        canceled.set(true)
                        FFmpegKit.cancel()
                        ExtractionService.stop(this@MainActivity)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "ia_extract/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sink = events
                }
                override fun onCancel(arguments: Any?) {
                    sink = null
                }
            })
    }

    private fun emit(ev: Map<String, Any>) {
        // WS3：进度 ≥5% 步进 → 前台服务通知同步（节流防 intent 风暴）
        if (ev["type"] == "progress") {
            val pct = (ev["percent"] as? Number)?.toInt() ?: 0
            if (pct - lastFgPct >= 5) {
                lastFgPct = pct
                try {
                    ExtractionService.update(
                        this, ExtractionService.DEFAULT_TITLE, pct
                    )
                } catch (_: Exception) {
                    // 通知不可用（后台启动限制等）——下载主线不受阻
                }
            }
        }
        main.post { sink?.success(ev) }
    }

    @Volatile private var lastFgPct = -100

    // ---------- 验证环境网络底数（RV-B 模拟器窗口）----------
    // * 模拟器 NAT 继承不到宿主 TUN/DNS（net.dns1/2 空，实测 getprop）→
    //   模拟器上提取流量经宿主代理 10.0.2.2:7897（10.0.2.2=emulator 特指宿主
    //   回环）；DNS 由代理解析（CONNECT/远端解析）——与桌面宿主 TUN 同网络语义。
    // * 真机（arm64 RV-B 终验窗口）不走此分支：直连。
    private val onEmulator: Boolean by lazy {
        android.os.Build.FINGERPRINT.contains("generic") ||
            android.os.Build.FINGERPRINT.contains("emulator") ||
            android.os.Build.MODEL.contains("sdk_gphone")
    }
    private val VERIFY_PROXY_HOST = "10.0.2.2"
    private val VERIFY_PROXY_PORT = 7897

    private fun httpProxy(): java.net.Proxy? = if (onEmulator) {
        java.net.Proxy(java.net.Proxy.Type.HTTP,
            java.net.InetSocketAddress(VERIFY_PROXY_HOST, VERIFY_PROXY_PORT))
    } else null

    private fun verifyProxyUrl(): String? =
        if (onEmulator) "http://$VERIFY_PROXY_HOST:$VERIFY_PROXY_PORT" else null

    private fun ensureEngine() {
        if (!started.compareAndSet(false, true)) return
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(applicationContext))
        }
        if (!engineInited) {
            // YtDlp.init 幂等；这里只借其启动链（Chaquopy assets 已在 AAR）
            if (!Python.isStarted()) throw IllegalStateException("python not started")
            engineInited = true
        }
        ensureYtDlpOverride()
    }

    // ---------- yt-dlp 运行时升级（B 站适配失效快速响应；T9A 实证路径）----------
    //
    // 背景（2026-10-19 实证）：AAR 打包 yt_dlp=2026.6.9，B 站已收紧指纹级反挖
    // （412 Precondition Failed / 旧版 TLS 握手被 RST——宿主 venv 对照 OLD 稳定 FAIL、
    //  2026.8.19 稳定 OK）。yt-dlp wheel 为纯 Python，可运行时解包并以 sys.path[0]
    //  压过打包版（宿主等价注入验证已通过）。对齐 DEC-008「B 站适配失效时快速
    //  小版本更新」诉求，不随库发版即可更新。
    private val YT_DLP_OVERRIDE_VERSION = "2026.8.19"

    private fun ensureYtDlpOverride() {
        val dir = File(filesDir, "ytdlp_override")
        val marker = File(dir, "version.txt")
        if (marker.exists() && marker.readText().trim() == YT_DLP_OVERRIDE_VERSION) {
            sysPathInsert(dir)
            return
        }
        try {
            val meta = httpGetString(
                "https://pypi.org/pypi/yt-dlp/$YT_DLP_OVERRIDE_VERSION/json")
                ?: throw IllegalStateException("pypi meta fetch failed")
            val urls = org.json.JSONObject(meta).getJSONArray("urls")
            var whlUrl = ""
            for (i in 0 until urls.length()) {
                val u = urls.getJSONObject(i)
                if (u.optString("packagetype") == "bdist_wheel" &&
                    u.optString("filename").endsWith("-py3-none-any.whl")) {
                    whlUrl = u.optString("url")
                    break
                }
            }
            if (whlUrl.isEmpty()) throw IllegalStateException("pure wheel not found")
            val tmp = File.createTempFile("ytdlp_dl", ".whl", cacheDir)
            try {
                downloadToFile(whlUrl, tmp)
                val z = java.util.zip.ZipFile(tmp)
                dir.mkdirs()
                for (e in z.entries()) {
                    if (!(e.name.startsWith("yt_dlp/") || e.name.contains(".dist-info/"))) {
                        continue
                    }
                    val f = File(dir, e.name)
                    if (e.isDirectory) {
                        f.mkdirs()
                    } else {
                        f.parentFile?.mkdirs()
                        z.getInputStream(e).use { i -> f.outputStream().use { o -> i.copyTo(o) } }
                    }
                }
                z.close()
            } finally {
                tmp.delete()
            }
            marker.writeText(YT_DLP_OVERRIDE_VERSION)
        } catch (e: Exception) {
            // 网络不可用/更新失败：沿用打包 2026.6.9（B 站会 412，诚实报网络/引擎错误，
            // 下次启动再更新）——不冒充引擎正常。
            Log.w(TAG, "yt-dlp 运行时升级失败（沿用打包版 2026.6.9）", e)
            if (dir.exists()) sysPathInsert(dir)
        }
        sysPathInsert(dir)
    }

    private fun sysPathInsert(dir: File) {
        if (!dir.isDirectory) return
        val sys = Python.getInstance().getModule("sys")
        // sys.path 是 list：先取列表对象，再调其 insert（直接 callAttr("path",…)
        // 会把 path 当 callable 调 → TypeError: 'list' object is not callable）。
        sys.get("path")?.callAttr("insert", 0, dir.absolutePath)
    }

    private fun httpGetString(url: String): String? {
        val conn = URL(url).openConnection(httpProxy() ?: java.net.Proxy.NO_PROXY) as HttpURLConnection
        conn.connectTimeout = 15000
        conn.readTimeout = 60000
        if (conn.responseCode !in 200..299) return null
        return conn.inputStream.bufferedReader().use { it.readText() }
    }

    private fun downloadToFile(url: String, target: File) {
        val conn = URL(url).openConnection(httpProxy() ?: java.net.Proxy.NO_PROXY) as HttpURLConnection
        conn.connectTimeout = 15000
        conn.readTimeout = 120000
        if (conn.responseCode !in 200..299) throw IllegalStateException("HTTP ${conn.responseCode}")
        conn.inputStream.use { i -> target.outputStream().use { o -> i.copyTo(o, 1 shl 16) } }
    }

    // ---------- yt_dlp（直接 Python API：自由选项面） ----------

    @Volatile private var tempCookieFile: File? = null

    private fun ytDlpMetadataJson(url: String, cookiesContent: String?): String {
        val py = Python.getInstance()
        val ytDlp = py.getModule("yt_dlp")
        val jsonMod = py.getModule("json")
        // opts 经 json.loads 成原生 python dict（Kotlin Map 直传被包成 Java 对象，
        // python 侧 .get(k, default) 会撞 Java 方法签名——实测 TypeError）。
        val cookiePath = writeTempCookies(cookiesContent)
        val proxy = verifyProxyUrl()
        val optsJson = buildString {
            append("{\"noplaylist\":true,\"quiet\":true,\"no_warnings\":true")
            if (cookiePath != null) append(",\"cookiefile\":\"$cookiePath\"")
            if (proxy != null) append(",\"proxy\":\"$proxy\"")
            append("}")
        }
        try {
            val opts = jsonMod.callAttr("loads", optsJson)
            val ydl = ytDlp.callAttr("YoutubeDL", opts)
            val info = ydl.callAttr("extract_info", url, false)
            return jsonMod.callAttr("dumps", info).toString()
        } finally {
            if (cookiePath != null) deleteTempCookies()
        }
    }

    /** B 站多 P/合集条目枚举（开发裁决 2026-10-19「拆分成多个单独的歌曲」）：
     *  extract_flat='in_playlist'（不逐页取详情，快），条目 url 自带 ?p=N，
     *  条目详情由下载任务对条目 url 二次 resolve 补全。 */
    private fun ytDlpPlaylistJson(url: String, cookiesContent: String?): String {
        val py = Python.getInstance()
        val ytDlp = py.getModule("yt_dlp")
        val jsonMod = py.getModule("json")
        val cookiePath = writeTempCookies(cookiesContent)
        val proxy = verifyProxyUrl()
        val optsJson = buildString {
            append("{\"extract_flat\":\"in_playlist\",\"quiet\":true,\"no_warnings\":true")
            if (cookiePath != null) append(",\"cookiefile\":\"$cookiePath\"")
            if (proxy != null) append(",\"proxy\":\"$proxy\"")
            append("}")
        }
        try {
            val opts = jsonMod.callAttr("loads", optsJson)
            val ydl = ytDlp.callAttr("YoutubeDL", opts)
            val info = ydl.callAttr("extract_info", url, false)
            return jsonMod.callAttr("dumps", info).toString()
        } finally {
            if (cookiePath != null) deleteTempCookies()
        }
    }

    private fun writeTempCookies(content: String?): String? {
        if (content.isNullOrEmpty()) return null
        val dir = File(cacheDir, "ia_cookies")
        if (!dir.exists()) dir.mkdirs()
        val f = File(dir, "cookies_${System.nanoTime()}.txt")
        f.writeText(content)
        tempCookieFile = f
        return f.absolutePath
    }

    private fun deleteTempCookies() {
        tempCookieFile?.let { f ->
            try { f.delete() } catch (_: Exception) { }
            try { f.parentFile?.delete() } catch (_: Exception) { }
        }
        tempCookieFile = null
    }

    private fun classifyPy(e: Exception): String {
        val t = (e.message ?: "") + e.toString()
        val lower = t.lowercase()
        return if ((lower.contains("login") || lower.contains("sign in")) && lower.contains("cookie") ||
            lower.contains("需要登录") || lower.contains("请登录")) "auth" else "engine"
    }

    // ---------- download ----------

    private fun runDownload(url: String, outputDir: String, quality: String, cookies: String?) {
        Log.w(TAG, "[dl] runDownload start quality=$quality")
        val metaJson = ytDlpMetadataJson(url, cookies)
        Log.w(TAG, "[dl] meta resolved (len=${metaJson.length})")
        val meta = org.json.JSONObject(metaJson)
        val id = meta.optString("id")
        if (id.isEmpty()) throw IllegalStateException("no id in metadata")

        val fmt = pickAudioFormat(meta, quality)
        val rawUrl = fmt.optString("url")
        if (rawUrl.isEmpty()) throw IllegalStateException("no audio stream url")
        val expectedRawBytes = fmt.optLong("size", -1L)
        val ext = if (quality == "hires") "flac" else "mp3"
        val dir = File(outputDir).apply { mkdirs() }
        val raw = File(dir, "${id}_raw.part")
        val out = File(dir, "$id.$ext")

        downloadStreamWithRetry(rawUrl, raw, expectedRawBytes)
        if (canceled.get()) {
            emit(mapOf("type" to "paused", "reason" to "user"))
            return
        }

        transcode(raw, out, meta.optString("title"), meta.optString("uploader"),
            meta.optString("thumbnail"))
        raw.delete()
        emit(mapOf("type" to "staged", "path" to out.absolutePath))
    }

    /** 音频轨选择（B 站 DASH 音轨 30216=64k / 30232=128k / 30280=192k；§5.2 枚举族）。 */
    private fun pickAudioFormat(meta: org.json.JSONObject, quality: String): org.json.JSONObject {
        val formats = meta.optJSONArray("formats")
        if (formats == null || formats.length() == 0) throw IllegalStateException("no formats")
        val audio = ArrayList<org.json.JSONObject>()
        for (i in 0 until formats.length()) {
            val f = formats.getJSONObject(i)
            val ac = f.optString("acodec")
            val fid = f.optString("format_id")
            if ((ac != "none" && ac.isNotEmpty()) || fid.startsWith("302")) audio.add(f)
        }
        if (audio.isEmpty()) throw IllegalStateException("no audio format")

        fun rank(f: org.json.JSONObject): Long {
            val fid = f.optString("format_id").toIntOrNull() ?: 0
            return when (fid) { 30216 -> 64; 30232 -> 128; 30280 -> 192; else -> 0 }
        }
        val sorted = audio.sortedByDescending { rank(it) }
        return when (quality) {
            "k64" -> sorted.lastOrNull() ?: sorted.first()
            "k128" -> sorted.firstOrNull { rank(it) <= 128 } ?: sorted.first()
            else -> sorted.first() // k192 / hires = 最高档（桌面同=默认 bestaudio）
        }
    }

    /** mcdn PCDN 节点（xy…xy.mcdn.bilivideo.cn）实证语义（T9A 2026-10-19）：
     *  * 对 Range 续传回 416（非标准 206/200）→ 续传无效；
     *  * 长时 stall（半开连接）时 readTimeout 偶发不掷 → 看门狗 disconnect 落 IOException。
     *  统一收口：416 → 删半成品从头下；其余异常 → 保留半成品带 Range 重试；≤3 次。 */
    private fun downloadStreamWithRetry(urlStr: String, target: File, expectedBytes: Long) {
        var last: Exception? = null
        for (attempt in 1..3) {
            try {
                downloadStream(urlStr, target, expectedBytes)
                return
            } catch (e: InterruptedException) {
                throw e
            } catch (e: Exception) {
                if (canceled.get()) throw InterruptedException("paused")
                last = e
                Log.w(TAG, "[dl] attempt $attempt failed: " +
                    "${e::class.java.simpleName}: ${e.message} partial=${target.length()}")
                if ("${e.message}".contains("HTTP 416")) target.delete()
            }
        }
        throw last ?: IllegalStateException("download retries exhausted")
    }

    private fun downloadStream(urlStr: String, target: File, expectedBytes: Long) {
        val resumeLen = if (target.exists()) target.length() else 0L
        val conn = URL(urlStr).openConnection(httpProxy() ?: java.net.Proxy.NO_PROXY) as HttpURLConnection
        conn.connectTimeout = 15000
        conn.readTimeout = 60000
        conn.instanceFollowRedirects = true
        conn.setRequestProperty("Referer", "https://www.bilibili.com/")
        conn.setRequestProperty("User-Agent",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36")
        if (resumeLen > 0) conn.setRequestProperty("Range", "bytes=$resumeLen-")
        Log.w(TAG, "[dl] conn… resume=$resumeLen (${urlStr.substringBefore("?")})")
        val code = conn.responseCode
        val contentRange = conn.getHeaderField("Content-Range")
        Log.w(TAG, "[dl] resp=$code len=${conn.contentLengthLong} type=${conn.contentType} cr=$contentRange")
        if (code == 416) {
            // 416=Range Not Satisfiable。实证（upos 官方节点/mcdn 同现）：
            // 半成品已达全文件长度（下完但连接未正常 EOF/未 FIN）→ 判完成直接收账；
            // 不匹配则视为该节点不支持续传 → 删残留由外层 downloadStreamWithRetry 从头重下。
            val totalSz = contentRange?.substringAfterLast('/')?.toLongOrNull()
            if (totalSz != null && resumeLen == totalSz) {
                runCatching { conn.disconnect() }
                Log.w(TAG, "[dl] 416 but part complete ($resumeLen==$totalSz) → done")
                return
            }
            throw IllegalStateException("HTTP 416 for stream (cr=$contentRange)")
        }
        if (code !in 200..299) throw IllegalStateException("HTTP $code for stream")
        val partial = code == 206
        val total = if (conn.contentLengthLong > 0) {
            conn.contentLengthLong + if (partial) resumeLen else 0L
        } else if (expectedBytes > 0) expectedBytes else -1L
        val input = conn.inputStream
        val start = if (partial) resumeLen else 0L
        val fos = FileOutputStream(target, partial) // 非 206=全量重发，从头覆盖
        try {
            pump(input, fos, conn, total, start.toDouble())
        } finally {
            fos.close()
            input.close()
        }
    }

    private fun pump(input: InputStream, fos: FileOutputStream,
                     conn: HttpURLConnection,
                     total: Long, base: Double) {
        val buf = ByteArray(65536)
        var soFar = base.toLong()
        var lastPct = if (base > 0 && total > 0) base / total * 100.0 else 0.0
        var lastMove = SystemClock.elapsedRealtime()
        // 看门狗：读循环 >90s 无字节推进 → 强断连接（readTimeout 就在该 socket
        // 上偶发不掷——CDN 半开连接场景实测卡死；联合证据见 T9A 记录）。
        val watchdog = Thread {
            try {
                Thread.sleep(90000)
                if (SystemClock.elapsedRealtime() - lastMove > 89000) {
                    Log.w(TAG, "[dl] watchdog: idle >90s, abort socket")
                    runCatching { conn.disconnect() }
                }
            } catch (_: Exception) { }
        }
        watchdog.isDaemon = true
        watchdog.start()
        try {
            while (true) {
                if (canceled.get()) {
                    throw InterruptedException("paused")
                }
                val n = input.read(buf)
                if (n < 0) break
                fos.write(buf, 0, n)
                soFar += n
                lastMove = SystemClock.elapsedRealtime()
                if (soFar / (1024 * 2048) != (soFar - n) / (1024 * 2048)) {
                    Log.w(TAG, "[dl] ${soFar / 1024}KiB/$total")
                }
                if (total > 0) {
                    val pct = soFar * 100.0 / total
                    if (pct - lastPct >= 0.5) {
                        lastPct = pct
                        emit(mapOf("type" to "progress", "percent" to pct.coerceIn(0.0, 100.0)))
                    }
                }
            }
            Log.w(TAG, "[dl] done soFar=$soFar total=$total")
        } finally {
            watchdog.interrupt()
        }
    }

    private fun transcode(raw: File, out: File, title: String, uploader: String, coverUrl: String) {
        var coverFile: File? = null
        try {
            coverFile = fetchCover(coverUrl)
            // ffmpeg CLI 约束：先列全部 -i 输入，再列输出选项（输出选项后跟 -i 会把
            // 输出选项归给该输入 → "apply an input option to an output file" 实证报错）。
            val inputArgs = ArrayList<String>(listOf("-y", "-i", raw.absolutePath))
            if (coverFile != null) inputArgs.addAll(listOf("-i", coverFile.absolutePath))
            // 显式 -map 已禁用自动流选择，-vn 反而会砍掉 -map 1:v 的封面视频轨
            // （实证：Output 只剩音频 → mp3 无 APIC）。不再放 -vn。
            val outArgs = ArrayList<String>(listOf(
                "-c:a", "libmp3lame", "-q:a", "5",
                "-id3v2_version", "3",
                "-metadata", "title=$title",
                "-metadata", "artist=$uploader",
                "-map_metadata", "-1",
            ))
            if (coverFile != null) {
                outArgs.addAll(listOf(
                    "-map", "0:a", "-map", "1:v",
                    "-c:v", "mjpeg",
                    "-disposition:v", "attached_pic",
                    "-metadata:s:v", "title=Album cover",
                ))
            } else {
                outArgs.addAll(listOf("-map", "0:a"))
            }
            val args = ArrayList<String>(inputArgs)
            args.addAll(outArgs)
            args.add(out.absolutePath)
            val session = FFmpegKit.executeWithArguments(args.toTypedArray())
            if (!ReturnCode.isSuccess(session.returnCode)) {
                val logs = session.allLogsAsString
                throw IllegalStateException("ffmpeg transcode failed: ${logs.takeLast(400)}")
            }
        } finally {
            coverFile?.delete()
        }
    }

    private fun fetchCover(coverUrl: String): File? {
        if (coverUrl.isBlank()) return null
        return try {
            // B 站 CDN 图床常给 http（i0.hdslb.com）——Android 默认禁明文，
            // host 支持 https，直接升级（T9A 实证：http 被 CleartextURLFilter 拒）。
            val upgraded = if (coverUrl.startsWith("http://")) {
                "https://" + coverUrl.removePrefix("http://")
            } else coverUrl
            val conn = URL(upgraded).openConnection(httpProxy() ?: java.net.Proxy.NO_PROXY) as HttpURLConnection
            conn.connectTimeout = 10000
            conn.readTimeout = 20000
            conn.setRequestProperty("Referer", "https://www.bilibili.com/")
            if (conn.responseCode !in 200..299) return null
            val f = File.createTempFile("ia_cover", ".img", cacheDir)
            conn.inputStream.use { i -> f.outputStream().use { o -> i.copyTo(o) } }
            f
        } catch (e: Exception) {
            Log.w(TAG, "cover fetch failed（非致命：跳过嵌封面）", e)
            null
        }
    }
}
