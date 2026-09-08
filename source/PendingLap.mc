import Toybox.Lang;

// Operation values owned by the PendingLap model.
const PENDING_LAP_SAVE = 1;
const PENDING_LAP_REMOVE = 2;

class PendingLap {
    // Pending operation: PENDING_LAP_SAVE or PENDING_LAP_REMOVE.
    var kind as Number;
    // System timer value when the first lap was received, in milliseconds.
    var createdAtMillis as Number;
    // Cached GPS position used when saving a new checkpoint.
    var location as [Double, Double] or Null;
    // Stable ID of the saved checkpoint being removed.
    var checkpointId as String or Null;

    function initialize(
        kind as Number,
        createdAtMillis as Number,
        location as [Double, Double] or Null,
        checkpointId as String or Null
    ) {
        self.kind = kind;
        self.createdAtMillis = createdAtMillis;
        self.location = location;
        self.checkpointId = checkpointId;
    }
}
