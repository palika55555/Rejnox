package com.rejnox.rejnox.wear

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import android.widget.Button
import android.widget.Chronometer
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/** Obrazovka tréningu: tep, kalórie, čas, pauza a ukončenie. */
class MainActivity : ComponentActivity() {
    private lateinit var bpm: TextView
    private lateinit var kcal: TextView
    private lateinit var timer: Chronometer
    private lateinit var paused: TextView
    private lateinit var pause: Button
    private lateinit var main: Button
    private lateinit var error: TextView

    private val permissions = buildList {
        add(Manifest.permission.BODY_SENSORS)
        add(Manifest.permission.ACTIVITY_RECOGNITION)
        if (Build.VERSION.SDK_INT >= 33) add(Manifest.permission.POST_NOTIFICATIONS)
    }.toTypedArray()

    private val requestPermissions =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
            if (result[Manifest.permission.BODY_SENSORS] == true) {
                WorkoutController.start()
            } else {
                WorkoutController.reportError("Bez povolenia senzorov tep nezmeriam.")
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        bpm = findViewById(R.id.bpm)
        kcal = findViewById(R.id.kcal)
        timer = findViewById(R.id.timer)
        paused = findViewById(R.id.paused)
        pause = findViewById(R.id.pause)
        main = findViewById(R.id.main)
        error = findViewById(R.id.error)

        WorkoutController.init(this)
        pause.setOnClickListener { WorkoutController.togglePause() }
        main.setOnClickListener {
            if (WorkoutController.state.value.running) WorkoutController.stop() else requestStart()
        }

        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                WorkoutController.state.collect { render(it) }
            }
        }
        if (hasSensors()) WorkoutController.recover()
        handle(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    /** rejnox://workout/start z telefónu spustí tréning. */
    private fun handle(intent: Intent?) {
        val uri = intent?.data ?: return
        if (uri.host == "workout" && uri.path == "/start") requestStart()
    }

    private fun hasSensors() =
        ContextCompat.checkSelfPermission(this, Manifest.permission.BODY_SENSORS) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestStart() {
        if (WorkoutController.state.value.running) return
        if (hasSensors()) WorkoutController.start() else requestPermissions.launch(permissions)
    }

    private fun render(state: WorkoutState) {
        val heart = state.bpm?.takeIf { it > 0 }?.roundToInt()
        bpm.text = heart?.toString() ?: "--"
        bpm.contentDescription =
            heart?.let { "Tep $it úderov za minútu" } ?: "Tep zatiaľ nie je známy"

        kcal.visibility = if (state.running) View.VISIBLE else View.GONE
        kcal.text = "${(state.kcal ?: 0.0).roundToInt()} kcal"

        val start = state.startedAt
        if (state.running && start != null && !state.paused) {
            timer.base = SystemClock.elapsedRealtime() - (System.currentTimeMillis() - start)
            timer.visibility = View.VISIBLE
            timer.start()
        } else {
            timer.stop()
            timer.visibility = View.GONE
        }
        paused.visibility = if (state.paused) View.VISIBLE else View.GONE

        pause.visibility = if (state.running) View.VISIBLE else View.GONE
        pause.text = if (state.paused) "Pokračovať" else "Pauza"
        main.text = if (state.running) "Ukončiť" else "Začať tréning"

        error.visibility = if (state.error != null) View.VISIBLE else View.GONE
        error.text = state.error
    }
}
