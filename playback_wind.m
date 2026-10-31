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
if exist('load_relief_wind', 'file') == 2
    w = load_relief_wind(V, t);
    w = w(:);
    label = 'load_relief_wind (shear + 1-cosine gust)';
    return
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
