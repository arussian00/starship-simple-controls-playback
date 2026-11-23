function flight = run_starship_flight()
%RUN_STARSHIP_FLIGHT  Starship mission from matlab-rocket-sim, with no figures.
%
%   flight = run_starship_flight()
%
%   Same calls and the same numbers as rocket_starship_sim.m steps 1-8:
%   ideal steering on the ascent (starshipStack), then simulateBooster for
%   the booster's flip / boostback / tower catch and for the ship's
%   belly-flop and splashdown. Histories come back as fullB and fullS,
%   including pitch, gimbal and the aux channels.
%
%   Does not call animateStarship, plotFlight or figure, and does not edit
%   the source repo. Call setup_paths first so the sim is on the path.

Pb = rocket_params('superheavy');
Ps = rocket_params('starship');
mu = Pb.g0 * Pb.Re^2;

% Numbers below are the ones in rocket_starship_sim.m. Keep them in step
% with that script so this flight stays the one Andy already runs.
S.m1dry    = Pb.m_dry;
S.m1prop   = Pb.m_prop;
S.T1       = Pb.engAscent * Pb.T_eng;
S.Isp1sl   = Pb.Isp_sl;
S.Isp1vac  = Pb.Isp_vac;
S.reserve1 = 400e3;

S.m2dry    = Ps.m_dry;
S.m2prop   = Ps.m_prop;
S.T2       = 3*2.3e6 + 3*2.5e6;
S.Isp2     = 365;
S.reserve2 = 30e3;
S.mPay     = 10e3;
S.gLimit   = 4;

S.Cd         = 0.4;
S.thrBucket  = 0.75;
S.bucketMach = [0.6 0.8 1.5 1.8];
S.A          = Pb.A;

S.tKick   = 8;
S.kickDur = 5;
S.kickDeg = 0.8;

S.hCoast  = 190e3;
S.perigee = -50e3;
S.wnG     = 0.01;
S.zG      = 0.8;

m0 = S.m1dry + S.m1prop + S.m2dry + S.m2prop + S.mPay;
fprintf('Liftoff mass %.0f t, thrust %.1f MN, thrust-to-weight %.2f\n', ...
    m0/1e3, S.T1/1e6, S.T1/(m0*Pb.g0));

Y0 = [0; 0; 0; 0; m0];
mMECO = m0 - (S.m1prop - S.reserve1);
opts = odeset('Events', @(t, Y) evMECO(t, Y, mMECO), ...
    'RelTol', 1e-8, 'AbsTol', 1e-6, 'MaxStep', 0.5);
[tA, YA] = ode45(@(t, Y) starshipStack(t, Y, S, Pb, mu, 'stack'), [0 400], Y0, opts);
tSep = tA(end);
Ysep = YA(end, :).';
fprintf(['Hot staging at t = %.1f s, h = %.1f km, speed = %.0f m/s, ' ...
    'flight-path angle = %.1f deg\n'], ...
    tSep, Ysep(2)/1e3, hypot(Ysep(3), Ysep(4)), atan2d(Ysep(4), Ysep(3)));

mShip = S.m2dry + S.m2prop + S.mPay;
mBoost = Ysep(5) - mShip;

opts = odeset('Events', @(t, Y) perigeeSECO(t, Y, S, Pb, mu), ...
    'RelTol', 1e-8, 'AbsTol', 1e-6, 'MaxStep', 0.5);
[tC, YC] = ode45(@(t, Y) starshipStack(t, Y, S, Pb, mu, 'ship'), ...
    [tSep, tSep + 1500], [Ysep(1:4); mShip], opts);
tSECO = tC(end);
Yseco = YC(end, :).';
[perigee, apogee] = orbitOf(Yseco, Pb.Re, mu);

Xb0 = [Ysep(1:4); mBoost; atan2(Ysep(3), Ysep(4)); Ysep(3)/(Pb.Re + Ysep(2))];
outB = simulateBooster(Pb, Xb0, tSep, Pb.phaseList);

Ps.m_dry = S.m2dry + S.mPay;
Xs0 = [Yseco(1:4); Yseco(5); atan2(Yseco(3), Yseco(4)); Yseco(3)/(Pb.Re + Yseco(2))];
outS = simulateBooster(Ps, Xs0, tSECO, Ps.phaseList);

segA = pointMassSegment(tA, YA, Pb, @(t, Y) starshipStack(t, Y, S, Pb, mu, 'stack'), S.T1);
segC = pointMassSegment(tC, YC, Pb, @(t, Y) starshipStack(t, Y, S, Pb, mu, 'ship'), S.T2);
fullB = fullFlight({segA}, {'stack ascent'}, outB);
fullS = fullFlight({segA, segC}, {'stack ascent', 'ship burn'}, outS);

fprintf('\n================ STARSHIP ASCENT ================\n');
fprintf('Engine cut-off (SECO) : t = %.1f s, h = %.1f km, speed = %.0f m/s\n', ...
    tSECO, Yseco(2)/1e3, hypot(Yseco(3), Yseco(4)));
fprintf('Trajectory            : %.0f x %.0f km (perigee below ground = re-enters)\n', ...
    perigee/1e3, apogee/1e3);
fprintf('Ship propellant left  : %.1f t (landing reserve %.0f t)\n', ...
    (Yseco(5) - S.m2dry - S.mPay)/1e3, S.reserve2/1e3);

metricsB = flightMetrics(fullB);
metricsS = flightMetrics(fullS);
metricsReentry = flightMetrics(outS, false);
qS = heatFlux(outS.X(:, 2), hypot(outS.X(:, 3), outS.X(:, 4)), outS.P.noseRadius, outS.P);
qB = heatFlux(outB.X(:, 2), hypot(outB.X(:, 3), outB.X(:, 4)), Pb.noseRadius, Pb);
[qSmax, iq] = max(qS);
fprintf(['Ship re-entry: max %.1f g, max q %.1f kPa, %.0f m/s at the flip, ' ...
    'splashdown %.0f km downrange\n'], ...
    metricsReentry.maxG, metricsReentry.maxQ/1e3, metricsReentry.landIgnSpeed, ...
    outS.X(end, 1)/1e3);
fprintf('Peak heating (estimate): ship %.0f kW/m^2 at %.0f km, booster %.0f kW/m^2\n', ...
    qSmax/1e3, outS.X(iq, 2)/1e3, max(qB)/1e3);
fprintf('Flight time to splashdown: %.1f min\n\n', outS.t(end)/60);

flight.fullB = fullB;
flight.fullS = fullS;
flight.tSep = tSep;
flight.tSECO = tSECO;
flight.perigee = perigee;
flight.apogee = apogee;
flight.Pb = Pb;
flight.Ps = fullS.P;
flight.S = S;
flight.outB = outB;
flight.outS = outS;
flight.metricsB = metricsB;
flight.metricsS = metricsS;
flight.metricsReentry = metricsReentry;
flight.qShipMax = qSmax;
flight.qBoostMax = max(qB);
end
