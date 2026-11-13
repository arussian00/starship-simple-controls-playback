function varargout = run_playback(speed, animate)
%RUN_PLAYBACK  Starship flight, open-loop pitch playback, one mission-control window.
%
%   run_playback
%   run_playback(2)            twice as fast
%   run_playback(1, false)     print the summary and skip the animation
%
%   MATLAB Online, from this folder, after a git checkout or git pull
%   done with !git (those files are invisible until the path is refreshed):
%
%       addpath(pwd)
%       rehash
%       clear functions
%       run_playback
%
%   The Starship trajectory is matlab-rocket-sim with ideal steering on the
%   ascent and that sim's own return controller. boosterPitchTVC is simulated
%   along the ascent only. Its gimbal is not fed back into the flight. If
%   the controller cannot be built or simulated, the flight animation still
%   plays and the window says controller unavailable.
%
%   Assign the output if you want the histories:
%       out = run_playback(1, false);

% pwd's directory cache does not notice files !git just wrote. Putting this
% folder on the search path and rehashing makes the sibling .m files visible.
here = fileparts(mfilename('fullpath'));
if isempty(here)
    here = pwd;
end
addpath(here);
rehash;

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

traj = [];
info = empty_info();
try
    V = vehicle_params();
    [traj, info] = trajectory_from_sim(flight, V);
    fprintf('Controller inputs from this run (not the controls-repo CSV).\n');
    fprintf('  %s\n', info.reference);
    fprintf('  Wind: %s\n', info.windLabel);
    fprintf('  Ascent schedule: %.0f s, %d samples, peak |pitch - flight path| = %.3f deg\n', ...
        info.tStop, height(traj), info.peakThetaRefDeg);
    pb = run_open_loop_playback(traj, info, V);
catch ME
    pb = controller_unavailable(ME.message);
    fprintf('\n%s\n', pb.controllerNote);
end
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


function info = empty_info()
info.windLabel = '';
info.peakThetaRefDeg = NaN;
info.reference = '';
info.tStop = NaN;
end


function pb = controller_unavailable(reason)
reason = flatten_message(reason);
pb.mode = 'playback';
pb.openLoop = true;
pb.unavailable = true;
pb.controllerNote = ['controller unavailable: ' reason];
n = 2;
nanCol = nan(n, 1);
pb.t = [0; 1];
pb.thetaCmdDeg = nanCol;
pb.thetaDeg = nanCol;
pb.errDeg = nanCol;
pb.pitchRateDeg = nanCol;
pb.deltaDeg = nanCol;
pb.deltaCmdDeg = nanCol;
pb.rateDeg = nanCol;
pb.alphaDeg = nanCol;
pb.qAlpha_kPa_deg = nanCol;
pb.deltaMaxDeg = 0;
pb.rateMaxDeg = 0;
pb.plantWind = 'controller unavailable';
pb.windLabel = 'controller unavailable';
pb.reference = '';
pb.peakThetaRefDeg = NaN;
pb.scheduledWind = false;
pb.features.loadRelief = false;
pb.features.movingCg = false;
pb.features.slosh = false;
pb.features.bending = false;
pb.features.gridFins = false;
pb.features.monteCarlo = false;
pb.features.notes = {pb.controllerNote};
pb.finT = [];
pb.finDeg = [];
pb.finSource = '';
pb.hasFinCommand = false;
pb.metrics.peakAttErr_deg = NaN;
pb.metrics.peakGimbal_deg = NaN;
pb.metrics.peakRate_deg = NaN;
pb.metrics.tOnAngle_s = NaN;
pb.metrics.tOnRate_s = NaN;
pb.metrics.peakAlpha_deg = NaN;
pb.metrics.peakQAlpha_kPa_deg = NaN;
end


function text = flatten_message(text)
if ~ischar(text)
    text = char(text);
end
text = strrep(text, sprintf('\n'), ' ');
text = strrep(text, sprintf('\r'), ' ');
text = regexprep(text, ' +', ' ');
text = strtrim(text);
end


function print_playback_summary(flight, pb, info)
M = pb.metrics;
catchMiss = flight.metricsB.miss;
splash = flight.metricsS.miss;
fprintf('\n================ PLAYBACK (open loop) ================\n');
if isfield(pb, 'controllerNote') && ~isempty(pb.controllerNote)
    fprintf('%s\n', pb.controllerNote);
    fprintf('The flight animation still runs. The controller did not.\n');
else
    fprintf('The Starship trajectory above is the sim, unchanged.\n');
    fprintf('The pitch controller was played back along the ascent and did not fly the vehicle.\n');
end
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
