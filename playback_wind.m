function [w, label] = playback_wind(V, t)
%PLAYBACK_WIND  Crosswind fed to the pitch plant during open-loop playback.
%
%   [w, label] = playback_wind(V, t)
%
%   When rocket-controls-simulink provides load_relief_wind (max-q load
%   relief, step 3), that shear-plus-gust profile is used. Until then the
%   wind is the design gust already in vehicle_params: 0 until gustTime,
%   then a constant gustSpeed (15 m/s at t = 14 s on main).
%
%   This is the controls-repo wind, not matlab-rocket-sim's P.wind. The
%   Starship flight itself stays in the sim's still air. The gust is applied
%   only inside the pitch playback, so it cannot move the trajectory.

t = t(:);
windFields = {'windShear', 'windShearTime', 'windGust', 'windGustStart', 'windGustDur'};
if exist('load_relief_wind', 'file') == 2 && has_wind_fields(V, windFields)
    try
        w = load_relief_wind(V, t);
        w = w(:);
        if numel(w) == numel(t) && isnumeric(w)
            label = 'load_relief_wind (shear + 1-cosine gust)';
            return
        end
        warning('playback_wind:Shape', ...
            'load_relief_wind did not return one sample per time.');
    catch ME
        warning('playback_wind:LoadRelief', ...
            'load_relief_wind is present but was not used (%s).', ME.message);
    end
elseif exist('load_relief_wind', 'file') == 2
    warning('playback_wind:Fields', ...
        ['load_relief_wind is on the path; skipped because windShear, ' ...
         'windShearTime, windGust, windGustStart, or windGustDur is missing.']);
end

w = zeros(size(t));
if isfield(V, 'gustTime') && isfield(V, 'gustSpeed')
    w(t >= V.gustTime) = V.gustSpeed;
    label = sprintf('design gust step: %.4g m/s at t = %.4g s (vehicle_params)', ...
        V.gustSpeed, V.gustTime);
else
    label = 'no controls-repo wind model found; wind left at 0';
end
end


function tf = has_wind_fields(V, names)
tf = isstruct(V);
if ~tf
    return
end
for k = 1:numel(names)
    if ~isfield(V, names{k}) || isempty(V.(names{k}))
        tf = false;
        return
    end
end
end
