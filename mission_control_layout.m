function L = mission_control_layout()
%MISSION_CONTROL_LAYOUT  Panel positions shared with starship-closed-loop-sim.
%
%   Both mission-control windows use these normalized positions so the two
%   runs can sit side by side. Columns match animateStarship
%   (x = 0.035, 0.285, 0.535, 0.785, width 0.20). A fourth row is the
%   controls strip. The closed-loop window should use the same rectangles
%   and the same four controls panels, with its own on-screen label.
%
%   Row (bottom, height), all in figure-normalized units:
%     scene     y = 0.700  h = 0.230   overview, Earth, booster cam, ship cam
%     upper     y = 0.490  h = 0.175   altitude, speed, g-load, dynamic pressure
%     lower     y = 0.280  h = 0.175   throttle, AoA, mass, heating
%     controls  y = 0.040  h = 0.205   attitude, gimbal, AoA and q*alpha, grid fins
%
%   Controls panels, left to right:
%     1  attitude command vs response, and the error
%     2  gimbal angle and rate, with the stop lines
%     3  angle of attack and q*alpha
%     4  grid fins (sim return force; controller deflection when that
%        loop exists)

L.col = [0.035 0.285 0.535 0.785];
L.wid = 0.20;
L.rows.scene = [0.700 0.230];
L.rows.upper = [0.490 0.175];
L.rows.lower = [0.280 0.175];
L.rows.controls = [0.040 0.205];

L.telemNames = { ...
    'Altitude [km]', 'Speed [km/s]', 'g-load [g]', 'Dynamic pressure [kPa]', ...
    'Throttle [%]', 'Angle of attack [deg]', 'Mass [t] (log)', 'Heating [kW/m^2]'};
L.controlNames = { ...
    'Attitude cmd / response / error [deg]', ...
    'Gimbal angle [deg] and rate [deg/s]', ...
    'AoA [deg] and q*alpha [kPa deg]', ...
    'Grid fins'};

L.figureName = 'Starship mission control';
L.indicatorPlayback = 'PLAYBACK (open loop)';
L.indicatorClosedLoop = 'CLOSED LOOP';

L.color.booster = [0.85 0.25 0.15];
L.color.ship = [0.10 0.35 0.85];
L.color.command = [0.15 0.15 0.15];
L.color.response = [0.00 0.45 0.70];
L.color.error = [0.75 0.20 0.15];
L.color.limit = [0.55 0.12 0.12];
L.color.rate = [0.85 0.45 0.10];
L.color.banner = [0.65 0.10 0.05];
end
