function pb = run_open_loop_playback(traj, info, V)
%RUN_OPEN_LOOP_PLAYBACK  Simulink pitch response along the sim trajectory.
%
%   pb = run_open_loop_playback(traj, info, V)
%
%   Designs the controls-repo cascade (design_pitch_controller), builds
%   boosterPitchTVC with build_pitch_model when Simulink is available, and
%   runs sim() with the ascent schedule from trajectory_from_sim. The gimbal
%   is not applied to the Starship flight. Workspace variables are the
%   interface the controls repo already uses; this file only retargets the
%   attitude Step (and, on main, the plant wind Step) at those variables.
%
%   On main the plant is
%       theta'' = mu(t)*sin(delta) + lambda(t)*theta + gustAccPerWind*wind.
%   gustAccPerWind is a constant, so the wind input is set to the equivalent
%   acceleration -(lambda/V)*w and the gain is set to 1. That is the same
%   moment as lambda*(theta - w/V). Alpha and q*alpha are computed from that
%   definition for the plots.
%
%   When the merged model already forms alpha = theta - wind/speed and looks
%   up schedWind (step 3), the real wind is published in schedWind and the
%   extra gust Step is held at 0 so it is not added twice. Logged alpha and
%   qAlpha are used when those sinks exist.

if nargin < 3 || isempty(V)
    V = vehicle_params();
end

D = design_pitch_controller(V, 'plot', false, 'verbose', false);
fprintf(['Pitch cascade (playback, not in the flight loop): ' ...
    'Kq = %.4g, Kth = %.4g, KiTh = %.4g, stop %.0f deg, rate %.0f deg/s\n'], ...
    D.Kq, D.Kth, D.KiTh, D.deltaMaxDeg, D.gimbalRateDeg);

here = fileparts(mfilename('fullpath'));
previous = pwd;
cleanup = onCleanup(@() cd(previous)); %#ok<NASGU>
cd(here);

mdl = build_pitch_model();
quiet_scopes(mdl);

[ext, traj] = controls_extensions(mdl, V, D, traj);
t = traj.t_s(:);
thetaRef = traj.theta_ref_rad(:);
apply_pitch_condition(D, "liftoff", ...
    'thetaStepDeg', 0, 'gustSpeed', 0, 'gustTime', 1e9, ...
    'misalignDeg', 0, 'misalignTime', 1e9, 'tStop', t(end), 'shapeOn', 1);
push_baseline_schedule(traj, D);
publish_optional_tables(traj, V);
scheduledWind = model_has_block(mdl, 'lookup_wind');

assignin('base', 'playbackThetaCmd', timeseries(thetaRef, t));
cmdOk = retarget_step([mdl '/theta_cmd'], 'playbackThetaCmd');
if ~cmdOk
    error('run_open_loop_playback:Command', ...
        ['theta_cmd is not a Step or From Workspace block, so the sim pitch ' ...
         'profile cannot drive boosterPitchTVC.']);
end

if scheduledWind
    assignin('base', 'gustSpeed', 0);
    pb.plantWind = 'schedWind lookup (m/s)';
else
    acc = wind_acceleration(traj);
    assignin('base', 'playbackWindAcc', timeseries(acc, t));
    assignin('base', 'gustAccPerWind', 1);
    windOk = retarget_step([mdl '/Plant/wind'], 'playbackWindAcc');
    if ~windOk
        error('run_open_loop_playback:Wind', ...
            ['Plant/wind is not a Step, and the model has no schedWind lookup. ' ...
             'The controls-repo gust cannot be injected.']);
    end
    pb.plantWind = 'equivalent gust acceleration -(lambda/V)*w, gain = 1';
end

quiet_scopes(mdl);
save_system(mdl);
unload_quietly(mdl);
load_system(mdl);

fprintf(['Open-loop playback: sim() of %s to t = %.1f s along the ascent. ' ...
    'The controller does not fly the vehicle.\n'], mdl, t(end));
out = sim(mdl, 'ReturnWorkspaceOutputs', 'on');
unload_quietly(mdl);

[tLog, theta] = must_log(out, 'theta');
[~, pitchRate] = must_log(out, 'q');
[~, delta] = must_log(out, 'delta');
[~, rate] = must_log(out, 'gimbalRateMeas');
[tCmd, thetaCmd] = must_log(out, 'thetaCmd');
if numel(tCmd) ~= numel(tLog) || max(abs(tCmd - tLog)) > 1e-6
    thetaCmd = interp1(tCmd, thetaCmd, tLog, 'linear', 'extrap');
end

[alphaLog, hasAlpha] = optional_vector(out, 'alpha', tLog);
[qAlphaLog, hasQAlpha] = optional_vector(out, 'qAlpha', tLog);
[finT, finDeg, finSource] = optional_fin(out, ext);

qPa = interp1(t, traj.q_Pa(:), tLog, 'linear', 'extrap');
speed = interp1(t, traj.speed_mps(:), tLog, 'linear', 'extrap');
wind = interp1(t, traj.wind_mps(:), tLog, 'linear', 'extrap');
if hasAlpha
    alpha = alphaLog;
else
    % Main plant: wind moment is zero at or below 1 m/s (vehicle_params).
    % The step-3 plant uses lrVfloor inside alpha = theta - wind/speed.
    vFloor = 1;
    if scheduledWind && isfield(V, 'lrVfloor') && ~isempty(V.lrVfloor)
        vFloor = V.lrVfloor;
    end
    alpha = theta - wind ./ max(speed, vFloor);
    alpha(speed <= vFloor) = theta(speed <= vFloor);
end
if hasQAlpha
    qAlpha = qAlphaLog;
else
    qAlpha = qPa .* alpha;
end

err = thetaCmd - theta;
deltaDeg = rad2deg(delta);
rateDeg = rad2deg(rate);
alphaDeg = rad2deg(alpha);
qAlphaKpaDeg = rad2deg(qAlpha) / 1000;

pb.mode = 'playback';
pb.openLoop = true;
pb.t = tLog;
pb.thetaCmdDeg = rad2deg(thetaCmd);
pb.thetaDeg = rad2deg(theta);
pb.errDeg = rad2deg(err);
pb.pitchRateDeg = rad2deg(pitchRate);
pb.deltaDeg = deltaDeg;
pb.deltaCmdDeg = rad2deg(must_second(out, 'deltaCmd', tLog));
pb.rateDeg = rateDeg;
pb.alphaDeg = alphaDeg;
pb.qAlpha_kPa_deg = qAlphaKpaDeg;
pb.deltaMaxDeg = D.deltaMaxDeg;
pb.rateMaxDeg = D.gimbalRateDeg;
pb.windLabel = info.windLabel;
pb.reference = info.reference;
pb.peakThetaRefDeg = info.peakThetaRefDeg;
pb.scheduledWind = scheduledWind;
pb.features = ext;
pb.finT = finT;
pb.finDeg = finDeg;
pb.finSource = finSource;
pb.hasFinCommand = ~isempty(finDeg);
pb.metrics = pack_metrics(tLog, err, deltaDeg, rateDeg, alphaDeg, qAlphaKpaDeg, D);
end


function push_baseline_schedule(traj, D)
target = which('apply_flight_schedule');
if isempty(target)
    error('run_open_loop_playback:Schedule', ...
        'apply_flight_schedule is not on the path.');
end
src = fileread(target);
if ~isempty(strfind(src, 'schedWind')) %#ok<STREMP>
    % Step 3 reads the shear and gust off D. Without those fields the
    % call stays on the default (zero) wind table.
    if has_wind_fields(D)
        apply_flight_schedule(traj, D, 'useWind', true);
    else
        apply_flight_schedule(traj, D);
    end
else
    apply_flight_schedule(traj, D.deltaMax);
end
end


function tf = has_wind_fields(D)
names = {'windShear', 'windShearTime', 'windGust', 'windGustStart', 'windGustDur'};
tf = isstruct(D);
if ~tf
    return
end
for k = 1:numel(names)
    if ~isfield(D, names{k}) || isempty(D.(names{k}))
        tf = false;
        return
    end
end
end


function publish_optional_tables(traj, V)
try
    tSched = evalin('base', 'schedTime');
catch
    return
end
tSrc = traj.t_s(:);
CNa = 2.0;
area = pi * (4.5 ^ 2);
if isstruct(V) && isfield(V, 'CNa'), CNa = V.CNa; end
if isstruct(V) && isfield(V, 'area'), area = V.area; end
mass = traj.mass_kg(:);
q = traj.q_Pa(:);
assign_match('schedSpeed', tSched, tSrc, traj.speed_mps(:));
assign_match('schedQdyn', tSched, tSrc, q);
assign_match('schedWind', tSched, tSrc, traj.wind_mps(:));
assign_match('schedAccThrust', tSched, tSrc, traj.thrust_N(:) ./ mass);
assign_match('schedAccAero', tSched, tSrc, q .* CNa .* area ./ mass);
end


function assign_match(name, tSched, tSrc, values)
tSched = tSched(:);
if numel(tSrc) == numel(tSched) && max(abs(tSrc - tSched)) < 1e-6
    y = values(:);
else
    y = interp1(tSrc, values(:), tSched, 'linear', 'extrap');
end
assignin('base', name, y(:).');
end


function acc = wind_acceleration(traj)
speed = traj.speed_mps(:);
lambda = traj.lambda_rps2(:);
wind = traj.wind_mps(:);
acc = zeros(size(wind));
use = speed > 1;
acc(use) = -lambda(use) ./ speed(use) .* wind(use);
end


function tf = model_has_block(mdl, name)
found = find_system(mdl, 'LookUnderMasks', 'on', 'FollowLinks', 'on', ...
    'Name', name);
tf = ~isempty(found);
end


function quiet_scopes(mdl)
scopes = find_system(mdl, 'LookUnderMasks', 'on', 'BlockType', 'Scope');
for i = 1:numel(scopes)
    try_param(scopes{i}, 'OpenAtSimulationStart', 'off');
end
end


function ok = retarget_step(block, varName)
% Point a Step source at a base-workspace timeseries. A From Workspace that
% is already there is only renamed. Any other block type is left alone.
ok = false;
try
    kind = get_param(block, 'BlockType');
catch
    return
end
if strcmp(kind, 'FromWorkspace')
    set_param(block, 'VariableName', varName);
    tune_from_workspace(block);
    ok = true;
    return
end
if ~strcmp(kind, 'Step')
    return
end
parent = get_param(block, 'Parent');
name = get_param(block, 'Name');
pos = get_param(block, 'Position');
ports = get_param(block, 'PortHandles');
line = get_param(ports.Outport(1), 'Line');
dst = destination_ports(line);
if line ~= -1
    delete_line(line);
end
delete_block(block);
newBlock = [parent '/' name];
add_block('simulink/Sources/From Workspace', newBlock, 'VariableName', varName);
try_param(newBlock, 'Position', pos);
tune_from_workspace(newBlock);
out = get_param(newBlock, 'PortHandles');
for k = 1:numel(dst)
    add_line(parent, out.Outport(1), dst(k), 'autorouting', 'on');
end
ok = true;
end


function dst = destination_ports(line)
dst = [];
if isempty(line) || line == -1
    return
end
direct = get_param(line, 'DstPortHandle');
direct = direct(direct > 0);
dst = direct(:);
try
    children = get_param(line, 'LineChildren');
catch
    children = [];
end
children = children(:);
for k = 1:numel(children)
    if children(k) > 0
        dst = [dst; destination_ports(children(k))]; %#ok<AGROW>
    end
end
if ~isempty(dst)
    dst = unique(dst, 'stable');
end
end


function tune_from_workspace(block)
try_param(block, 'SampleTime', '0');
try_param(block, 'Interpolate', 'on');
try_param(block, 'OutputAfterFinalValue', 'Holding final value');
end


function unload_quietly(mdl)
try
    close_system(mdl, 0);
catch
    try
        close_system(mdl, 1);
    catch
    end
end
end


function ok = try_param(block, name, value)
try
    set_param(block, name, value);
    ok = true;
catch
    ok = false;
end
end


function [t, y] = must_log(out, name)
ts = fetch_log(out, name);
[t, y] = unpack_log(ts);
end


function y = must_second(out, name, tWant)
[t, raw] = must_log(out, name);
if numel(t) == numel(tWant) && max(abs(t(:) - tWant(:))) <= 1e-6
    y = raw(:);
else
    y = interp1(t(:), raw(:), tWant(:), 'linear', 'extrap');
end
end


function [y, ok] = optional_vector(out, name, tWant)
ok = false;
y = [];
try
    ts = fetch_log(out, name);
catch
    return
end
[t, raw] = unpack_log(ts);
if numel(t) == numel(tWant) && max(abs(t(:) - tWant(:))) <= 1e-6
    y = raw(:);
else
    y = interp1(t(:), raw(:), tWant(:), 'linear', 'extrap');
end
ok = true;
end


function [finT, finDeg, source] = optional_fin(out, ext)
finT = ext.gridFinT;
finDeg = ext.gridFinDeg;
source = '';
if ~isempty(finDeg)
    source = 'grid_fin_command';
end
candidates = {'finDefl', 'gridFin', 'deltaFin', 'fin'};
for k = 1:numel(candidates)
    try
        ts = fetch_log(out, candidates{k});
    catch
        continue
    end
    [t, y] = unpack_log(ts);
    finT = t(:);
    finDeg = rad2deg(y(:));
    source = ['log:' candidates{k}];
    return
end
end


function ts = fetch_log(out, name)
try
    ts = out.(name);
    return
catch
end
try
    ts = out.get(name);
    return
catch ME
    error('run_open_loop_playback:MissingLog', ...
        'No logged signal "%s" (%s).', name, ME.message);
end
end


function [t, y] = unpack_log(ts)
if isa(ts, 'timeseries')
    t = ts.Time(:);
    y = ts.Data(:);
elseif isstruct(ts) && isfield(ts, 'time')
    t = ts.time(:);
    y = ts.signals.values(:);
else
    error('run_open_loop_playback:LogFormat', ...
        'Expected a timeseries log, got %s.', class(ts));
end
y = y(:);
end


function M = pack_metrics(t, err, deltaDeg, rateDeg, alphaDeg, qAlphaKpaDeg, D)
M.peakAttErr_deg = max(abs(rad2deg(err)));
M.peakGimbal_deg = max(abs(deltaDeg));
M.peakRate_deg = max(abs(rateDeg));
M.tOnAngle_s = dwell_time(t, abs(deltaDeg) >= D.deltaMaxDeg - 0.05);
M.tOnRate_s = dwell_time(t, abs(rateDeg) >= D.gimbalRateDeg - 0.05);
M.peakAlpha_deg = max(abs(alphaDeg));
M.peakQAlpha_kPa_deg = max(abs(qAlphaKpaDeg));
end


function tout = dwell_time(t, on)
% Same definition as run_pitch_tvc: each solver interval uses its start sample.
if numel(t) < 2
    tout = 0;
    return
end
tout = sum(diff(t(:)) .* double(on(1:end-1)));
end
