function [traj, info] = trajectory_from_sim(flight, V)
%TRAJECTORY_FROM_SIM  Controller schedule taken from this Starship run.
%
%   [traj, info] = trajectory_from_sim(flight, V)
%
%   Builds the same columns as data/superheavy_booster_trajectory.csv
%   (see make_booster_trajectory) from flight.fullB, for the stack ascent
%   only. The CSV in the controls repo is not read. mu and lambda use the
%   controls-repo assumptions (uniform rod, CG at mid-length, static margin
%   and CNa from vehicle_params) so a later change there flows through.
%
%   The attitude reference is the sim's pitch minus the flight-path angle.
%   The TVC plant measures pitch from trim (the velocity vector). Ideal
%   steering holds that error near zero after the kick, and at the kick
%   angle while the nose is held off the velocity vector. Commanding the
%   absolute pitch (tens of degrees of gravity turn) would be a different
%   plant than boosterPitchTVC.
%
%   Breakpoints are the ascent's own ode45 samples (duplicate times
%   removed), not the 1 Hz CSV. The 5 s pitch kick stays at the samples
%   the sim actually wrote.

if nargin < 2 || isempty(V)
    V = vehicle_params();
end

Pb = flight.Pb;
fullB = flight.fullB;
ascent = fullB.phase == 1;
if ~any(ascent)
    error('trajectory_from_sim:NoAscent', ...
        'fullB has no stack-ascent samples (phase == 1).');
end

tN = fullB.t(ascent);
tN = tN(:);
X = fullB.X(ascent, :);
qN = fullB.aux.q(ascent);
qN = qN(:);
thrustN = fullB.aux.thrust(ascent);
thrustN = thrustN(:);
throttleN = fullB.aux.throttle(ascent);
throttleN = throttleN(:);
pitchN = X(:, 6);

[tN, ia] = unique(tN, 'stable');
X = X(ia, :);
qN = qN(ia);
thrustN = thrustN(ia);
throttleN = throttleN(ia);
pitchN = pitchN(ia);

vx = X(:, 3);
vh = X(:, 4);
speed = hypot(vx, vh);
gamma = zeros(size(speed));
moving = speed > 1;
gamma(moving) = atan2(vx(moving), vh(moving));
thetaRef = atan2(sin(pitchN - gamma), cos(pitchN - gamma));
t = tN;
h = X(:, 2);
mass = X(:, 5);
q = qN;
thrust = thrustN;
throttle = throttleN;
pitch = pitchN;

Lstack = field_or(V, 'stackLength', 121);
sm = field_or(V, 'staticMarginAscent', -0.5);
CNa = field_or(V, 'CNa', 2.0);
area = field_or(V, 'area', Pb.A);
diam = field_or(V, 'diam', Pb.diam);
nEng = Pb.engAscent;

n = numel(t);
len = Lstack * ones(n, 1);
arm = len / 2;
cg = arm;
lcp = -sm * diam * ones(n, 1);
cp = cg - lcp;
inertia = mass .* (len .^ 2) / 12;
mu = thrust .* arm ./ inertia;
lambda = q .* CNa .* area .* lcp ./ inertia;
tvc = double(thrust > 1);

mach = zeros(n, 1);
for i = 1:n
    [~, ~, aSound] = earthModel(h(i), Pb);
    mach(i) = speed(i) / max(aSound, 1);
end

[wind, windLabel] = playback_wind(V, t);

phase = repmat("ascent", n, 1);
config = repmat("stack", n, 1);
smCol = sm * ones(n, 1);

traj = table(t, phase, config, h, speed, mach, q, mass, throttle, ...
    nEng * ones(n, 1), thrust, len, cg, arm, cp, lcp, inertia, smCol, ...
    mu, lambda, tvc, pitch, gamma, thetaRef, wind, ...
    'VariableNames', {'t_s', 'phase', 'config', 'altitude_m', 'speed_mps', ...
    'mach', 'q_Pa', 'mass_kg', 'throttle', 'n_eng', 'thrust_N', 'length_m', ...
    'cg_from_nose_m', 'arm_m', 'cp_from_nose_m', 'lcp_m', 'inertia_kgm2', ...
    'static_margin_cal', 'mu_rps2', 'lambda_rps2', 'tvc_active', ...
    'pitch_rad', 'flight_path_rad', 'theta_ref_rad', 'wind_mps'});

info.windLabel = windLabel;
info.tStop = t(end);
info.dt = median(diff(t));
info.peakThetaRefDeg = rad2deg(max(abs(thetaRef)));
info.reference = ['sim body pitch minus flight-path angle ' ...
    '(TVC trim). Zero along the gravity turn; the pitch kick while the ' ...
    'nose is held off the velocity vector.'];
info.CNa = CNa;
info.area = area;
end


function value = field_or(S, name, fallback)
if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
    value = S.(name);
else
    value = fallback;
end
end
