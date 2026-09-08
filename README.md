# Garmin AutoLap

Garmin AutoLap is a Connect IQ `SimpleDataField` for Garmin Edge computers.
It observes the native Cycling activity, detects configured GPS checkpoints,
and provides a visible `LAP!` prompt, sound cue, and native toast where
supported. The
native Garmin activity and FIT recording remain in control.

The project targets Edge 530, 830, 840, 850, 1030, 1040, and 1050. The implementation uses the
native Garmin activity rather than creating FIT laps itself, because Data
Fields do not have access to `ActivityRecording.Session.addLap()`.

## Build

Open the repository root as a VS Code workspace and build a target device with
the Garmin Connect IQ extension. The project files are at the root:

- `manifest.xml` — Connect IQ application and target device
- `monkey.jungle` — build entry point
- `source/` — Monkey C sources
- `resources/` — settings, strings, and drawables

The supported field is **Garmin AutoLap**. Add it to a native Cycling data
page. The field does not have to be in your most active data screen, 
as long as it is present in the activity profile you should get audio ques and notifications.

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
sound cue with the checkpoint name shown in the data field.

The `Sound` setting selects `Off`, `Alert`, `Message`, `Start` or `Lap`. Garmin's
System sound category must be enabled for the cue to be audible.

Two lap presses within 10 seconds manage user checkpoints:

- Outside a checkpoint: first lap memoizes the current GPS position; the
  second saves it.
- Inside a saved checkpoint: first lap memoizes its ID; the second removes it.

The 10-second window uses system time and continues while the activity is
auto-paused. Built-in CSV checkpoints are protected from removal.

## Compatibility and limitations

The project uses `onTimerLap()` as the compatibility callback across the
supported devices. Audio and the data-field display provide feedback on every
target; native toasts are also used where supported.
