function [ext, traj] = controls_extensions(mdl, V, D, traj)
%CONTROLS_EXTENSIONS  Turn on later rocket-controls-simulink features if present.
%
%   [ext, traj] = controls_extensions(mdl, V, D, traj)
%
%   Playback is built against main. Steps 3-6 are separate branches. Each
%   hook runs only when its function is on the path and the field it reads
%   exists. A missing piece is skipped. traj comes back unchanged unless
%   apply_mass_properties (or a CG hook) replaced it.
%
%   Step 3  max-q load relief. load_relief_wind runs only with the wind
%           fields. lrBlend is on only when that field and the model gain
%           both exist. The plant then logs alpha and qAlpha.
%   Step 4  moving CG: apply_mass_properties(traj, V) when staticMarginAscent
%           and staticMarginLanding exist, otherwise apply_cg_schedule or
%           cg_schedule. Slosh: apply_slosh or slosh_schedule. Bending:
%           apply_bending or bending_schedule. notch_for_flight only when
%           the model references notchNum. slosh_model and bending_model
%           alone are not called.
%   Step 5  grid fins. grid_fin_command(traj, V) may return a struct with
%           t and deg (or deflection_deg). grid_fin_model is not run.
%           A logged fin / gridFin / deltaFin / fin signal is picked up
%           later from the simulation output.
%   Step 6  Monte Carlo / tuner. run_pitch_monte_carlo, pitch_monte_carlo,
%           or run_monte_carlo is reported and not launched. Playback stays
%           one deterministic ascent. open_pitch_tuner is not run.
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

% Step 3. The blend is on only when the wind function, the lrBlend field,
% and the model gain are all present. A missing piece is a note, not a call.
hasWindFn = exist('load_relief_wind', 'file') == 2;
hasBlendField = has_fields(V, {'lrBlend'}) || has_fields(D, {'lrBlend'});
hasBlendGain = model_uses(mdl, 'lrBlend');
ext.loadRelief = hasWindFn && hasBlendField && hasBlendGain;
if hasWindFn && ~ext.loadRelief
    ext.notes{end + 1} = ['load_relief_wind is on the path; lrBlend is used ' ...
        'only when vehicle_params (or the design) has that field and the ' ...
        'loaded model has the gain. The blend stays off.']; %#ok<AGROW>
end

% Step 4. apply_mass_properties is the moving-CG hook on the structure
% branch. The older names are tried only when that function is absent.
% slosh_model and bending_model build plants; they are not called with the
% trajectory. notch_for_flight runs only if the model names notchNum.
ext.movingCg = false;
if exist('apply_mass_properties', 'file') == 2
    if has_fields(V, {'staticMarginAscent', 'staticMarginLanding'})
        [traj, applied, note] = try_mass_properties(traj, V);
        ext.movingCg = applied;
        if ~isempty(note)
            ext.notes{end + 1} = note; %#ok<AGROW>
        end
    else
        ext.notes{end + 1} = ['apply_mass_properties is on the path; skipped ' ...
            'because staticMarginAscent or staticMarginLanding is missing.']; %#ok<AGROW>
    end
else
    [ext.movingCg, traj] = call_first(traj, V, D, {'apply_cg_schedule', 'cg_schedule'});
end
[ext.slosh, traj] = call_first(traj, V, D, {'apply_slosh', 'slosh_schedule'});
[ext.bending, traj] = call_first(traj, V, D, {'apply_bending', 'bending_schedule'});
if ~ext.slosh && exist('slosh_model', 'file') == 2
    ext.notes{end + 1} = ['slosh_model is on the path; playback calls it only ' ...
        'through apply_slosh or slosh_schedule, and neither is on the path.']; %#ok<AGROW>
end
if ~ext.bending && exist('bending_model', 'file') == 2 && ~model_uses(mdl, 'notchNum')
    ext.notes{end + 1} = ['bending_model is on the path; playback calls it only ' ...
        'through apply_bending or bending_schedule, and neither is on the path.']; %#ok<AGROW>
end
if exist('notch_for_flight', 'file') == 2 && model_uses(mdl, 'notchNum')
    [ext, bent] = publish_notch(ext, D);
    ext.bending = ext.bending || bent;
end

% Step 5. grid_fin_command is the only descent hook playback calls.
% grid_fin_model is a parameter block for the separate descent sim.
ext.gridFins = false;
if exist('grid_fin_command', 'file') == 2
    try
        fin = grid_fin_command(traj, V);
        [ext.gridFinT, ext.gridFinDeg] = normalize_fin(fin);
        ext.gridFins = true;
        fprintf('controls extension: called grid_fin_command\n');
    catch ME
        warning('controls_extensions:GridFin', ...
            'grid_fin_command is present but was not used (%s).', ME.message);
        ext.notes{end + 1} = ['grid_fin_command failed: ' ME.message]; %#ok<AGROW>
    end
elseif model_uses(mdl, 'schedFin')
    ext.gridFins = true;
elseif exist('grid_fin_model', 'file') == 2
    ext.notes{end + 1} = ['grid_fin_model is on the path; playback does not ' ...
        'run the descent loop.']; %#ok<AGROW>
end

% Step 6. Report the Monte Carlo entry point. Do not launch it.
ext.monteCarlo = first_existing({'run_pitch_monte_carlo', 'pitch_monte_carlo', ...
    'run_monte_carlo'});
if ext.monteCarlo
    ext.notes{end + 1} = ['Monte Carlo function is on the path. Playback does ' ...
        'not launch it; run that entry point on its own.']; %#ok<AGROW>
end

push_referenced_scalars(mdl, V, D);
end


function [traj, applied, note] = try_mass_properties(traj, V)
applied = false;
note = '';
try
    updated = apply_mass_properties(traj, V);
catch ME
    note = ['apply_mass_properties failed: ' ME.message];
    warning('controls_extensions:Mass', '%s', note);
    return
end
if is_trajectory(updated)
    traj = updated;
    applied = true;
    fprintf('controls extension: called apply_mass_properties\n');
else
    note = 'apply_mass_properties returned no trajectory; the rod schedule stands.';
end
end


function [ext, bent] = publish_notch(ext, D)
bent = false;
if ~isstruct(D) || ~isfield(D, 'flight') || isempty(D.flight)
    ext.notes{end + 1} = ['notch_for_flight is on the path; skipped because ' ...
        'the design has no flight field.']; %#ok<AGROW>
    return
end
try
    [num, den] = notch_for_flight(D.flight(1));
catch ME
    ext.notes{end + 1} = ['notch_for_flight failed: ' ME.message]; %#ok<AGROW>
    warning('controls_extensions:Notch', ...
        'notch_for_flight is present but was not used (%s).', ME.message);
    return
end
if ~isnumeric(num) || ~isnumeric(den) || isempty(num) || isempty(den)
    ext.notes{end + 1} = 'notch_for_flight did not return numeric coefficients.'; %#ok<AGROW>
    return
end
assignin('base', 'notchNum', num(:).');
assignin('base', 'notchDen', den(:).');
bent = ~(isscalar(num) && isscalar(den) && num == 1 && den == 1);
if bent
    fprintf('controls extension: called notch_for_flight\n');
else
    ext.notes{end + 1} = ['notch_for_flight returned a unit gain (this flight ' ...
        'has no bendWn).']; %#ok<AGROW>
end
end


function [ran, traj] = call_first(traj, V, D, names)
ran = false;
for k = 1:numel(names)
    name = names{k};
    if exist(name, 'file') ~= 2
        continue
    end
    try
        traj = invoke_hook(name, traj, V, D);
    catch ME
        warning('controls_extensions:Hook', ...
            '%s is on the path but was not used (%s).', name, ME.message);
        continue
    end
    fprintf('controls extension: called %s\n', name);
    ran = true;
    return
end
end


function traj = invoke_hook(name, traj, V, D)
try
    nIn = nargin(name);
catch
    nIn = 3;
end
if nIn < 0
    nIn = 3;
end
try
    nOut = nargout(name);
catch
    nOut = 0;
end
updated = [];
if nOut == 0
    if nIn >= 3
        feval(name, traj, V, D);
    elseif nIn == 2
        feval(name, traj, V);
    elseif nIn == 1
        feval(name, traj);
    else
        feval(name);
    end
    return
end
if nIn >= 3
    updated = feval(name, traj, V, D);
elseif nIn == 2
    updated = feval(name, traj, V);
elseif nIn == 1
    updated = feval(name, traj);
else
    updated = feval(name);
end
if is_trajectory(updated)
    traj = updated;
end
end


function tf = first_existing(names)
tf = false;
for k = 1:numel(names)
    if exist(names{k}, 'file') == 2
        tf = true;
        return
    end
end
end


function tf = has_fields(S, names)
tf = isstruct(S);
if ~tf
    return
end
for k = 1:numel(names)
    if ~isfield(S, names{k}) || isempty(S.(names{k}))
        tf = false;
        return
    end
end
end


function tf = is_trajectory(traj)
tf = false;
if isstruct(traj) && isfield(traj, 't_s') && isfield(traj, 'mu_rps2')
    tf = true;
    return
end
try
    if istable(traj)
        names = cellstr(traj.Properties.VariableNames);
        tf = any(strcmp(names, 't_s')) && any(strcmp(names, 'mu_rps2'));
    end
catch
    tf = false;
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
