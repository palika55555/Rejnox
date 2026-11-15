package com.rejnox.rejnox

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.concurrent.futures.await
import androidx.wear.remote.interactions.RemoteActivityHelper
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.Wearable
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.asExecutor
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONObject

/**
 * Most medzi hodinkami s Wear OS a Flutterom (rovnaké kanály ako Apple Watch):
 * - kanál "rejnox/watch": status, startWorkout, stop/pause/resumeWorkout,
 *   openWatchApp (Obchod Play na hodinkách)
 * - stream "rejnox/watch_heart_rate": tep a kalórie z hodiniek naživo
 */
class WatchBridge(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    MessageClient.OnMessageReceivedListener {

    private val scope = MainScope()
    private var sink: EventChannel.EventSink? = null

    init {
        MethodChannel(messenger, "rejnox/watch").setMethodCallHandler(this)
        EventChannel(messenger, "rejnox/watch_heart_rate").setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                when (call.method) {
                    "status" -> result.success(status())
                    "startWorkout" -> {
                        startWorkout()
                        result.success(true)
                    }
                    "stopWorkout" -> result.success(send("stop"))
                    "pauseWorkout" -> result.success(send("pause"))
                    "resumeWorkout" -> result.success(send("resume"))
                    "openWatchApp" -> result.success(openPlayStoreOnWatch())
                    else -> result.notImplemented()
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                result.error("watch_failed", e.message, null)
            }
        }
    }

    /** Pripojené hodinky; bez Wear OS appky v telefóne prázdny zoznam. */
    private suspend fun connectedNodes(): List<Node> =
        try {
            Wearable.getNodeClient(context).connectedNodes.await()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            emptyList()
        }

    /** Hodinky, na ktorých je Rejnox (schopnosť z wear/res/values/wear.xml). */
    private suspend fun rejnoxNodes(): Set<Node> =
        try {
            Wearable.getCapabilityClient(context)
                .getCapability(CAPABILITY, CapabilityClient.FILTER_REACHABLE)
                .await()
                .nodes
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            emptySet()
        }

    private suspend fun status(): Map<String, Boolean> {
        val installed = rejnoxNodes()
        return mapOf(
            "paired" to (installed.isNotEmpty() || connectedNodes().isNotEmpty()),
            "installed" to installed.isNotEmpty(),
            "reachable" to installed.any { it.isNearby },
        )
    }

    private suspend fun startWorkout() {
        val node = rejnoxNodes().firstOrNull()
            ?: throw IllegalStateException("Rejnox na hodinkách nie je v dosahu.")
        openOnWatch(Uri.parse(START_URI), node.id)
    }

    /** Vráti false, ak hodinky nie sú v dosahu. */
    private suspend fun send(command: String): Boolean {
        val nodes = rejnoxNodes()
        val messages = Wearable.getMessageClient(context)
        nodes.forEach { messages.sendMessage(it.id, COMMAND_PATH, command.toByteArray()).await() }
        return nodes.isNotEmpty()
    }

    /** Otvorí Rejnox v Obchode Play na hodinkách, kde ešte nie je. */
    private suspend fun openPlayStoreOnWatch(): Boolean {
        val installed = rejnoxNodes().map { it.id }.toSet()
        val targets = connectedNodes().filter { it.id !in installed }
        val store = Uri.parse("market://details?id=${context.packageName}")
        targets.forEach { openOnWatch(store, it.id) }
        return targets.isNotEmpty()
    }

    private suspend fun openOnWatch(uri: Uri, nodeId: String) {
        val intent = Intent(Intent.ACTION_VIEW)
            .addCategory(Intent.CATEGORY_BROWSABLE)
            .setData(uri)
        RemoteActivityHelper(context, Dispatchers.IO.asExecutor())
            .startRemoteActivity(intent, nodeId)
            .await()
    }

    // EventChannel

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        Wearable.getMessageClient(context).addListener(this)
    }

    override fun onCancel(arguments: Any?) {
        Wearable.getMessageClient(context).removeListener(this)
        sink = null
    }

    override fun onMessageReceived(event: MessageEvent) {
        if (event.path != HEART_RATE_PATH) return
        val json = runCatching { JSONObject(String(event.data)) }.getOrNull() ?: return
        val payload = buildMap<String, Any> {
            put("state", json.optString("state", "running"))
            put("at", json.optDouble("at", System.currentTimeMillis() / 1000.0))
            if (json.has("bpm")) put("bpm", json.getDouble("bpm"))
            if (json.has("kcal")) put("kcal", json.getDouble("kcal"))
        }
        // Správy chodia na hlavnom vlákne, sink sa smie volať priamo.
        sink?.success(payload)
    }

    companion object {
        private const val CAPABILITY = "rejnox_wear"
        private const val HEART_RATE_PATH = "/rejnox/heart_rate"
        private const val COMMAND_PATH = "/rejnox/command"
        private const val START_URI = "rejnox://workout/start"
    }
}
