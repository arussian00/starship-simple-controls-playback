function ext = controls_extensions(mdl, V, D, traj)
%CONTROLS_EXTENSIONS  Turn on later rocket-controls-simulink features if present.
%
%   ext = controls_extensions(mdl, V, D, traj)
%
%   Playback is built against main. Steps 3-6 are separate branches and are
%   skipped when their functions or block parameters are absent. When a
%   branch is merged (or checked out via playback_config), the matching
%   hook runs and the new signals show up in the same mission-control panels.
%
%   Step 3  max-q load relief. load_relief_wind, lrBlend, schedWind,
%           schedSpeed, schedQdyn. The plant then logs alpha and qAlpha.
%   Step 4  moving CG, slosh, bending. Optional calls, in order:
%           apply_cg_schedule, cg_schedule, apply_slosh, slosh_schedule,
%           apply_bending, bending_schedule. Each is called as
%           f(traj, V, D), f(traj, V), f(traj) or f(), whichever nargin fits.
%   Step 5  grid fins. grid_fin_command(traj, V) may return a struct with
%           t and deg (or deflection_deg). A logged fin / gridFin / deltaFin
%           signal is picked up later from the simulation output.
%   Step 6  Monte Carlo / tuner. run_pitch_monte_carlo or pitch_monte_carlo
%           is reported and not launched. Playback stays one deterministic
%           ascent. open_pitch_tuner already exists on main and is not run.
%
%   Scalar workspace names the loaded model actually references (lrBlend,
%   qEngage, ...) are copied from V or D when those fields exist and the
%   base workspace does not already hold them.

ext.loadRelief = false;
ext.movingCg = false;
ext.slosh = false;
ext.bending = false;
ext.gridFins = false;
ext.monteCarlo = false;
ext.notes = {};
ext.gridFinT = [];
ext.gridFinDeg = [];

ext.loadRelief = exist('load_relief_wind', 'file') == 2 ...
    && model_uses(mdl, 'lrBlend');
if exist('load_relief_wind', 'file') == 2 && ~ext.loadRelief
    ext.notes{end + 1} = ['load_relief_wind is on the path; the loaded model ' ...
        'has no lrBlend gain, so the blend stays off.']; %#ok<AGROW>
end

ext.movingCg = call_first(mdl, traj, V, D, ["apply_cg_schedule", "cg_schedule"]);
ext.slosh = call_first(mdl, traj, V, D, ["apply_slosh", "slosh_schedule"]);
ext.bending = call_first(mdl, traj, V, D, ["apply_bending", "bending_schedule"]);
ext.gridFins = exist('grid_fin_command', 'file') == 2 || model_uses(mdl, 'schedFin');
ext.monteCarlo = exist('run_pitch_monte_carlo', 'file') == 2 ...
    || exist('pitch_monte_carlo', 'file') == 2;

if ext.gridFins && exist('grid_fin_command', 'file') == 2
    try
        fin = grid_fin_command(traj, V);
        [ext.gridFinT, ext.gridFinDeg] = normalize_fin(fin);
    catch ME
        warning('controls_extensions:GridFin', ...
            'grid_fin_command is present but was not used (%s).', ME.message);
        ext.notes{end + 1} = ['grid_fin_command failed: ' ME.message]; %#ok<AGROW>
    end
end

if ext.monteCarlo
    ext.notes{end + 1} = ['Monte Carlo function is on the path. Playback does ' ...
        'not launch it; run that entry point on its own.']; %#ok<AGROW>
end

push_referenced_scalars(mdl, V, D);
end


function ran = call_first(~, traj, V, D, names)
ran = false;
for k = 1:numel(names)
    name = char(names(k));
    if exist(name, 'file') ~= 2
        continue
    end
    call_hook(name, traj, V, D);
    fprintf('controls extension: called %s\n', name);
    ran = true;
    return
end
end


function call_hook(name, traj, V, D)
n = nargin(name);
if n < 0
    n = 3;
end
if n >= 3
    feval(name, traj, V, D);
elseif n == 2
    feval(name, traj, V);
elseif n == 1
    feval(name, traj);
else
    feval(name);
end
end


function push_referenced_scalars(mdl, V, D)
names = model_identifiers(mdl);
for k = 1:numel(names)
    name = names{k};
    if base_has(name)
        continue
    end
    value = [];
    if isstruct(V) && isfield(V, name)
        value = V.(name);
    elseif isstruct(D) && isfield(D, name)
        value = D.(name);
    else
        continue
    end
    if isnumeric(value) && isscalar(value) && isreal(value)
        assignin('base', name, value);
    elseif islogical(value) && isscalar(value)
        assignin('base', name, value);
    end
end
end


function tf = model_uses(mdl, name)
ids = model_identifiers(mdl);
tf = any(strcmp(ids, name));
end


function ids = model_identifiers(mdl)
ids = {};
try
    blocks = find_system(mdl, 'LookUnderMasks', 'on', 'FollowLinks', 'on', ...
        'Type', 'block');
catch
    return
end
for i = 1:numel(blocks)
    try
        dialog = get_param(blocks{i}, 'DialogParameters');
    catch
        dialog = [];
    end
    if isempty(dialog)
        continue
    end
    fields = fieldnames(dialog);
    for k = 1:numel(fields)
        try
            value = get_param(blocks{i}, fields{k});
        catch
            continue
        end
        if ischar(value) && isvarname(strtrim(value))
            ids{end + 1} = strtrim(value); %#ok<AGROW>
        end
    end
end
ids = unique(ids, 'stable');
end


function tf = base_has(name)
tf = evalin('base', sprintf('exist(''%s'', ''var'')', name)) == 1;
end


function [t, deg] = normalize_fin(fin)
t = [];
deg = [];
if ~isstruct(fin)
    return
end
if isfield(fin, 't')
    t = fin.t(:);
end
if isfield(fin, 'deg')
    deg = fin.deg(:);
elseif isfield(fin, 'deflection_deg')
    deg = fin.deflection_deg(:);
elseif isfield(fin, 'deflection')
    deg = rad2deg(fin.deflection(:));
end
if numel(t) ~= numel(deg)
    t = [];
    deg = [];
end
end
