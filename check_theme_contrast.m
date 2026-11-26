function check_theme_contrast()
%CHECK_THEME_CONTRAST  WCAG contrast for every text object in a sample window.
%
%   check_theme_contrast
%
%   Builds a dark graph, a camera axes, a light banner, a legend, and both
%   a light and a dark control. For each camera sky from daytime blue to
%   black it reapplies the theme and asserts that every text object, tick
%   color, and control title has a WCAG contrast ratio of at least 4.5
%   against the surface behind it. Legend text, box, edge, and font must
%   stay on the palette style_legend already uses.

here = fileparts(mfilename('fullpath'));
if isempty(here)
    here = pwd;
end
addpath(here);
try
    graphics_toolkit('gnuplot');
catch
end

T = playback_theme();
fails = {};
ratio = playback_theme('contrast', [1 1 1], [0 0 0]);
if abs(ratio - 21) > 0.02
    fails{end + 1} = sprintf('white on black ratio is %.3f', ratio); %#ok<AGROW>
end
if playback_theme('contrast', T.text, T.legendBack) < T.minContrast
    fails{end + 1} = 'legend palette is below 4.5'; %#ok<AGROW>
end

fig = figure('Visible', 'off');
playback_theme('figure', fig);

ax = axes('Parent', fig, 'Position', [0.08 0.55 0.36 0.32]);
hold(ax, 'on');
grid(ax, 'on');
lineColor = [0.85 0.25 0.15];
hLine = plot(ax, 1:4, [1 2 1.4 2.2], '-', 'Color', lineColor, 'LineWidth', 1.4);
title(ax, 'Altitude');
xlabel(ax, 'Time');
ylabel(ax, 'km');
note = text(ax, 0.7, 0.8, 'log', 'Units', 'normalized');
playback_theme('graph', ax);
leg = legend(ax, hLine, {'Super Heavy'}, 'Location', 'northwest');
paint_legend(leg, T);
legSnap = legend_snapshot(leg);

axSky = axes('Parent', fig, 'Position', [0.55 0.55 0.36 0.32]);
title(axSky, 'Super Heavy camera');
xlabel(axSky, 'Downrange');
playback_theme('overlay', axSky);
hud = text(axSky, 0.02, 0.98, 'SUPER HEAVY', 'Units', 'normalized', ...
    'VerticalAlignment', 'top');

lightCtl = [];
darkCtl = [];
try
    lightCtl = uicontrol('Parent', fig, 'Style', 'text', 'String', 'light', ...
        'Units', 'normalized', 'Position', [0.08 0.06 0.18 0.08], ...
        'BackgroundColor', [0.94 0.94 0.94], 'ForegroundColor', [1 1 1]);
    darkCtl = uicontrol('Parent', fig, 'Style', 'text', 'String', 'dark', ...
        'Units', 'normalized', 'Position', [0.30 0.06 0.18 0.08], ...
        'BackgroundColor', [0.12 0.12 0.14], 'ForegroundColor', [0 0 0]);
catch ME
    fprintf('uicontrol skipped: %s\n', ME.message);
end
try
    uipanel('Parent', fig, 'Title', 'Light panel', 'Units', 'normalized', ...
        'Position', [0.52 0.05 0.2 0.22], 'BackgroundColor', [0.95 0.95 0.95], ...
        'ForegroundColor', [1 1 1]);
    uipanel('Parent', fig, 'Title', 'Dark panel', 'Units', 'normalized', ...
        'Position', [0.74 0.05 0.2 0.22], 'BackgroundColor', T.figure, ...
        'ForegroundColor', [0 0 0]);
catch ME
    fprintf('uipanel skipped: %s\n', ME.message);
end
try
    annotation(fig, 'textbox', [0.12 0.90 0.76 0.06], 'String', 'PLAYBACK', ...
        'BackgroundColor', T.bannerBack, 'EdgeColor', 'none', ...
        'Color', [1 1 1], 'FaceAlpha', 0.9, 'HorizontalAlignment', 'center');
catch ME
    fprintf('annotation skipped: %s\n', ME.message);
end

playback_theme('reinforce', fig);
try
    n0 = playback_theme('assert', fig);
    if n0 < 1
        fails{end + 1} = 'assert found no text'; %#ok<AGROW>
    end
catch ME
    fails{end + 1} = ['initial ' ME.message]; %#ok<AGROW>
end

set(axSky, 'Color', [1 1 0.8]);
set(hud, 'Color', [1 1 0.6]);
caught = false;
try
    playback_theme('assert', fig);
catch
    caught = true;
end
if ~caught
    fails{end + 1} = 'assert accepted light text on a light sky'; %#ok<AGROW>
end

day = [0.53 0.81 0.98];
night = [0.02 0.02 0.08];
steps = [0:0.05:1, 0.42];
for s = steps
    bg = (1 - s) * day + s * night;
    set(axSky, 'Color', bg);
    playback_theme('reinforce', fig);
    try
        playback_theme('assert', fig);
    catch ME
        fails{end + 1} = sprintf('sky %.2f: %s', s, ME.message); %#ok<AGROW>
        continue
    end
    fg = color_of(hud);
    if ~same_rgb(fg, playback_theme('ink', bg))
        fails{end + 1} = sprintf('sky %.2f: readout ink', s); %#ok<AGROW>
    end
    if playback_theme('contrast', fg, bg) < T.minContrast
        fails{end + 1} = sprintf('sky %.2f: readout ratio', s); %#ok<AGROW>
    end
    titleColor = color_of(get(axSky, 'Title'));
    figureColor = color_of(fig);
    if ~same_rgb(titleColor, playback_theme('ink', figureColor))
        fails{end + 1} = sprintf('sky %.2f: camera title left the figure', s); %#ok<AGROW>
    end
    if playback_theme('contrast', titleColor, figureColor) < T.minContrast
        fails{end + 1} = sprintf('sky %.2f: camera title ratio', s); %#ok<AGROW>
    end
    tickColor = color_of(axSky, 'XColor');
    if playback_theme('contrast', tickColor, figureColor) < T.minContrast
        fails{end + 1} = sprintf('sky %.2f: tick ratio', s); %#ok<AGROW>
    end
    if ~legend_unchanged(leg, legSnap)
        fails{end + 1} = sprintf('sky %.2f: legend changed', s); %#ok<AGROW>
    end
end

if ~same_rgb(color_of(get(ax, 'Title')), T.inkLight)
    fails{end + 1} = 'graph title is not the light ink'; %#ok<AGROW>
end
if playback_theme('contrast', color_of(note), color_of(ax)) < T.minContrast
    fails{end + 1} = 'in-plot note contrast'; %#ok<AGROW>
end
if ~same_rgb(color_of(hLine), lineColor)
    fails{end + 1} = 'line color changed'; %#ok<AGROW>
end
if ~legend_unchanged(leg, legSnap)
    fails{end + 1} = 'legend changed'; %#ok<AGROW>
end

if ~isempty(lightCtl) && ishghandle(lightCtl)
    if mean(color_of(lightCtl, 'ForegroundColor')) > 0.2
        fails{end + 1} = 'light control text is not dark'; %#ok<AGROW>
    end
    if playback_theme('contrast', color_of(lightCtl, 'ForegroundColor'), ...
            color_of(lightCtl, 'BackgroundColor')) < T.minContrast
        fails{end + 1} = 'light control contrast'; %#ok<AGROW>
    end
    if ~same_rgb(color_of(lightCtl, 'BackgroundColor'), [0.94 0.94 0.94])
        fails{end + 1} = 'light control background changed'; %#ok<AGROW>
    end
end
if ~isempty(darkCtl) && ishghandle(darkCtl)
    if mean(color_of(darkCtl, 'ForegroundColor')) < 0.8
        fails{end + 1} = 'dark control text is not light'; %#ok<AGROW>
    end
    if playback_theme('contrast', color_of(darkCtl, 'ForegroundColor'), ...
            color_of(darkCtl, 'BackgroundColor')) < T.minContrast
        fails{end + 1} = 'dark control contrast'; %#ok<AGROW>
    end
    if ~same_rgb(color_of(darkCtl, 'BackgroundColor'), [0.12 0.12 0.14])
        fails{end + 1} = 'dark control background changed'; %#ok<AGROW>
    end
end

if ishghandle(fig)
    close(fig);
end
if isempty(fails)
    fprintf('CONTRAST CHECKS PASSED\n');
    return
end
fprintf('FAILED %d CHECKS\n', numel(fails));
for i = 1:numel(fails)
    fprintf('  - %s\n', fails{i});
end
error('check_theme_contrast:Failed', '%d checks failed.', numel(fails));
end


function paint_legend(leg, T)
if isempty(leg) || ~ishghandle(leg)
    return
end
try_set(leg, 'TextColor', T.text);
try_set(leg, 'Color', T.legendBack);
try_set(leg, 'EdgeColor', T.text);
try_set(leg, 'FontSize', T.fontSmall);
end


function snap = legend_snapshot(leg)
snap.text = prop_or(leg, 'TextColor');
snap.color = prop_or(leg, 'Color');
snap.edge = prop_or(leg, 'EdgeColor');
snap.font = prop_or(leg, 'FontSize');
snap.children = child_colors(leg);
end


function tf = legend_unchanged(leg, snap)
tf = same_rgb(prop_or(leg, 'TextColor'), snap.text) ...
    && same_rgb(prop_or(leg, 'Color'), snap.color) ...
    && same_rgb(prop_or(leg, 'EdgeColor'), snap.edge) ...
    && isequal(prop_or(leg, 'FontSize'), snap.font);
if ~tf
    return
end
nowChildren = child_colors(leg);
if numel(nowChildren) ~= numel(snap.children)
    tf = false;
    return
end
for i = 1:numel(snap.children)
    if ~same_rgb(nowChildren{i}, snap.children{i})
        tf = false;
        return
    end
end
end


function colors = child_colors(h)
colors = {};
kids = [];
try
    kids = findall(h, 'Type', 'text');
catch
end
for i = 1:numel(kids)
    if isequal(kids(i), h)
        continue
    end
    c = prop_or(kids(i), 'Color');
    if ~isempty(c)
        colors{end + 1} = c; %#ok<AGROW>
    end
end
end


function rgb = color_of(h, name)
if nargin < 2
    name = 'Color';
end
rgb = prop_or(h, name);
if isnumeric(rgb)
    rgb = double(rgb(:)).';
    if numel(rgb) >= 3
        rgb = rgb(1:3);
    end
end
end


function value = prop_or(h, name)
value = [];
try
    value = get(h, name);
catch
end
end


function tf = same_rgb(a, b)
if isempty(a) && isempty(b)
    tf = true;
    return
end
if ~isnumeric(a) || ~isnumeric(b) || numel(a) < 3 || numel(b) < 3
    tf = isequal(a, b);
    return
end
a = double(a(:)).';
b = double(b(:)).';
tf = all(abs(a(1:3) - b(1:3)) <= 1e-6);
end


function try_set(h, name, value)
try
    set(h, name, value);
catch
end
end
