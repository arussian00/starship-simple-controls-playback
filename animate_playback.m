function animate_playback(flight, pb, speed)
%ANIMATE_PLAYBACK  One mission-control window, flight plus open-loop controls.
%
%   animate_playback(flight, pb)
%   animate_playback(flight, pb, speed)
%
%   The scene row and the eight telemetry panels follow animateStarship
%   (same columns, both vehicles, both cameras, the same time warp). The
%   bottom row is the controls strip from mission_control_layout, drawn on
%   the same clock. Traces grow as the flight plays. The pitch-TVC traces
%   stop at the end of the ascent playback; grid-fin force from the sim's
%   own return continues through the catch.
%
%   speed multiplies the warp (2 plays twice as fast). Close the window to
%   stop. This is the only figure run_playback opens.

if nargin < 3 || isempty(speed)
    speed = 1;
end
L = mission_control_layout();
B = flight.fullB;
Sh = flight.fullS;
tSep = flight.tSep;
Pb = B.P;
Ps = Sh.P;
fps = 20;

%% Frame times. Same warp schedule as animateStarship.
tCatch = B.t(end);
tEnd = max(B.t(end), Sh.t(end));
[tuS, iuS] = unique(Sh.t, 'last');
hShip = @(t) interp1(tuS, Sh.X(iuS, 2), min(t, tuS(end)));
tf = zeros(1, 0);
warp = zeros(1, 0);
t = 0;
while t < tEnd
    w = 8;
    if t > tCatch + 8
        hs = hShip(t);
        if hs > 80e3
            w = 150;
        elseif hs > 5e3
            w = 30;
        else
            w = 5;
        end
    end
    tf(end + 1) = t; %#ok<AGROW>
    warp(end + 1) = w; %#ok<AGROW>
    t = t + speed * w / fps;
end
tf(end + 1) = tEnd;
warp(end + 1) = warp(end);

b = sample_flight(B, tf, Pb);
s = sample_flight(Sh, tf, Ps);
s.thr(tf <= tSep) = 0;
b.thr(tf > tCatch) = 0;
s.thr(tf >= Sh.t(end)) = 0;
for f = {'gL', 'q', 'thr', 'aoa', 'heat'}
    b.(f{1})(tf > tCatch + 1) = NaN;
    s.(f{1})(tf > Sh.t(end) + 1) = NaN;
end
xPad = Pb.xPad;

iSep = find(tf >= tSep, 1);
nSep = [sin(b.th(iSep)); cos(b.th(iSep))];
fade = max(0, 1 - (tf - tSep) / 40);
sx = s.x;
sh = s.h;
for k = 1:numel(tf)
    if tf(k) <= tSep
        n = [sin(b.th(k)); cos(b.th(k))];
        s.th(k) = b.th(k);
        s.aoa(k) = b.aoa(k);
    else
        n = nSep * fade(k);
    end
    sx(k) = s.x(k) + Pb.L * n(1);
    sh(k) = s.h(k) + Pb.L * n(2);
end

toX = @(x, h) (Pb.Re + h) .* sin(x / Pb.Re) / 1e3;
toY = @(x, h) (Pb.Re + h) .* cos(x / Pb.Re) / 1e3;
ev = mission_events(B, Sh, tSep);

cmd = sample_stop(pb.t, pb.thetaCmdDeg, tf);
resp = sample_stop(pb.t, pb.thetaDeg, tf);
err = sample_stop(pb.t, pb.errDeg, tf);
gim = sample_stop(pb.t, pb.deltaDeg, tf);
rate = sample_stop(pb.t, pb.rateDeg, tf);
aoaC = sample_stop(pb.t, pb.alphaDeg, tf);
qa = sample_stop(pb.t, pb.qAlpha_kPa_deg, tf);
finSim = sample_hold(B.t, B.aux.finForce(:) / 1e3, tf);
finSim(tf > tCatch + 1) = NaN;
if pb.hasFinCommand
    finCmd = sample_stop(pb.finT, pb.finDeg, tf);
else
    finCmd = [];
end

%% One window, normalized positions, so it fills the screen and resizes.
fig = figure('Name', [L.figureName ' - ' L.indicatorPlayback], ...
    'Color', 'w', 'NumberTitle', 'off', ...
    'Units', 'normalized', 'OuterPosition', [0 0 1 1]);
try
    set(fig, 'WindowState', 'maximized');
catch
end
try
    annotation(fig, 'textbox', [0.28 0.945 0.44 0.045], ...
        'String', L.indicatorPlayback, ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'FontWeight', 'bold', ...
        'FontSize', 13, 'Color', L.color.banner, ...
        'BackgroundColor', [1 0.95 0.90], 'FaceAlpha', 0.9);
catch
    annotation(fig, 'textbox', [0.28 0.945 0.44 0.045], ...
        'String', L.indicatorPlayback, ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'FontSize', 13, 'Color', L.color.banner);
end

axO = axes('Parent', fig, 'Position', panel_pos(L, 'scene', 1));
axE = axes('Parent', fig, 'Position', panel_pos(L, 'scene', 2));
axB = axes('Parent', fig, 'Position', panel_pos(L, 'scene', 3));
axS = axes('Parent', fig, 'Position', panel_pos(L, 'scene', 4));

hold(axO, 'on');
grid(axO, 'on');
hTrB = plot(axO, nan, nan, '-', 'Color', L.color.booster, 'LineWidth', 1.5);
hTrS = plot(axO, nan, nan, '-', 'Color', L.color.ship, 'LineWidth', 1.5);
hDtB = plot(axO, nan, nan, 'o', 'Color', L.color.booster, ...
    'MarkerFaceColor', L.color.booster, 'MarkerSize', 5);
hDtS = plot(axO, nan, nan, 'o', 'Color', L.color.ship, ...
    'MarkerFaceColor', L.color.ship, 'MarkerSize', 5);
plot(axO, xPad / 1e3, 0, 'k^', 'MarkerFaceColor', [1 0.8 0], 'MarkerSize', 7);
xlabel(axO, 'Downrange [km]');
ylabel(axO, 'Altitude [km]');
legend(axO, [hTrB hTrS], {'Super Heavy', 'Starship'}, 'Location', 'northwest', ...
    'AutoUpdate', 'off', 'FontSize', 7);
hClock = title(axO, '', 'FontName', 'Monospaced', 'FontSize', 9);
hLog = text(axO, 0.98, 0.97, '', 'Units', 'normalized', 'FontSize', 7, ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'FontName', 'Monospaced');

hold(axE, 'on');
axis(axE, 'equal');
th = linspace(0, 2 * pi, 360);
fill(axE, Pb.Re / 1e3 * cos(th), Pb.Re / 1e3 * sin(th), [0.75 0.85 1], ...
    'EdgeColor', [0.3 0.5 0.8]);
plot(axE, (Pb.Re + 100e3) / 1e3 * cos(th), (Pb.Re + 100e3) / 1e3 * sin(th), ...
    ':', 'Color', [0.5 0.5 0.5]);
hEB = plot(axE, nan, nan, '-', 'Color', L.color.booster, 'LineWidth', 1.5);
hES = plot(axE, nan, nan, '-', 'Color', L.color.ship, 'LineWidth', 1.5);
hEdB = plot(axE, nan, nan, 'o', 'Color', L.color.booster, ...
    'MarkerFaceColor', L.color.booster, 'MarkerSize', 4);
hEdS = plot(axE, nan, nan, 'o', 'Color', L.color.ship, ...
    'MarkerFaceColor', L.color.ship, 'MarkerSize', 4);
R = 1.1 * Pb.Re / 1e3;
axis(axE, [-R R -R R]);
title(axE, 'Earth view (dotted: 100 km)');
xlabel(axE, 'km');
ylabel(axE, 'km');

W = 100;
gB = build_camera(axB, Pb, Ps, xPad, 'Super Heavy camera');
gS = build_camera(axS, Pb, Ps, xPad, 'Starship camera');

yB = {b.h / 1e3, b.v / 1e3, b.gL, b.q / 1e3, 100 * b.thr, b.aoa, b.m / 1e3, b.heat / 1e3};
yS = {sh / 1e3, s.v / 1e3, s.gL, s.q / 1e3, 100 * s.thr, s.aoa, s.m / 1e3, s.heat / 1e3};
nT = numel(L.telemNames);
axT = cell(1, nT);
lB = cell(1, nT);
lS = cell(1, nT);
for j = 1:nT
    if j <= 4
        row = 'upper';
        col = j;
    else
        row = 'lower';
        col = j - 4;
    end
    axT{j} = axes('Parent', fig, 'Position', panel_pos(L, row, col));
    [axT{j}, lB{j}, lS{j}] = telemetry_axes(axT{j}, L.telemNames{j}, L);
end
set(axT{7}, 'YScale', 'log');
set(axT{6}, 'YLim', [0 180], 'YTick', 0:45:180);
set(axT{5}, 'YLim', [0 110]);

M = pb.metrics;
axC = cell(1, 4);
hC = struct();
axC{1} = axes('Parent', fig, 'Position', panel_pos(L, 'controls', 1));
hold(axC{1}, 'on');
grid(axC{1}, 'on');
hC.cmd = plot(axC{1}, nan, nan, '--', 'Color', L.color.command, 'LineWidth', 1.2);
hC.resp = plot(axC{1}, nan, nan, '-', 'Color', L.color.response, 'LineWidth', 1.5);
hC.err = plot(axC{1}, nan, nan, ':', 'Color', L.color.error, 'LineWidth', 1.3);
plain(axC{1});
title(axC{1}, sprintf('Attitude [deg]   peak |error| %.3f', M.peakAttErr_deg), ...
    'Interpreter', 'none');
xlabel(axC{1}, 'Time [min]');
legend(axC{1}, [hC.cmd hC.resp hC.err], {'command', 'response', 'error'}, ...
    'Location', 'best', 'FontSize', 7);

axC{2} = axes('Parent', fig, 'Position', panel_pos(L, 'controls', 2));
yyaxis(axC{2}, 'left');
hold(axC{2}, 'on');
hC.gim = plot(axC{2}, nan, nan, '-', 'Color', L.color.response, 'LineWidth', 1.4);
yline(axC{2}, pb.deltaMaxDeg, '--', 'Color', L.color.limit);
yline(axC{2}, -pb.deltaMaxDeg, '--', 'Color', L.color.limit);
ylabel(axC{2}, 'deg');
yyaxis(axC{2}, 'right');
hold(axC{2}, 'on');
hC.rate = plot(axC{2}, nan, nan, '-', 'Color', L.color.rate, 'LineWidth', 1.2);
yline(axC{2}, pb.rateMaxDeg, ':', 'Color', L.color.limit);
yline(axC{2}, -pb.rateMaxDeg, ':', 'Color', L.color.limit);
ylabel(axC{2}, 'deg/s');
plain(axC{2});
title(axC{2}, sprintf('Gimbal   stops %.2f s angle, %.2f s rate', ...
    M.tOnAngle_s, M.tOnRate_s), 'Interpreter', 'none');
xlabel(axC{2}, 'Time [min]');

axC{3} = axes('Parent', fig, 'Position', panel_pos(L, 'controls', 3));
yyaxis(axC{3}, 'left');
hold(axC{3}, 'on');
hC.aoa = plot(axC{3}, nan, nan, '-', 'Color', L.color.response, 'LineWidth', 1.4);
ylabel(axC{3}, 'deg');
yyaxis(axC{3}, 'right');
hold(axC{3}, 'on');
hC.qa = plot(axC{3}, nan, nan, '-', 'Color', L.color.rate, 'LineWidth', 1.2);
ylabel(axC{3}, 'kPa deg');
plain(axC{3});
title(axC{3}, sprintf('AoA and q*alpha   peak |q*alpha| %.3g kPa deg', ...
    M.peakQAlpha_kPa_deg), 'Interpreter', 'none');
xlabel(axC{3}, 'Time [min]');

axC{4} = axes('Parent', fig, 'Position', panel_pos(L, 'controls', 4));
yyaxis(axC{4}, 'left');
hold(axC{4}, 'on');
hC.fin = plot(axC{4}, nan, nan, '-', 'Color', L.color.booster, 'LineWidth', 1.4);
ylabel(axC{4}, 'kN');
if pb.hasFinCommand
    yyaxis(axC{4}, 'right');
    hold(axC{4}, 'on');
    hC.finCmd = plot(axC{4}, nan, nan, '--', 'Color', L.color.command, 'LineWidth', 1.2);
    ylabel(axC{4}, 'deg');
    finTitle = 'Grid fins: sim force and controller';
else
    hC.finCmd = [];
    finTitle = 'Grid fins (sim return; no controller yet)';
    text(axC{4}, 0.02, 0.95, 'controls model has no grid-fin loop', ...
        'Units', 'normalized', 'FontSize', 7, 'VerticalAlignment', 'top');
end
plain(axC{4});
title(axC{4}, finTitle, 'Interpreter', 'none');
xlabel(axC{4}, 'Time [min]');
grid(axC{4}, 'on');

for j = 1:4
    plain(axC{j});
end

%% Play
for k = 1:numel(tf)
    if ~ishghandle(fig)
        return
    end
    tk = tf(k);
    set(hTrB, 'XData', b.x(1:k) / 1e3, 'YData', b.h(1:k) / 1e3);
    set(hTrS, 'XData', sx(1:k) / 1e3, 'YData', sh(1:k) / 1e3);
    set(hDtB, 'XData', b.x(k) / 1e3, 'YData', b.h(k) / 1e3);
    set(hDtS, 'XData', sx(k) / 1e3, 'YData', sh(k) / 1e3);
    xs = [b.x(1:k), sx(1:k)] / 1e3;
    hs = [b.h(1:k), sh(1:k)] / 1e3;
    xr = [min(xs), max(xs)];
    pad = max(5, 0.05 * diff(xr));
    if xr(1) == xr(2)
        pad = 5;
    end
    axis(axO, [xr(1) - pad, xr(2) + pad, 0, max(10, 1.15 * max(hs))]);

    set(hEB, 'XData', toX(b.x(1:k), b.h(1:k)), 'YData', toY(b.x(1:k), b.h(1:k)));
    set(hES, 'XData', toX(sx(1:k), sh(1:k)), 'YData', toY(sx(1:k), sh(1:k)));
    set(hEdB, 'XData', toX(b.x(k), b.h(k)), 'YData', toY(b.x(k), b.h(k)));
    set(hEdS, 'XData', toX(sx(k), sh(k)), 'YData', toY(sx(k), sh(k)));

    set(hClock, 'String', sprintf('%s   T+%02d:%02d   (time x%d)', ...
        L.indicatorPlayback, floor(tk / 60), floor(mod(tk, 60)), round(speed * warp(k))));
    done = ev.t <= tk;
    shown = done(:).' & (cumsum(done(:).') > nnz(done) - 7);
    set(hLog, 'String', ev.text(shown));

    for cam = 1:2
        if cam == 1
            g = gB;
            ax = axB;
            cx = b.x(k);
            cy = b.h(k) + Pb.L / 2 * cos(b.th(k));
        else
            g = gS;
            ax = axS;
            cx = sx(k);
            cy = sh(k) + Ps.L / 2 * cos(s.th(k));
        end
        if tk <= tSep
            cy = b.h(k) + (Pb.L + Ps.L) / 2 * cos(b.th(k));
        end
        draw_vehicle(g.booster, [b.x(k); b.h(k)], b.th(k), b.gim(k), b.thr(k), 45);
        draw_vehicle(g.ship, [sx(k); sh(k)], s.th(k), s.gim(k), s.thr(k), 35);
        cy = max(cy, 0.75 * W);
        sky = min(max(cy, 0) / 80e3, 1) ^ 0.5;
        set(ax, 'Color', (1 - sky) * [0.53 0.81 0.98] + sky * [0.02 0.02 0.08]);
        axis(ax, [cx - W, cx + W, cy - W, cy + W]);
        if cam == 1
            str = hud_text('SUPER HEAVY', B.phaseList{b.ph(k)}, b, k, tk > tSep);
        else
            str = hud_text('STARSHIP', Sh.phaseList{s.ph(k)}, s, k, tk > tSep);
        end
        if sky > 0.5
            hc = 'w';
        else
            hc = 'k';
        end
        set(g.hud, 'String', str, 'Color', hc);
    end

    tm = tf(1:k) / 60;
    xl = [0, max(1, tf(k) / 60 * 1.05)];
    for j = 1:nT
        set(lB{j}, 'XData', tm, 'YData', yB{j}(1:k));
        set(lS{j}, 'XData', tm, 'YData', yS{j}(1:k));
        xlim(axT{j}, xl);
    end
    set(hC.cmd, 'XData', tm, 'YData', cmd(1:k));
    set(hC.resp, 'XData', tm, 'YData', resp(1:k));
    set(hC.err, 'XData', tm, 'YData', err(1:k));
    set(hC.gim, 'XData', tm, 'YData', gim(1:k));
    set(hC.rate, 'XData', tm, 'YData', rate(1:k));
    set(hC.aoa, 'XData', tm, 'YData', aoaC(1:k));
    set(hC.qa, 'XData', tm, 'YData', qa(1:k));
    set(hC.fin, 'XData', tm, 'YData', finSim(1:k));
    if ~isempty(hC.finCmd)
        set(hC.finCmd, 'XData', tm, 'YData', finCmd(1:k));
    end
    for j = 1:4
        xlim(axC{j}, xl);
    end
    drawnow
end
end


function pos = panel_pos(L, rowName, column)
row = L.rows.(rowName);
pos = [L.col(column), row(1), L.wid, row(2)];
end


function plain(ax)
set(ax, 'FontSize', 8);
grid(ax, 'on');
try
    set(ax, 'Toolbar', []);
catch
end
end


function y = sample_hold(tSrc, ySrc, tf)
[tu, iu] = unique(tSrc(:), 'last');
tq = min(max(tf, tu(1)), tu(end));
y = interp1(tu, ySrc(iu), tq);
end


function y = sample_stop(tSrc, ySrc, tf)
y = nan(size(tf));
if isempty(tSrc) || isempty(ySrc)
    return
end
[tu, iu] = unique(tSrc(:), 'last');
inside = tf >= tu(1) & tf <= tu(end);
y(inside) = interp1(tu, ySrc(iu), tf(inside));
end


function v = sample_flight(out, tf, P)
[tu, iu] = unique(out.t, 'last');
tq = min(max(tf, tu(1)), tu(end));
I = @(y) interp1(tu, y(iu), tq);
v.x = I(out.X(:, 1));
v.h = I(out.X(:, 2));
v.v = I(hypot(out.X(:, 3), out.X(:, 4)));
v.m = I(out.X(:, 5));
v.th = I(out.X(:, 6));
v.thr = I(out.aux.throttle);
v.gim = I(out.aux.gimbal);
v.gL = I(out.aux.gLoad);
v.ph = interp1(tu, out.phase(iu), tq, 'previous');
v.q = I(out.aux.q);
vx = I(out.X(:, 3));
vh = I(out.X(:, 4));
v.aoa = acosd(max(-1, min(1, (sin(v.th) .* vx + cos(v.th) .* vh) ./ max(v.v, 1e-6))));
v.aoa(v.v < 1) = 0;
v.heat = heatFlux(v.h, v.v, P.noseRadius, P);
end


function ev = mission_events(B, Sh, tSep)
t = 0;
txt = {'LIFTOFF'};
[~, iq] = max(B.aux.q .* (B.t < tSep));
t(end + 1) = B.t(iq); %#ok<AGROW>
txt{end + 1} = 'MAX-Q'; %#ok<AGROW>
t(end + 1) = tSep; %#ok<AGROW>
txt{end + 1} = 'HOT STAGING'; %#ok<AGROW>
names = {'boostback', 'BOOSTBACK BURN'; 'brake', 'BOOSTER LANDING BURN'};
for j = 1:size(names, 1)
    i = find(strcmp(B.phaseList, names{j, 1}), 1);
    if ~isempty(i) && ~isnan(B.phaseStart(i))
        t(end + 1) = B.phaseStart(i); %#ok<AGROW>
        txt{end + 1} = names{j, 2}; %#ok<AGROW>
    end
end
Mb = flightMetrics(B, false);
t(end + 1) = B.t(end); %#ok<AGROW>
if Mb.success
    txt{end + 1} = 'TOWER CATCH'; %#ok<AGROW>
else
    txt{end + 1} = 'BOOSTER LOST'; %#ok<AGROW>
end
i = find(strcmp(Sh.phaseList, 'bellyflop'), 1);
t(end + 1) = Sh.phaseStart(i); %#ok<AGROW>
txt{end + 1} = 'SHIP ENGINE CUT-OFF'; %#ok<AGROW>
iE = find(Sh.t > Sh.phaseStart(i) & Sh.X(:, 2) < 100e3 & Sh.X(:, 4) < 0, 1);
if ~isempty(iE)
    t(end + 1) = Sh.t(iE); %#ok<AGROW>
    txt{end + 1} = 'ENTRY (100 km)'; %#ok<AGROW>
end
i = find(strcmp(Sh.phaseList, 'landing'), 1);
if ~isempty(i) && ~isnan(Sh.phaseStart(i))
    t(end + 1) = Sh.phaseStart(i); %#ok<AGROW>
    txt{end + 1} = 'FLIP + LANDING BURN'; %#ok<AGROW>
end
Ms = flightMetrics(Sh, false);
t(end + 1) = Sh.t(end); %#ok<AGROW>
if Ms.success
    txt{end + 1} = 'SPLASHDOWN'; %#ok<AGROW>
else
    txt{end + 1} = 'SHIP LOST'; %#ok<AGROW>
end
[t, order] = sort(t);
ev.t = t;
ev.text = cellfun(@(tt, s) sprintf('T+%02d:%02d %s', floor(tt / 60), floor(mod(tt, 60)), s), ...
    num2cell(t), txt(order), 'UniformOutput', false);
end


function g = build_camera(ax, Pb, Ps, xPad, ttl)
hold(ax, 'on');
axis(ax, 'equal');
patch(ax, [-1e7 3e5 3e5 -1e7], [-1e3 -1e3 0 0], [0.35 0.55 0.25], 'EdgeColor', 'none');
patch(ax, [3e5 1e8 1e8 3e5], [-1e3 -1e3 0 0], [0.10 0.30 0.60], 'EdgeColor', 'none');
plot(ax, xPad + [-12 12], [0.5 0.5], 'Color', [0.2 0.2 0.2], 'LineWidth', 6);
hArms = Pb.hLand + 0.9 * Pb.L;
xT = xPad + Pb.diam / 2 + 12;
patch(ax, xT + [0 8 8 0], [0 0 hArms + 25 hArms + 25], [0.3 0.3 0.33], 'EdgeColor', 'none');
plot(ax, [xPad - Pb.diam / 2 - 3, xT], [hArms hArms], 'Color', [0.2 0.2 0.22], 'LineWidth', 4);
g.booster = vehicle_shapes(ax, 'booster', Pb);
g.ship = vehicle_shapes(ax, 'ship', Ps);
g.hud = text(ax, 0.02, 0.98, '', 'Units', 'normalized', 'FontName', 'Monospaced', ...
    'FontSize', 8, 'VerticalAlignment', 'top');
xlabel(ax, 'Downrange [m]');
ylabel(ax, 'Altitude [m]');
title(ax, ttl);
end


function v = vehicle_shapes(ax, kind, P)
L = P.L;
d = P.diam;
r = d / 2;
steel = [0.80 0.82 0.85];
dark = [0.22 0.22 0.25];
switch kind
    case 'booster'
        polys = {[-r r r -r; 0 0 L-3 L-3], steel
            [-r r r -r; L-3 L-3 L L], dark
            [r r+3.5 r+3.5 r; L-11 L-11 L-6 L-6], dark
            [-r -r-3.5 -r-3.5 -r; L-11 L-11 L-6 L-6], dark
            [-0.85*r 0.85*r 0.6*r -0.6*r; 0 0 -2.5 -2.5], dark};
    case 'ship'
        polys = {[-r r r 0.85*r 0.5*r 0 -0.5*r -0.85*r -r; ...
            0 0 0.78*L 0.87*L 0.95*L L 0.95*L 0.87*L 0.78*L], steel
            [r-1.3 r r r-1.3; 0 0 0.78*L 0.78*L], dark
            [r r+3 r+3 r; 1 1 11 14], dark
            [-r -r-3 -r-3 -r; 1 1 11 14], dark
            [0.8*r 0.8*r+2.2 0.8*r+2.2 0.85*r; 0.80*L 0.80*L 0.87*L 0.90*L], dark
            [-0.8*r -0.8*r-2.2 -0.8*r-2.2 -0.85*r; 0.80*L 0.80*L 0.87*L 0.90*L], dark};
end
v.flame = patch(ax, nan, nan, [1 0.55 0], 'EdgeColor', [1 0.9 0.2]);
v.poly = polys(:, 1);
v.h = cell(size(polys, 1), 1);
for j = 1:size(polys, 1)
    v.h{j} = patch(ax, nan, nan, polys{j, 2}, 'EdgeColor', [0.15 0.15 0.15]);
end
v.w = d;
end


function draw_vehicle(v, pos, th, gim, thr, flameLen)
n = [sin(th); cos(th)];
sd = [n(2); -n(1)];
for j = 1:numel(v.h)
    p = v.poly{j};
    R = pos + sd * p(1, :) + n * p(2, :);
    set(v.h{j}, 'XData', R(1, :), 'YData', R(2, :));
end
if isnan(thr)
    thr = 0;
end
if isnan(gim)
    gim = 0;
end
fl = flameLen * thr * (1 + 0.15 * rand);
nf = [sin(th - gim); cos(th - gim)];
sf = [nf(2); -nf(1)];
F = pos + sf * [-0.4 * v.w, 0, 0.4 * v.w] + nf * [-2, -2, -fl, -2];
if thr > 0.01
    vis = 'on';
else
    vis = 'off';
end
set(v.flame, 'XData', F(1, :), 'YData', F(2, :), 'Visible', vis);
end


function [ax, lB, lS] = telemetry_axes(ax, ylab, L)
hold(ax, 'on');
grid(ax, 'on');
lB = plot(ax, nan, nan, '-', 'Color', L.color.booster, 'LineWidth', 1.6);
lS = plot(ax, nan, nan, '-', 'Color', L.color.ship, 'LineWidth', 1.6);
xlabel(ax, 'Time [min]');
title(ax, ylab, 'Interpreter', 'none');
plain(ax);
end


function str = hud_text(name, phase, v, k, separated)
if ~separated
    phase = 'stack ascent (attached)';
end
thr = v.thr(k);
aoa = v.aoa(k);
if isnan(thr), thr = 0; end
if isnan(aoa), aoa = 0; end
str = sprintf(['%s\nPhase : %s\nAlt   : %8.2f km\nSpeed : %8.0f m/s\n' ...
    'Throt : %6.0f %%\nPitch : %6.1f deg\nAoA   : %6.1f deg\nMass  : %8.0f t'], ...
    name, phase, v.h(k) / 1e3, v.v(k), 100 * thr, ...
    rad2deg(atan2(sin(v.th(k)), cos(v.th(k)))), aoa, v.m(k) / 1e3);
end
