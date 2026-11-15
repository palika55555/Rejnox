package com.rejnox.rejnox.wear

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONObject

/**
 * Spojenie hodiniek s telefónom: posiela stav tréningu, tep a kalórie.
 * Rovnaký formát ako Apple Watch (state, bpm, kcal, at v sekundách).
 */
object PhoneLink {
    const val HEART_RATE_PATH = "/rejnox/heart_rate"
    const val COMMAND_PATH = "/rejnox/command"
    private const val TAG = "RejnoxPhoneLink"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /** state: started / running / paused / ended */
    fun send(context: Context, state: String, bpm: Double?, kcal: Double?) {
        val json = JSONObject()
            .put("type", "heartRate")
            .put("state", state)
            .put("at", System.currentTimeMillis() / 1000.0)
        bpm?.let { json.put("bpm", it) }
        kcal?.let { json.put("kcal", it) }
        val bytes = json.toString().toByteArray()

        scope.launch {
            try {
                val nodes = Wearable.getNodeClient(context).connectedNodes.await()
                val messages = Wearable.getMessageClient(context)
                nodes.forEach { messages.sendMessage(it.id, HEART_RATE_PATH, bytes).await() }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // Telefón nie je v dosahu; ďalšia správa príde o sekundu.
                Log.w(TAG, "Stav tréningu sa do telefónu neposlal", e)
            }
        }
    }
}
