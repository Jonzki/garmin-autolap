# Checkpoint Management: Double-Lap Design

Implementation status: complete for the current Edge 850 target. The remaining
items below are validation and broader-device compatibility checks.

## Goal

Use two lap presses as an explicit confirmation gesture for adding or removing
checkpoints while riding. The implementation accepts either lap callback so it
also works on devices or emulators that only deliver `onTimerLap()`.

```text
Manual lap outside checkpoint → memoize GPS location
                              → second manual lap within 10 seconds
                              → save memoized location

Manual lap inside saved checkpoint → memoize checkpoint ID
                                  → second manual lap within 10 seconds
                                  → remove checkpoint from storage
```

Keep the ride-tested sound implementation, toast notifications, radius tuning,
and bearing-aware display independent from this feature.

## API and data model

- `WatchUi.DataField.onTimerLap2()` is preferred when available, with
  `onTimerLap()` as the compatibility fallback. Any lap trigger participates in
  checkpoint management.
- `System.getTimer()` provides the 10-second system-time window, which keeps
  running while the activity is auto-paused.
- `WatchUi.showToast()` provides first-press guidance and success feedback.
- `Application.Storage` persists user-created checkpoints.
- Storage records use one pipe-delimited string per checkpoint so the object
  store only needs to serialize an array of strings.
- `CheckpointManager` loads built-in and saved checkpoints explicitly and owns
  persistence. `CheckpointEngine` owns proximity, arming, and selection logic.

Built-in CSV checkpoints are protected initially; only saved user checkpoints
can be removed.

Each saved checkpoint contains an ID, generated name, latitude, longitude,
trigger radius, and re-arm radius. Storage is versioned and invalid records are
ignored.

## Interaction rules

1. Cache the latest GPS location during `compute()`.
2. On a lap inside a saved checkpoint, memoize that checkpoint ID.
3. On a lap outside all checkpoints, memoize the latest GPS location.
4. A second lap within 10 system seconds executes the pending action.
5. Show a short first-press hint and a success toast.
6. Preserve pending state through `onTimerPause()`.
7. Clear pending state on timeout, missing/stale GPS, or `onTimerReset()`.
8. Treat automatic, distance, position, and manual laps consistently.

The callback does not provide the FIT-record GPS coordinate, so saving uses the
most recent cached position. The implementation should retain its timestamp
and reject it if it becomes too old.

## Completed validation

- Save a checkpoint at an unknown location with two laps.
- Persist checkpoints across Data Field restarts.
- Load multiple serialized checkpoints from storage.
- Remove saved checkpoints with two laps inside their trigger radius.
- Verify storage serialization with the versioned pipe-delimited format.
- Confirm the default `TONE_LAP` setting and existing sound modes.
- Confirm toast and lap-position usability during a real test ride.

## Validation still required

- Confirm whether `onTimerLap2()` is delivered on the Edge 850 device; the
  implementation currently relies safely on `onTimerLap()` when it is not.
- Confirm lap handling while the activity is auto-paused.
- Verify built-in checkpoints cannot be removed after re-enabling their load.
- Test timeout, missing GPS, stale GPS, pause/resume, and reset behavior.
- Ride through a newly saved checkpoint on a later activity.
- Validate the root project on an Edge 530 profile. Notification support may
  require a compatibility fallback because `showToast()` and `onTimerLap2()`
  are not listed for that device in current API documentation.

## Possible optimization

- If profiling ever shows GPS distance calculation is a bottleneck, compare the
  current haversine-style calculation with an equirectangular approximation for
  the sub-5 km operating range. Squared-distance comparisons could avoid
  square roots for trigger and re-arm checks. Do not change this without
  validating radius and display behavior.
