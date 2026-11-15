package com.rejnox.rejnox.wear

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/** Príkazy z telefónu (stop / pause / resume), aj keď appka nebeží na popredí. */
class CommandListenerService : WearableListenerService() {
    override fun onMessageReceived(event: MessageEvent) {
        if (event.path != PhoneLink.COMMAND_PATH) return
        WorkoutController.init(this)
        val workout = WorkoutController.state.value
        when (String(event.data)) {
            "stop" -> if (workout.running) WorkoutController.stop()
            "pause" -> if (workout.running && !workout.paused) WorkoutController.pause()
            "resume" -> if (workout.paused) WorkoutController.resume()
        }
    }
}
