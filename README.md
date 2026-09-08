# Garmin AutoLap

Garmin AutoLap is a Connect IQ `SimpleDataField` for Garmin Edge computers.
It observes the native Cycling activity, detects configured GPS checkpoints,
and provides a visible `LAP!` prompt, sound cue, and toast notification. The
native Garmin activity and FIT recording remain in control.

The project currently targets the Edge 850. The implementation uses the
native Garmin activity rather than creating FIT laps itself, because Data
Fields do not have access to `ActivityRecording.Session.addLap()`.

## Build

Open the repository root as a VS Code workspace and build the `edge850` target
with the Garmin Connect IQ extension. The project files are at the root:

- `manifest.xml` — Connect IQ application and target device
- `monkey.jungle` — build entry point
- `source/` — Monkey C sources
- `resources/` — settings, strings, and drawables

The supported field is **Garmin AutoLap**. Add it to a native Cycling data
page, then use **Simulation → Activity Data** to provide the GPS stream.

## Checkpoint database

Edit the publishable template `data/checkpoints.csv` with these columns:

`name,latitude,longitude,triggerRadiusMeters,rearmRadiusMeters`

Regenerate the compiled configuration after editing:

```powershell
powershell -ExecutionPolicy Bypass -File tools/generate_checkpoint_config.ps1
```

The generator accepts comma-separated CSV and tab-separated text pasted from a
spreadsheet. Spaces in checkpoint names are supported.

Personal checkpoint data can be kept in the ignored
`data/checkpoints.local.csv` file and passed to the generator explicitly:

```powershell
powershell -ExecutionPolicy Bypass -File tools/generate_checkpoint_config.ps1 `
  -CsvPath data/checkpoints.local.csv
```

Built-in CSV checkpoints are loaded explicitly by `CheckpointManager`. User-
created checkpoints are stored separately on the device.

## Ride behavior

The field displays the nearest approaching checkpoint within 3 km and uses an
adaptive nearby-point scan to keep GPS processing practical. Entering a
checkpoint shows `LAP!`, plays the configured attention tone, and displays a
toast with the checkpoint name.

The `Sound` setting selects `Off`, `Alert`, `Message`, `Start` or `Lap`. Garmin's
System sound category must be enabled for the cue to be audible.

Two lap presses within 10 seconds manage user checkpoints:

- Outside a checkpoint: first lap memoizes the current GPS position; the
  second saves it.
- Inside a saved checkpoint: first lap memoizes its ID; the second removes it.

The 10-second window uses system time and continues while the activity is
auto-paused. Built-in CSV checkpoints are protected from removal.

## Compatibility and limitations

The active target is Edge 850. `onTimerLap()` is retained as the compatibility
path for devices that do not deliver the richer lap callback. Broader device
support, including Edge 530, requires validating notification API support and
adding the device profile to the manifest.
