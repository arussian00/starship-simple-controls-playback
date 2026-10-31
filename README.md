# Starship simple controls playback

The Starship flight from [matlab-rocket-sim](https://github.com/arussian00/matlab-rocket-sim) runs exactly as it does there: ideal steering on the ascent, and that sim's own return controller for the booster tower catch and the ship's belly-flop and splashdown. Along that ascent, the pitch controller from [rocket-controls-simulink](https://github.com/arussian00/rocket-controls-simulink) is simulated **open loop** and played back in time with one mission-control window.

The controller is shown. It does not fly the vehicle. Catch miss and splashdown error are the sim's numbers.

The sister repo [starship-closed-loop-sim](https://github.com/arussian00/starship-closed-loop-sim) is the run where the controller does fly the vehicle. Use the same window and the same panel positions (below) so the two can be compared. This window is labeled **PLAYBACK (open loop)**. That one is labeled **CLOSED LOOP**.

Both source repos are dependencies. This repo does not copy them and does not use git submodules.

## MATLAB Online

In the Command Window:

```matlab
gitclone("https://github.com/arussian00/starship-simple-controls-playback.git");
cd starship-simple-controls-playback
run_playback
```

`gitclone` needs R2023b or newer. MATLAB Online is current. The first run clones `matlab-rocket-sim` and `rocket-controls-simulink` into `/MATLAB Drive/Repositories` if those folders are not already there, then adds them to the path.

Needs **Simulink** and **Control System Toolbox**, because the controller is `boosterPitchTVC` built by `build_pitch_model` and simulated with `sim`. The Starship flight itself is core MATLAB.

| Command | What you get |
|---|---|
| `run_playback` | Flight summary, open-loop controller summary, then the animation |
| `run_playback(2)` | Same animation, twice as fast |
| `run_playback(1, false)` | Summaries only, no animation |
| `out = run_playback(1, false);` | Also returns the histories and `out.summary` |

`out.summary` is the comparison block: `catchMiss_m`, `splashdownError_m`, `peakAttErr_deg`, `peakGimbal_deg`, `tOnAngle_s`, `tOnRate_s`, `peakQAlpha_kPa_deg`, and flags for load relief, moving CG, slosh, bending, grid fins, and Monte Carlo.

## What is different from the closed-loop repo

| | This repo | starship-closed-loop-sim |
|---|---|---|
| Who flies the rocket | Ideal steering on ascent, then the sim's return controller | The pitch controller (and later loops) command the vehicle |
| Controller | `sim` of `boosterPitchTVC` along the recorded ascent | The same model, closed with the vehicle |
| Catch and splashdown | Identical to `rocket_starship_sim` | They move when the controller flies the stack |
| On-screen label | PLAYBACK (open loop) | CLOSED LOOP |
| Window | One figure, same panel rectangles | One figure, same panel rectangles |

## Where the controller inputs come from

They are computed from **this** sim run, not from `data/superheavy_booster_trajectory.csv`.

`trajectory_from_sim` walks the stack-ascent part of `fullB` and builds the same columns `make_booster_trajectory` writes: time, altitude, speed, Mach, dynamic pressure, mass, throttle, thrust, length, CG, gimbal arm, CP, inertia, static margin, `mu`, `lambda`, and `tvc_active`. Breakpoints are that run's ode45 samples, not the 1 Hz CSV. Geometry stays the controls-repo assumption (uniform rod, CG at mid-length, `CNa` and static margin from `vehicle_params`) so a later change there is picked up.

The attitude reference is the sim's body pitch minus the flight-path angle. `boosterPitchTVC` measures pitch from trim, which is the velocity vector. Ideal steering holds that difference near zero on the gravity turn, and at the pitch-kick angle (0.8 deg) while the nose is held off the velocity vector. The absolute pitch program is tens of degrees and is not a command for this plant.

Wind is the controls-repo model, applied only inside the pitch playback. On main that is the design gust in `vehicle_params` (15 m/s step at t = 14 s). The Starship sim still flies in its own still air (`P.wind = 0`), so the gust cannot change the trajectory. The main-branch plant adds `gustAccPerWind * wind` with a constant gain, so the wind block is driven with the equivalent acceleration `-(lambda/V)*w` and the gain is set to 1. That is the moment `lambda*(theta - w/V)`.

`apply_flight_schedule` then points the Simulink `mu`, `lambda`, and `1/mu` lookups at this table. `design_pitch_controller` supplies the cascade. `build_pitch_model` writes `boosterPitchTVC.slx` in this folder (gitignored). `sim` runs to the end of the ascent.

## Mission-control layout

One figure named `Starship mission control - PLAYBACK (open loop)`. It opens maximized. Axes use normalized positions, so resizing the window resizes the panels. Columns match `animateStarship`:

| Column | x | width |
|---|---|---|
| 1 | 0.035 | 0.20 |
| 2 | 0.285 | 0.20 |
| 3 | 0.535 | 0.20 |
| 4 | 0.785 | 0.20 |

| Row | y | height | Panels, left to right |
|---|---|---|---|
| Scene | 0.700 | 0.230 | Overview, Earth, Super Heavy camera, Starship camera |
| Upper telemetry | 0.490 | 0.175 | Altitude, speed, g-load, dynamic pressure |
| Lower telemetry | 0.280 | 0.175 | Throttle, AoA, mass, heating |
| Controls | 0.040 | 0.205 | Attitude command / response / error, gimbal angle and rate vs the stops, AoA and q\*alpha, grid fins |

The scene and the eight telemetry graphs are the `animateStarship` set, on that function's time warp, for both vehicles. The controls row is synchronized to the same clock. Pitch-TVC traces cover the ascent and then stop. Grid-fin force is the sim's return controller (`aux.finForce`). A controller deflection is drawn on that panel only when a grid-fin signal exists.

`mission_control_layout.m` is the list of those rectangles. The closed-loop window should use the same ones.

## When controls steps 3-6 merge

Playback tracks **main** today. `playback_config.m` can name a branch for either dependency; `setup_paths` checks it out if it is not already current. Empty means "leave the clone as it is".

| Step | On the controls repo | What playback does when it appears |
|---|---|---|
| 3, max-q load relief (`lr_blend`, branch `cursor/maxq-load-relief-bd91`) | `load_relief_wind`, `schedWind`, `schedSpeed`, `schedQdyn`, logged `alpha` and `qAlpha` | Wind switches to the shear plus 1-cosine gust. If the built model has an `lrBlend` gain, that blend is taken from `vehicle_params`. Logged alpha and q\*alpha replace the post-processed ones. The summary line `load relief` reads `on`. |
| 4, moving CG, slosh, bending | `apply_cg_schedule` or `cg_schedule`, `apply_slosh` or `slosh_schedule`, `apply_bending` or `bending_schedule` | The first function that exists is called as `f(traj, V, D)`, or with fewer arguments if that is all it takes. Scalar gains the model references are copied from `vehicle_params` when the workspace does not already have them. |
| 5, grid fins and descent | `grid_fin_command(traj, V)`, or a logged `finDefl` / `gridFin` / `deltaFin` / `fin` | The grid-fin panel adds deflection next to the sim's fin force. Until then the panel says the controls model has no grid-fin loop. |
| 6, Monte Carlo and tuner | `run_pitch_monte_carlo` or `pitch_monte_carlo` | Reported as present. Playback does not launch it; it stays one deterministic ascent. `open_pitch_tuner` already exists on main and is not opened. |

Anything in that list that is missing is skipped. The ascent playback still runs.

## Files

| File | Role |
|---|---|
| `run_playback.m` | Entry point |
| `setup_paths.m` | Find or clone the two source repos, then `addpath` |
| `playback_config.m` | URLs and optional branches |
| `run_starship_flight.m` | `rocket_starship_sim` steps 1-8, no animation and no extra figures |
| `trajectory_from_sim.m` | Ascent schedule and attitude reference from that run |
| `playback_wind.m` | Controls-repo gust (or `load_relief_wind` when it exists) |
| `run_open_loop_playback.m` | Build `boosterPitchTVC`, `sim` along the ascent, collect the traces |
| `controls_extensions.m` | Hooks for steps 3-6 |
| `mission_control_layout.m` | Shared panel positions |
| `animate_playback.m` | The one mission-control window |

## Troubleshooting

| Symptom | What to do |
|---|---|
| `gitclone` is not found | Clone this repo from the Files panel (right-click, Source Control, Clone Repository), `cd` into it, and run `run_playback`. |
| `Cannot find matlab-rocket-sim` | Let `setup_paths` clone it, or clone it yourself under `/MATLAB Drive/Repositories`. |
| `build_pitch_model:NeedsSimulink` | This playback needs Simulink. The flight summary has already printed. |
| A missing `tf` / `pid` | Control System Toolbox is required by `design_pitch_controller`. |
| `uitable` cell-array error | This repo does not build a `uitable`. If a dependency does, its cells have to be numeric or char, not string scalars. |
| A scope warns about `LimitDataPoints` | The controls model logs with `MaxDataPoints` set to `inf`. |
| `isstable` complains about internal delays | Margins stay inside the controls repo, which uses a Padé model before `isstable` / `allmargin`. Playback does not call `isstable` on the delayed loop. |
| `NumberOfTableDimensions` | Not set here. The 1-D lookups use `BreakpointsForDimension1` and `Table`. |
| A rejected colour or annotation | Cosmetic `set_param` calls are wrapped so a rejected name does not stop the run. |
