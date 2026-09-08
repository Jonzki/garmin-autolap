using Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

class CheckpointManager {
    const LOGGER_ENABLED = false;
    const STORAGE_KEY = "savedCheckpoints";
    const STORAGE_VERSION_KEY = "savedCheckpointsVersion";
    const STORAGE_VERSION = 3;
    const DEFAULT_TRIGGER_RADIUS_METERS = 50;
    const DEFAULT_REARM_RADIUS_METERS = 80;

    var mEngine as CheckpointEngine;
    var mSavedCheckpoints as Array<Checkpoint> = new Array<Checkpoint>[0];

    function initialize(engine as CheckpointEngine) {
        mEngine = engine;
    }

    // Kept separate so the published build can omit this call and ship with
    // only user-created checkpoints.
    function loadBuiltInCheckpoints() as Void {
        var definitions = CheckpointConfig.CHECKPOINTS;
        for (var index = 0; index < definitions.size(); index += 1) {
            var checkpoint = deserialize(definitions[index]);
            if (checkpoint != null) {
                mEngine.addCheckpoint(checkpoint);
            }
        }
    }

    function loadSavedCheckpoints() as Void {
        mSavedCheckpoints = new Array<Checkpoint>[0];
        var version = Storage.getValue(STORAGE_VERSION_KEY);
            logDebug("Autolap storage: version="
            + (version == null ? "null" : version));
        if (version != null && version.toNumber() != STORAGE_VERSION) {
            logDebug("Autolap: ignoring checkpoint storage version=" + version);
            return;
        }
        var stored = Storage.getValue(STORAGE_KEY);
        logDebug("Autolap storage: raw type="
            + (stored == null ? "null" : (stored instanceof Array ? "array" : "other"))
            + " count=" + (stored == null ? "null" : stored.size()));
        if (stored == null || !(stored instanceof Array)) {
            return;
        }

        for (var index = 0; index < stored.size(); index += 1) {
            logDebug("Autolap storage: record[" + index + "]=" + stored[index]);
            var checkpoint = deserialize(stored[index]);
            if (checkpoint != null) {
                mSavedCheckpoints.add(checkpoint);
                mEngine.addCheckpoint(checkpoint);
            } else {
                logDebug("Autolap storage: rejected record[" + index + "]");
            }
        }
    }

    function saveCheckpoint(locationRadians as [Double, Double]) as Checkpoint {
        var nextNumber = mSavedCheckpoints.size() + 1;
        var checkpoint = new Checkpoint(
            "saved-" + System.getTimer(),
            "Saved checkpoint " + nextNumber,
            locationRadians[0] * 180.0 / Math.PI,
            locationRadians[1] * 180.0 / Math.PI,
            DEFAULT_TRIGGER_RADIUS_METERS,
            DEFAULT_REARM_RADIUS_METERS
        );
        mSavedCheckpoints.add(checkpoint);
        persist();
        logDebug("Autolap trace: persisted " + checkpoint.getId()
            + "; storage count=" + mSavedCheckpoints.size());
        return mEngine.addCheckpoint(checkpoint);
    }

    function removeCheckpointById(id as String) as Lang.Boolean {
        var removed = false;
        for (var index = 0; index < mSavedCheckpoints.size(); index += 1) {
            var checkpoint = mSavedCheckpoints[index];
            if (checkpoint.getId() == id) {
                mSavedCheckpoints.remove(checkpoint);
                removed = true;
                break;
            }
        }
        if (!removed) {
            logDebug("Autolap trace: no stored checkpoint for id=" + id);
            return false;
        }
        mEngine.removeCheckpointById(id);
        persist();
        return true;
    }

    function isSavedCheckpoint(checkpoint as Checkpoint) as Lang.Boolean {
        var id = checkpoint.getId();
        for (var index = 0; index < mSavedCheckpoints.size(); index += 1) {
            if (mSavedCheckpoints[index].getId() == id) {
                return true;
            }
        }
        return false;
    }

    function getSavedCheckpointCount() as Number {
        return mSavedCheckpoints.size();
    }

    function serialize(checkpoint as Checkpoint) as String {
        return checkpoint.getId() + "|"
            + checkpoint.getName() + "|"
            + checkpoint.getLatitudeDegrees().format("%.6f") + "|"
            + checkpoint.getLongitudeDegrees().format("%.6f") + "|"
            + checkpoint.getTriggerRadiusMeters().format("%.0f") + "|"
            + checkpoint.getRearmRadiusMeters().format("%.0f");
    }

    function deserialize(serialized as String) as Checkpoint or Null {
        if (serialized == null || serialized.length() == 0) {
            return null;
        }

        var fields = splitSerialized(serialized);
        logDebug("Autolap storage: parsed field count=" + fields.size());
        if (fields.size() != 6) {
            logDebug("Autolap: invalid checkpoint record=" + serialized);
            return null;
        }

        var latitude = fields[2].toFloat();
        var longitude = fields[3].toFloat();
        var triggerRadius = fields[4].toFloat();
        var rearmRadius = fields[5].toFloat();
        logDebug("Autolap storage: parsed values lat=" + latitude
            + " lon=" + longitude + " trigger=" + triggerRadius
            + " rearm=" + rearmRadius);
        if (latitude == null || longitude == null
            || triggerRadius == null || rearmRadius == null) {
            logDebug("Autolap storage: numeric conversion failed");
            return null;
        }

        return new Checkpoint(
            fields[0],
            fields[1],
            latitude,
            longitude,
            triggerRadius,
            rearmRadius
        );
    }

    // String.split() is not available in the SDK profile used by the Edge
    // 850 target, so keep the equivalent small helper local to the manager.
    function splitSerialized(value as String) as Array<String> {
        var fields = [];
        var start = 0;
        while (true) {
            var remainder = value.substring(start, null);
            var separator = remainder.find("|");
            if (separator == null) {
                fields.add(remainder);
                break;
            }
            fields.add(remainder.substring(0, separator));
            start += separator + 1;
        }
        return fields;
    }

    function persist() as Void {
        Storage.setValue(STORAGE_VERSION_KEY, STORAGE_VERSION);
        // Store one pipe-delimited string per checkpoint. This avoids nested
        // dictionaries and mixed numeric types in the device object store.
        var stored = [];
        for (var index = 0; index < mSavedCheckpoints.size(); index += 1) {
            stored.add(serialize(mSavedCheckpoints[index]));
        }
        Storage.setValue(STORAGE_KEY, stored);
    }

    function logDebug(message as String) as Void {
        if (LOGGER_ENABLED) {
            System.println("Autolap debug: " + message);
        }
    }
}
