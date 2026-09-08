import Toybox.System;
import Toybox.Lang;

class CheckpointEngine {
    var mCheckpoints as Array<Checkpoint> = new Array<Checkpoint>[0];
    var mNearbyCheckpoints as Array<Checkpoint> = new Array<Checkpoint>[0];
    var mTick = 0;
    
    const FULL_SCAN_INTERVAL = 10;
    const NEARBY_RADIUS_METERS = 3000.0;
    const NEARBY_EXIT_RADIUS_METERS = 3200.0;
    const DISPLAY_RADIUS_METERS = 3000.0;

    // Enable to log checkpoint selection logic into Debug console.
    const DEBUG_LOGGING = false;

    function initialize() {
    }

    function findAt(
        locationRadians as [Double, Double],
        radiusMeters as Numeric
    ) as Checkpoint or Null {
        var closest = null;
        var closestDistance = null;
        for (var index = 0; index < mCheckpoints.size(); index += 1) {
            var checkpoint = mCheckpoints[index];
            var distance = checkpoint.distanceTo(locationRadians);
            if (distance <= radiusMeters
                && (closestDistance == null || distance < closestDistance)) {
                closest = checkpoint;
                closestDistance = distance;
            }
        }
        return closest;
    }

    function findContaining(locationRadians as [Double, Double]) as Checkpoint or Null {
        var closest = null;
        var closestDistance = null;
        for (var index = 0; index < mCheckpoints.size(); index += 1) {
            var checkpoint = mCheckpoints[index];
            var distance = checkpoint.distanceTo(locationRadians);
            if (distance <= checkpoint.getTriggerRadiusMeters()
                && (closestDistance == null || distance < closestDistance)) {
                closest = checkpoint;
                closestDistance = distance;
            }
        }
        return closest;
    }

    function addCheckpoint(checkpoint as Checkpoint) as Checkpoint {
        mCheckpoints.add(checkpoint);
        return checkpoint;
    }

    function removeCheckpoint(checkpoint as Checkpoint) as Void {
        if (mCheckpoints.indexOf(checkpoint) >= 0) {
            mCheckpoints.remove(checkpoint);
        }
        if (mNearbyCheckpoints.indexOf(checkpoint) >= 0) {
            mNearbyCheckpoints.remove(checkpoint);
        }
    }

    function removeCheckpointById(id as String) as Void {
        if(id == null || id.length() == 0){
            return;
        }

        for (var index = 0; index < mCheckpoints.size(); index += 1) {
            if (mCheckpoints[index].getId() == id) {
                removeCheckpoint(mCheckpoints[index]);
                return;
            }
        }
    }

    function update(locationRadians as [Double, Double]) as Checkpoint or Null {
        mTick += 1;
        var fullScan = (mTick == 1 || mTick % FULL_SCAN_INTERVAL == 0);
        var pointsToUpdate = fullScan ? mCheckpoints : mNearbyCheckpoints;

        var triggered = null;
        for (var index = 0; index < pointsToUpdate.size(); index += 1) {
            if (pointsToUpdate[index].update(locationRadians) && triggered == null) {
                triggered = pointsToUpdate[index];
            }
        }

        if (fullScan) {
            rebuildNearbyCheckpoints();
        }
        return triggered;
    }

    function rebuildNearbyCheckpoints() as Void {
        var nextNearby = new Array<Checkpoint>[0];
        for (var index = 0; index < mCheckpoints.size(); index += 1) {
            var checkpoint = mCheckpoints[index];
            var distance = checkpoint.getLastDistanceMeters();
            if (distance == null) {
                continue;
            }

            var wasNearby = mNearbyCheckpoints.indexOf(checkpoint) >= 0;
            if ((wasNearby && distance <= NEARBY_EXIT_RADIUS_METERS)
                || (!wasNearby && distance <= NEARBY_RADIUS_METERS)) {
                nextNearby.add(checkpoint);
            }
        }
        mNearbyCheckpoints = nextNearby;
    }

    function getPreferredCheckpoint() as Checkpoint or Null {
        var nearest = null;
        var nearestDistance = null;
        var nearestApproaching = null;
        var nearestApproachingDistance = null;
        for (var index = 0; index < mCheckpoints.size(); index += 1) {
            var checkpoint = mCheckpoints[index];
            var distance = checkpoint.getLastDistanceMeters();
            if (distance == null || distance > DISPLAY_RADIUS_METERS) {
                continue;
            }
            if (DEBUG_LOGGING) {
                System.println("Autolap candidate: " + checkpoint.getName()
                    + " distance=" + distance.format("%.0f") + "m trend="
                    + (checkpoint.isMovingAway() ? "away" : "approaching"));
            }
            if (nearestDistance == null || distance < nearestDistance) {
                nearest = checkpoint;
                nearestDistance = distance;
            }
            if (!checkpoint.isMovingAway()
                && (nearestApproachingDistance == null || distance < nearestApproachingDistance)) {
                nearestApproaching = checkpoint;
                nearestApproachingDistance = distance;
            }
        }
        // Do not display a checkpoint whose distance is increasing. It can
        // become eligible again naturally once the rider turns around.
        var selected = nearestApproaching;
        if (DEBUG_LOGGING) {
            if (nearest == null) {
                System.println("Autolap closest: none within 3000m");
            } else {
                System.println("Autolap closest: " + nearest.getName()
                    + " distance=" + nearest.getLastDistanceMeters().format("%.0f")
                    + "m trend=" + (nearest.isMovingAway() ? "away" : "approaching"));
            }
            if (selected == null) {
                System.println("Autolap selection: none approaching within 3000m");
            } else {
                System.println("Autolap selection: " + selected.getName()
                    + " distance=" + selected.getLastDistanceMeters().format("%.0f")
                    + "m reason=not moving away");
            }
        }
        return selected;
    }

    function reset() as Void {
        mNearbyCheckpoints = new Array<Checkpoint>[0];
        mTick = 0;
        for (var index = 0; index < mCheckpoints.size(); index += 1) {
            mCheckpoints[index].reset();
        }
    }
}
