function varargout = run_playback(speed, animate)
%RUN_PLAYBACK  Starship flight, open-loop pitch playback, one mission-control window.
%
%   run_playback
%   run_playback(2)            twice as fast
%   run_playback(1, false)     print the summary and skip the animation
%
%   MATLAB Online, from this folder (setup_paths clones the two source
%   repos if they are not already under /MATLAB Drive/Repositories):
%
%       gitclone("https://github.com/arussian00/starship-simple-controls-playback.git");
%       cd starship-simple-controls-playback
%       run_playback
%
%   The Starship trajectory is matlab-rocket-sim with ideal steering on the
%   ascent and that sim's own return controller. boosterPitchTVC is simulated
%   along the ascent only. Its gimbal is not fed back into the flight.
%
%   Assign the output if you want the histories:
%       out = run_playback(1, false);

if nargin < 1 || isempty(speed)
    speed = 1;
end
if nargin < 2 || isempty(animate)
    animate = true;
end
if ~(isscalar(speed) && isnumeric(speed) && speed > 0)
    error('run_playback:Speed', 'speed must be a positive number.');
end
animate = logical(animate);

close all
paths = setup_paths();
flight = run_starship_flight();

V = vehicle_params();
[traj, info] = trajectory_from_sim(flight, V);
fprintf('Controller inputs from this run (not the controls-repo CSV).\n');
fprintf('  %s\n', info.reference);
fprintf('  Wind: %s\n', info.windLabel);
fprintf('  Ascent schedule: %.0f s, %d samples, peak |pitch - flight path| = %.3f deg\n', ...
    info.tStop, height(traj), info.peakThetaRefDeg);

pb = run_open_loop_playback(traj, info, V);
print_playback_summary(flight, pb, info);

result.paths = paths;
result.flight = flight;
result.trajectory = traj;
result.playback = pb;
result.summary = summary_struct(flight, pb, info);

if animate
    animate_playback(flight, pb, speed);
end
if nargout > 0
    varargout{1} = result;
end
end


function print_playback_summary(flight, pb, info)
M = pb.metrics;
catchMiss = flight.metricsB.miss;
splash = flight.metricsS.miss;
fprintf('\n================ PLAYBACK (open loop) ================\n');
fprintf('The Starship trajectory above is the sim, unchanged.\n');
fprintf('The pitch controller was played back along the ascent and did not fly the vehicle.\n');
fprintf('Catch miss distance        : %9.2f m   (sim tower catch)\n', catchMiss);
fprintf('Splashdown error           : %9.2f m   (sim, vs its splashdown target)\n', splash);
fprintf('Attitude reference         : sim pitch minus flight-path angle\n');
fprintf('Peak |attitude reference|  : %9.3f deg\n', info.peakThetaRefDeg);
fprintf('Wind                       : %s\n', info.windLabel);
fprintf('Plant wind input           : %s\n', pb.plantWind);
fprintf('Peak |attitude error|      : %9.3f deg   (command minus response)\n', M.peakAttErr_deg);
fprintf('Peak |gimbal|              : %9.3f deg   (stop %.0f deg)\n', M.peakGimbal_deg, pb.deltaMaxDeg);
fprintf('Peak |gimbal rate|         : %9.3f deg/s (stop %.0f deg/s)\n', M.peakRate_deg, pb.rateMaxDeg);
fprintf('Time on the angle stops    : %9.3f s\n', M.tOnAngle_s);
fprintf('Time on the rate stops     : %9.3f s\n', M.tOnRate_s);
fprintf('Peak |alpha|               : %9.3f deg\n', M.peakAlpha_deg);
fprintf('Peak |q*alpha|             : %9.3f kPa deg\n', M.peakQAlpha_kPa_deg);
fprintf('Features: load relief %s, moving CG %s, slosh %s, bending %s, grid fins %s, Monte Carlo %s\n', ...
    on_off(pb.features.loadRelief), on_off(pb.features.movingCg), ...
    on_off(pb.features.slosh), on_off(pb.features.bending), ...
    on_off(pb.features.gridFins), on_off(pb.features.monteCarlo));
for k = 1:numel(pb.features.notes)
    fprintf('  note: %s\n', pb.features.notes{k});
end
fprintf('=======================================================\n\n');
end


function S = summary_struct(flight, pb, info)
S.mode = 'playback';
S.openLoop = true;
S.catchMiss_m = flight.metricsB.miss;
S.splashdownError_m = flight.metricsS.miss;
S.catchSuccess = flight.metricsB.success;
S.splashdownSuccess = flight.metricsS.success;
S.tSep_s = flight.tSep;
S.peakThetaRef_deg = info.peakThetaRefDeg;
S.wind = info.windLabel;
S.peakAttErr_deg = pb.metrics.peakAttErr_deg;
S.peakGimbal_deg = pb.metrics.peakGimbal_deg;
S.peakRate_deg = pb.metrics.peakRate_deg;
S.tOnAngle_s = pb.metrics.tOnAngle_s;
S.tOnRate_s = pb.metrics.tOnRate_s;
S.peakAlpha_deg = pb.metrics.peakAlpha_deg;
S.peakQAlpha_kPa_deg = pb.metrics.peakQAlpha_kPa_deg;
S.loadRelief = pb.features.loadRelief;
S.movingCg = pb.features.movingCg;
S.slosh = pb.features.slosh;
S.bending = pb.features.bending;
S.gridFins = pb.features.gridFins;
S.monteCarlo = pb.features.monteCarlo;
end


function label = on_off(flag)
if flag
    label = 'on';
else
    label = 'off';
end
end
