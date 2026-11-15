package com.rejnox.rejnox.wear

import android.content.Context
import androidx.concurrent.futures.await
import androidx.health.services.client.ExerciseUpdateCallback
import androidx.health.services.client.HealthServices
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.ExerciseConfig
import androidx.health.services.client.data.ExerciseLapSummary
import androidx.health.services.client.data.ExerciseTrackedStatus
import androidx.health.services.client.data.ExerciseType
import androidx.health.services.client.data.ExerciseUpdate
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class WorkoutState(
    val running: Boolean = false,
    val paused: Boolean = false,
    val bpm: Double? = null,
    val kcal: Double? = null,
    /** Teraz mínus aktívny čas tréningu (System.currentTimeMillis). */
    val startedAt: Long? = null,
    val error: String? = null,
)

/**
 * Tréning cez Health Services: tep a kalórie naživo, pauza, obnova po
 * reštarte appky. Každú zmenu posiela do telefónu ([PhoneLink]).
 */
object WorkoutController {
    private val _state = MutableStateFlow(WorkoutState())
    val state: StateFlow<WorkoutState> = _state.asStateFlow()

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private lateinit var app: Context
    private val client by lazy { HealthServices.getClient(app).exerciseClient }

    fun init(context: Context) {
        if (!::app.isInitialized) app = context.applicationContext
    }

    private val callback = object : ExerciseUpdateCallback {
        override fun onExerciseUpdateReceived(update: ExerciseUpdate) {
            val exercise = update.exerciseStateInfo.state
            if (exercise.isEnded) {
                finish()
                return
            }
            val bpm = update.latestMetrics.getData(DataType.HEART_RATE_BPM).lastOrNull()?.value
            val kcal = update.latestMetrics.getData(DataType.CALORIES_TOTAL)?.total
            val next = _state.value.let { s ->
                s.copy(
                    running = true,
                    paused = exercise.isPaused,
                    bpm = bpm ?: s.bpm,
                    kcal = kcal ?: s.kcal,
                    // Posunutý o pauzy, aby časomiera ukazovala aktívny čas.
                    startedAt = update.activeDurationCheckpoint
                        ?.let { it.time.toEpochMilli() - it.activeDuration.toMillis() }
                        ?: s.startedAt,
                )
            }
            _state.value = next
            PhoneLink.send(app, if (next.paused) "paused" else "running", next.bpm, next.kcal)
        }

        override fun onLapSummaryReceived(lapSummary: ExerciseLapSummary) {}

        override fun onRegistered() {}

        override fun onRegistrationFailed(throwable: Throwable) {
            fail(throwable)
        }

        override fun onAvailabilityChanged(dataType: DataType<*, *>, availability: Availability) {}
    }

    fun start() = launch {
        if (_state.value.running) return@launch
        val caps = client.getCapabilitiesAsync().await()
        val type =
            if (ExerciseType.STRENGTH_TRAINING in caps.supportedExerciseTypes) {
                ExerciseType.STRENGTH_TRAINING
            } else {
                ExerciseType.WORKOUT
            }
        val supported = caps.getExerciseTypeCapabilities(type).supportedDataTypes
        val wanted = setOf<DataType<*, *>>(DataType.HEART_RATE_BPM, DataType.CALORIES_TOTAL)
        val config =
            ExerciseConfig.builder(type)
                .setDataTypes(wanted.filter { it in supported }.toSet())
                .setIsAutoPauseAndResumeEnabled(false)
                .setIsGpsEnabled(false)
                .build()
        client.setUpdateCallback(callback)
        client.startExerciseAsync(config).await()
        WorkoutService.start(app)
        _state.value =
            WorkoutState(running = true, kcal = 0.0, startedAt = System.currentTimeMillis())
        PhoneLink.send(app, "started", null, 0.0)
    }

    /** Tréning bežal, keď appka spadla alebo ju systém ukončil. */
    fun recover() = launch {
        if (_state.value.running) return@launch
        val info = client.getCurrentExerciseInfoAsync().await()
        if (info.exerciseTrackedStatus != ExerciseTrackedStatus.OWNED_EXERCISE_IN_PROGRESS) {
            return@launch
        }
        client.setUpdateCallback(callback)
        WorkoutService.start(app)
        _state.update { it.copy(running = true, error = null) }
    }

    fun pause() = launch { client.pauseExerciseAsync().await() }

    fun resume() = launch { client.resumeExerciseAsync().await() }

    /** Koniec príde cez callback (isEnded), potom [finish]. */
    fun stop() = launch { client.endExerciseAsync().await() }

    fun togglePause() = if (_state.value.paused) resume() else pause()

    fun reportError(message: String) = _state.update { it.copy(error = message) }

    private fun finish() {
        val kcal = _state.value.kcal
        _state.value = WorkoutState()
        WorkoutService.stop(app)
        scope.launch { runCatching { client.clearUpdateCallbackAsync(callback).await() } }
        PhoneLink.send(app, "ended", null, kcal)
    }

    private fun fail(error: Throwable) =
        _state.update { it.copy(error = error.message ?: "Tréning sa nepodaril.") }

    private fun launch(block: suspend () -> Unit) {
        scope.launch {
            try {
                block()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                fail(e)
            }
        }
    }
}
