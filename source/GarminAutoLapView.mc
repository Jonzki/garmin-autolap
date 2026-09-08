import Toybox.Activity;
import Toybox.Attention;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;
using Toybox.Application.Properties;

class GarminAutoLapView extends WatchUi.SimpleDataField {
    const LOGGER_ENABLED = false;
    var mEngine;
    var mManager;
    var mDistance = null;
    var mPromptSuppressedUntil = null;
    var mShowLapPrompt = false;
    var mPromptCheckpoint = null;
    var mHasGps = false;
    var mLastAlertAt = null;
    var mLastLocationRadians = null;
    var mLastLocationAt = null;
    var mPendingLap as PendingLap or Null = null;
    const DOUBLE_LAP_WINDOW_MS = 10000;

    function initialize() {
        SimpleDataField.initialize();
        label = "AUTOLAP";
        mEngine = new CheckpointEngine();
        mManager = new CheckpointManager(mEngine);
        // The published CSV template is empty; local builds may generate
        // built-in checkpoints here without changing the runtime code.
        mManager.loadBuiltInCheckpoints();
        mManager.loadSavedCheckpoints();
        logDebug("Autolap: loaded "
            + mManager.getSavedCheckpointCount()
            + " checkpoints from storage");
    }

    function compute(info as Activity.Info) as Numeric or Duration or String or Null {
        if (info.currentLocation == null) {
            mHasGps = false;
            return "No GPS";
        }

        mHasGps = true;
        var locationRadians = info.currentLocation.toRadians();
        mLastLocationRadians = locationRadians;
        mLastLocationAt = System.getTimer();
        expirePendingLap();
        var checkpoint = mEngine.update(locationRadians);
        var nearest = mEngine.getPreferredCheckpoint();
        if (nearest != null) {
            mDistance = nearest.getLastDistanceMeters();
        } else {
            mDistance = null;
        }

        // If the rider ignored the prompt, allow the same checkpoint to
        // become eligible again after leaving its rearm radius.
        if (mPromptCheckpoint != null) {
            if (mShowLapPrompt && !mPromptCheckpoint.isInsideTriggerRadius()) {
                mShowLapPrompt = false;
            }
            if (mPromptCheckpoint.isArmed()) {
                mShowLapPrompt = false;
                mPromptCheckpoint = null;
            }
        }

        if (checkpoint != null) {
            var now = System.getTimer();
            if (mPromptSuppressedUntil == null || now >= mPromptSuppressedUntil) {
                mShowLapPrompt = true;
                mPromptCheckpoint = checkpoint;
                playLapCue();
                showLapNotification(checkpoint);
                logDebug("DataField checkpoint detected: " + checkpoint.getName());
            }
        }

        return mShowLapPrompt ? "LAP!" : formatDistance();
    }

    // Attention is available to Data Fields. Keep this cue short and local;
    // the visual prompt remains the primary indication on screen.
    function playLapCue() as Void {
        if (!(Attention has :playTone)) {
            return;
        }

        var soundMode = Properties.getValue("soundMode") as Number;
        if (soundMode == 1) {
            Attention.playTone(Attention.TONE_ALERT_HI);
        } else if (soundMode == 2) {
            Attention.playTone(Attention.TONE_MSG);
        } else if (soundMode == 3) {
            Attention.playTone(Attention.TONE_START);
        } else if (soundMode == 10) {
            Attention.playTone(Attention.TONE_LAP);
        }
    }

    function showLapNotification(checkpoint) as Void {
        var now = System.getTimer();
        if (mLastAlertAt != null && now - mLastAlertAt < 5000) {
            return;
        }

        try {
            logDebug("Autolap toast: requesting for " + checkpoint.getName());
            WatchUi.showToast("LAP!  " + checkpoint.getName(), null);
            mLastAlertAt = now;
            logDebug("Autolap toast: request accepted");
        } catch (exception) {
            logDebug("Autolap toast: request failed");
        }
    }

    // Fallback for SDK/device combinations that do not deliver onTimerLap2.
    function onTimerLap() as Void {
            logDebug("Autolap trace: onTimerLap()");
        handleCheckpointLap();
    }

    // Some SDK/device combinations deliver the richer callback, while others
    // only deliver onTimerLap. The checkpoint gesture intentionally accepts
    // either callback and does not depend on the trigger classification.
    function onTimerLap2(trigger) as Boolean {
        logDebug("Autolap trace: onTimerLap2()");
        handleCheckpointLap();
        return true;
    }

    function handleCheckpointLap() as Void {
        var callbackNow = System.getTimer();
        logDebug("Autolap trace: handle lap pending="
            + (mPendingLap != null ? "yes" : "no"));
        mPromptSuppressedUntil = callbackNow + 10000;
        mShowLapPrompt = false;
        mPromptCheckpoint = null;
        logDebug("DataField lap callback");

        var now = System.getTimer();
        if (mPendingLap != null
            && now - mPendingLap.createdAtMillis <= DOUBLE_LAP_WINDOW_MS) {
            logDebug("Autolap trace: second lap kind=" + mPendingLap.kind
                + " age=" + (now - mPendingLap.createdAtMillis) + "ms");
            if (mPendingLap.kind == PENDING_LAP_SAVE) {
                mManager.saveCheckpoint(mPendingLap.location);
                logDebug("Autolap trace: save completed");
                showActionToast("Autolap: Saved Checkpoint.");
            } else if (mManager.removeCheckpointById(mPendingLap.checkpointId)) {
                logDebug("Autolap trace: remove completed");
                showActionToast("Autolap: Checkpoint removed.");
            } else {
                logDebug("Autolap trace: remove failed id="
                    + mPendingLap.checkpointId);
            }
            mPendingLap = null;
            return;
        }

        mPendingLap = null;
        if (mLastLocationRadians == null || mLastLocationAt == null
            || now - mLastLocationAt > 5000) {
            logDebug("Autolap trace: no usable GPS location; age="
                + (mLastLocationAt == null ? "none" : (now - mLastLocationAt)));
            showActionToast("Autolap: GPS unavailable.");
            return;
        }

        var checkpoint = mEngine.findContaining(mLastLocationRadians);
        logDebug("Autolap trace: containing checkpoint="
            + (checkpoint == null ? "none" : checkpoint.getName()));
        if (checkpoint != null && mManager.isSavedCheckpoint(checkpoint)) {
            mPendingLap = new PendingLap(
                PENDING_LAP_REMOVE,
                now,
                null,
                checkpoint.getId()
            );
            logDebug("Autolap trace: pending remove id=" + checkpoint.getId());
            showActionToast("Autolap: Lap again to remove.");
        } else if (checkpoint == null) {
            mPendingLap = new PendingLap(
                PENDING_LAP_SAVE,
                now,
                mLastLocationRadians,
                null
            );
            logDebug("Autolap trace: pending save");
            showActionToast("Autolap: Lap again to save.");
        } else {
            logDebug("Autolap trace: inside built-in checkpoint; no action");
        }
    }

    function expirePendingLap() as Void {
        if (mPendingLap != null
            && System.getTimer() - mPendingLap.createdAtMillis > DOUBLE_LAP_WINDOW_MS) {
            mPendingLap = null;
        }
    }

    function showActionToast(text) as Void {
        try {
            WatchUi.showToast(text, null);
        } catch (exception) {
            logDebug("Autolap action toast failed");
        }
    }

    function onTimerReset() as Void {
        mEngine.reset();
        mPromptSuppressedUntil = null;
        mShowLapPrompt = false;
        mPromptCheckpoint = null;
        mHasGps = false;
        mLastAlertAt = null;
        mLastLocationRadians = null;
        mLastLocationAt = null;
        mPendingLap = null;
    }

    function formatDistance() as String {
        if (mDistance == null) {
            return "-";
        }
        if (mDistance < 100.0) {
            return mDistance.format("%.0d") + " m";
        }
        if (mDistance < 1000.0) {
            var roundedTens = ((mDistance + 5.0) / 10.0).toLong() * 10;
            return roundedTens + " m";
        }
        return (mDistance / 1000.0).format("%.1f") + " km";
    }

    function logDebug(message) as Void {
        if (LOGGER_ENABLED) {
            System.println("Autolap debug: " + message);
        }
    }
}
