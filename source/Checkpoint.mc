import Toybox.Math;
import Toybox.Lang;

class Checkpoint {
    var mName;
    var mLatitudeRadians;
    var mLongitudeRadians;
    var mTriggerRadiusMeters;
    var mRearmRadiusMeters;
    var mId;
    var mArmed = false;
    var mLastDistanceMeters = null;
    var mIncreasingDistanceSamples = 0;
    var mDecreasingDistanceSamples = 0;

    function initialize(
        id as String,
        name as String,
        latitudeDegrees as Numeric,
        longitudeDegrees as Numeric,
        triggerRadiusMeters as Numeric,
        rearmRadiusMeters as Numeric
    ) {
        mId = id;
        mName = name;
        mLatitudeRadians = latitudeDegrees * Math.PI / 180.0;
        mLongitudeRadians = longitudeDegrees * Math.PI / 180.0;
        mTriggerRadiusMeters = triggerRadiusMeters;
        mRearmRadiusMeters = rearmRadiusMeters;
    }

    function update(locationRadians as [Double, Double]) {
        var previousDistance = mLastDistanceMeters;
        mLastDistanceMeters = distanceMeters(locationRadians[0], locationRadians[1]);
        updateDistanceTrend(previousDistance);
        if (!mArmed) {
            if (mLastDistanceMeters >= mRearmRadiusMeters) {
                mArmed = true;
            }
            return false;
        }
        if (mLastDistanceMeters <= mTriggerRadiusMeters) {
            mArmed = false;
            return true;
        }
        return false;
    }

    function reset() {
        mArmed = false;
        mLastDistanceMeters = null;
        mIncreasingDistanceSamples = 0;
        mDecreasingDistanceSamples = 0;
    }

    function getName() { return mName; }
    function getId() { return mId; }
    function getLatitudeDegrees() { return mLatitudeRadians * 180.0 / Math.PI; }
    function getLongitudeDegrees() { return mLongitudeRadians * 180.0 / Math.PI; }
    function getTriggerRadiusMeters() { return mTriggerRadiusMeters; }
    function getRearmRadiusMeters() { return mRearmRadiusMeters; }
    function distanceTo(locationRadians as [Double, Double]) {
        return distanceMeters(locationRadians[0], locationRadians[1]);
    }
    function getLastDistanceMeters() { return mLastDistanceMeters; }
    function isArmed() as Boolean { return mArmed; }
    function isInsideTriggerRadius() as Boolean {
        return mLastDistanceMeters != null && mLastDistanceMeters <= mTriggerRadiusMeters;
    }

    function isMovingAway() as Boolean {
        return mIncreasingDistanceSamples >= 2;
    }

    function updateDistanceTrend(previousDistance) as Void {
        if (previousDistance == null) {
            return;
        }

        var delta = mLastDistanceMeters - previousDistance;
        // Ignore small changes so normal GPS noise does not flip the trend.
        if (delta > 3.0) {
            mIncreasingDistanceSamples += 1;
            mDecreasingDistanceSamples = 0;
        } else if (delta < -3.0) {
            mDecreasingDistanceSamples += 1;
            mIncreasingDistanceSamples = 0;
        }

        if (mDecreasingDistanceSamples >= 2) {
            mIncreasingDistanceSamples = 0;
        }
    }

    function distanceMeters(latitudeRadians, longitudeRadians) {
        // This haversine-style calculation is intentionally kept for now. For
        // the sub-5 km operating range, an equirectangular approximation (and
        // squared-distance comparisons where possible) could be investigated
        // later if profiling shows distance calculation is a bottleneck.
        var deltaLatitude = latitudeRadians - mLatitudeRadians;
        var deltaLongitude = longitudeRadians - mLongitudeRadians;
        var a = Math.sin(deltaLatitude / 2.0) * Math.sin(deltaLatitude / 2.0)
            + Math.cos(mLatitudeRadians) * Math.cos(latitudeRadians)
            * Math.sin(deltaLongitude / 2.0) * Math.sin(deltaLongitude / 2.0);
        return 6371000.0 * 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a));
    }
}
