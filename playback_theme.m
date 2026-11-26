function varargout = playback_theme(action, varargin)
%PLAYBACK_THEME  Colors for the mission-control window.
%
%   T = playback_theme
%   playback_theme('figure', fig)     dark figure, light Theme when present
%   playback_theme('graph', ax)       dark plot area, contrasting labels
%   playback_theme('overlay', ax)     leave the plot color, contrast the labels
%   playback_theme('reinforce', fig)  put those colors back after a redraw
%   ink = playback_theme('ink', rgb)  white or black, whichever clears rgb
%   playback_theme('contrast', a, b)  WCAG contrast ratio of two colors
%   n = playback_theme('assert', fig) error if any text is below 4.5
%
%   Graph interiors and the figure chrome stay dark. Line colors, the Earth
%   disk, and the camera sky are not recolored. Each string is then white
%   or black against the surface it actually sits on: titles and tick
%   numbers sit on the figure, readouts inside an axes sit on that axes
%   color (the camera sky), and a control's text sits on that control.
%   The choice is the one with the higher WCAG ratio, and it has to reach
%   at least 4.5. White and black are the two inks because the mid-blue
%   camera sky is too gray for #F0F0F0 or for the legend's near-black.
%
%   Legends are not part of that pass. Their text, box, edge, and font stay
%   whatever style_legend already set. T.text and T.legendBack exist so
%   that styling does not follow the contrast inks.
%
%   R2025a figure Theme 'light' stops a dark MATLAB Online desktop from
%   restyling the window (and from repainting the legends). Call
%   'reinforce' after every redraw. Reinforce does not call theme() again
%   and does not walk legend objects.

if nargin == 0
    varargout{1} = theme_struct();
    return
end
switch lower(strtrim(char(action)))
    case 'figure'
        apply_figure(varargin{1});
    case 'graph'
        style_axes(varargin{1}, true);
    case 'overlay'
        style_axes(varargin{1}, false);
    case 'reinforce'
        reinforce(varargin{1});
    case 'ink'
        varargout{1} = ink_for(varargin{1});
    case 'contrast'
        varargout{1} = contrast_ratio(varargin{1}, varargin{2});
    case 'assert'
        n = assert_contrast(varargin{1});
        if nargout > 0
            varargout{1} = n;
        end
    otherwise
        error('playback_theme:Action', 'Unknown action "%s".', char(action));
end
end


function T = theme_struct()
% Figure chrome is a step darker than the graph panels. T.text is the
% legend ink and is not the ink used on other light surfaces.
T.figure = [0.10 0.10 0.12];
T.plot = [0.16 0.16 0.18];
T.text = [0.1 0.1 0.1];
T.inkLight = [1 1 1];
T.inkDark = [0 0 0];
T.inPlot = T.inkLight;
T.grid = [0.62 0.63 0.66];
T.gridAlpha = 0.4;
T.bannerBack = [1 0.96 0.93];
T.legendBack = [1 1 1];
T.minContrast = 4.5;
T.fontAxes = 10;
T.fontSmall = 9;
T.fontTitle = 11;
T.fontBanner = 13;
T.fontHud = 10;
end


function apply_figure(fig)
T = theme_struct();
% Theme first. A dark desktop theme would repaint legends; 'light' blocks
% that, then the explicit colors paint the dark figure.
if ~try_set(fig, 'Theme', 'light')
    try
        theme(fig, 'light');
    catch
    end
end
paint_figure(fig, T);
try_set(fig, 'DefaultLegendTextColor', T.text);
try_set(fig, 'DefaultLegendColor', T.legendBack);
try_set(fig, 'DefaultLegendEdgeColor', T.text);
end


function paint_figure(fig, T)
tick = ink_for(T.figure);
try_set(fig, 'Color', T.figure);
try_set(fig, 'DefaultAxesColor', T.plot);
try_set(fig, 'DefaultAxesXColor', tick);
try_set(fig, 'DefaultAxesYColor', tick);
try_set(fig, 'DefaultAxesZColor', tick);
try_set(fig, 'DefaultAxesGridColor', T.grid);
try_set(fig, 'DefaultAxesMinorGridColor', T.grid);
try_set(fig, 'DefaultAxesGridAlpha', T.gridAlpha);
try_set(fig, 'DefaultTextColor', tick);
try_set(fig, 'DefaultAxesFontSize', T.fontAxes);
try_set(fig, 'DefaultTextFontSize', T.fontSmall);
% Controls keep whatever background they were given. A light uicontrol
% then gets dark type from reinforce; a dark one gets light type.
try_set(fig, 'DefaultUicontrolForegroundColor', T.inkDark);
end


function style_axes(ax, darkPlot)
if isempty(ax) || ~ishghandle(ax)
    return
end
T = theme_struct();
if darkPlot
    paint_plot(ax, T);
    try
        setappdata(ax, 'PlaybackGraph', true);
    catch
    end
    partner = [];
    try
        partner = getappdata(ax, 'yyRight');
    catch
    end
    if ~isempty(partner) && ishghandle(partner) && partner ~= ax
        % Octave's yyaxis overlay stays transparent so it does not cover
        % the dark plot underneath. Its tick labels follow the figure.
        paint_chrome(partner, T, true);
    end
end
paint_chrome(ax, T, true);
end


function paint_plot(ax, T)
try_set(ax, 'Color', T.plot);
try_set(ax, 'Box', 'on');
try_set(ax, 'TickDir', 'out');
paint_grid(ax, T);
end


function paint_grid(ax, T)
% Tick colors are set separately. Put the grey grid back afterwards so
% an axis color does not take the grid lines with it.
try_set(ax, 'GridColor', T.grid);
try_set(ax, 'MinorGridColor', T.grid);
try_set(ax, 'GridAlpha', T.gridAlpha);
try_set(ax, 'MinorGridAlpha', T.gridAlpha * 0.6);
try_set(ax, 'GridColorMode', 'manual');
try_set(ax, 'MinorGridColorMode', 'manual');
end


function paint_chrome(ax, T, setFont)
% Tick numbers are drawn in the margin, on the figure, not on the sky.
tick = ink_for(outside_axes_color(ax));
try_set(ax, 'XColor', tick);
try_set(ax, 'YColor', tick);
try_set(ax, 'ZColor', tick);
if setFont
    try_set(ax, 'FontSize', T.fontAxes);
end
paint_rulers(ax, 'XAxis', T, setFont);
paint_rulers(ax, 'YAxis', T, setFont);
paint_rulers(ax, 'ZAxis', T, setFont);
paint_label(ax, 'Title', T, setFont);
paint_label(ax, 'Subtitle', T, setFont);
paint_label(ax, 'XLabel', T, setFont);
paint_label(ax, 'YLabel', T, setFont);
paint_label(ax, 'ZLabel', T, setFont);
paint_grid(ax, T);
end


function paint_rulers(ax, which, T, setFont)
try
    rulers = get(ax, which);
catch
    return
end
if isempty(rulers)
    return
end
tick = ink_for(outside_axes_color(ax));
for k = 1:numel(rulers)
    rk = rulers(k);
    try_set(rk, 'Color', tick);
    lbl = [];
    try
        lbl = get(rk, 'Label');
    catch
    end
    if isempty(lbl) || ~ishghandle(lbl) || in_legend(lbl)
        continue
    end
    try_set(lbl, 'Color', ink_for(backdrop_of(lbl)));
    try_set(lbl, 'FontWeight', 'bold');
    if setFont
        try_set(lbl, 'FontSize', T.fontAxes);
    end
end
end


function paint_label(ax, which, T, setFont)
try
    h = get(ax, which);
catch
    return
end
if isempty(h) || ~ishghandle(h) || in_legend(h)
    return
end
try_set(h, 'Color', ink_for(backdrop_of(h)));
try_set(h, 'FontWeight', 'bold');
if ~setFont
    return
end
if strcmp(which, 'Title')
    try_set(h, 'FontSize', T.fontTitle);
else
    try_set(h, 'FontSize', T.fontAxes);
end
end


function reinforce(fig)
if isempty(fig) || ~ishghandle(fig)
    return
end
T = theme_struct();
paint_figure(fig, T);
try
    axs = findall(fig, 'Type', 'axes');
catch
    axs = [];
end
for i = 1:numel(axs)
    ax = axs(i);
    if ~ishghandle(ax) || in_legend(ax) || is_annotation_axes(ax)
        continue
    end
    dark = false;
    try
        dark = isappdata(ax, 'PlaybackGraph') && getappdata(ax, 'PlaybackGraph');
    catch
        dark = false;
    end
    if dark
        paint_plot(ax, T);
    end
    % Font sizes belong to the resize scaler. Put the ink back only.
    paint_chrome(ax, T, false);
end
restyle_boxes(fig, T);
restyle_panels(fig);
restyle_text(fig);
end


function restyle_text(fig)
objs = find_kind(fig, 'text');
for i = 1:numel(objs)
    h = objs(i);
    if ~ishghandle(h) || in_legend(h)
        continue
    end
    try_set(h, 'Color', ink_for(backdrop_of(h)));
end
end


function restyle_boxes(fig, T)
% The banner is a light strip. Its string is chosen from that strip,
% including FaceAlpha against the figure. Text arrows keep their line
% color; only the string is recolored.
boxes = join_kinds(fig, {'textboxshape', 'textbox'});
for i = 1:numel(boxes)
    paint_banner(boxes(i), T);
end
groups = find_kind(fig, 'hggroup');
for i = 1:numel(groups)
    h = groups(i);
    if ~ishghandle(h) || in_legend(h) || ~is_textbox_group(h)
        continue
    end
    paint_banner(h, T);
end
arrows = join_kinds(fig, {'textarrowshape', 'textarrow'});
for i = 1:numel(arrows)
    h = arrows(i);
    if ~ishghandle(h) || in_legend(h)
        continue
    end
    try_set(h, 'TextColor', ink_for(figure_color(h)));
end
end


function paint_banner(h, T)
if ~ishghandle(h) || in_legend(h)
    return
end
try_set(h, 'BackgroundColor', T.bannerBack);
try_set(h, 'Color', ink_for(backdrop_of(h)));
end


function tf = is_textbox_group(h)
tf = false;
try
    get(h, 'String');
    get(h, 'FitBoxToText');
    tf = true;
catch
end
end


function restyle_panels(fig)
% Title ink follows the control's own background. Backgrounds are not
% rewritten, so a light uicontrol stays light and gets black type.
kinds = {'uipanel', 'uitab', 'uitabgroup', 'uicontrol'};
for k = 1:numel(kinds)
    objs = find_kind(fig, kinds{k});
    for i = 1:numel(objs)
        h = objs(i);
        if ~ishghandle(h) || in_legend(h)
            continue
        end
        try_set(h, 'ForegroundColor', ink_for(backdrop_of(h)));
    end
end
end


function n = assert_contrast(fig)
[msgs, n] = contrast_messages(fig);
if n < 1
    error('playback_theme:Contrast', 'No text objects to check.');
end
if isempty(msgs)
    return
end
block = msgs{1};
for i = 2:numel(msgs)
    block = [block ' | ' msgs{i}]; %#ok<AGROW>
end
error('playback_theme:Contrast', '%s', block);
end


function [msgs, n] = contrast_messages(fig)
T = theme_struct();
msgs = {};
n = 0;
if isempty(fig) || ~ishghandle(fig)
    msgs = {'Figure is not a valid graphics object.'};
    return
end
texts = find_kind(fig, 'text');
for i = 1:numel(texts)
    h = texts(i);
    % Octave legends keep blank placeholder strings painted white, the
    % same color as the legend box. They are not readable text. Real
    % legend labels still have a string and are checked below.
    if in_legend(h) && blank_string(h)
        continue
    end
    [msgs, n] = check_pair(msgs, n, h, safe_get(h, 'Color'), ...
        backdrop_of(h), T.minContrast);
end
legs = find_legends(fig);
for i = 1:numel(legs)
    leg = legs(i);
    ink = safe_get(leg, 'TextColor');
    if isempty(as_rgb(ink))
        continue
    end
    % TextColor is the legend ink. The legend object itself is not a
    % string, so this does not go through the text-only legend filter.
    [msgs, n] = record_contrast(msgs, n, leg, ink, legend_plate(leg), T.minContrast);
end
boxes = join_kinds(fig, {'textboxshape', 'textbox'});
for i = 1:numel(boxes)
    [msgs, n] = check_pair(msgs, n, boxes(i), safe_get(boxes(i), 'Color'), ...
        backdrop_of(boxes(i)), T.minContrast);
end
groups = find_kind(fig, 'hggroup');
for i = 1:numel(groups)
    h = groups(i);
    if ~is_textbox_group(h)
        continue
    end
    [msgs, n] = check_pair(msgs, n, h, safe_get(h, 'Color'), ...
        backdrop_of(h), T.minContrast);
end
kinds = {'uipanel', 'uitab', 'uitabgroup', 'uicontrol'};
for k = 1:numel(kinds)
    objs = find_kind(fig, kinds{k});
    for i = 1:numel(objs)
        h = objs(i);
        [msgs, n] = check_pair(msgs, n, h, safe_get(h, 'ForegroundColor'), ...
            backdrop_of(h), T.minContrast);
    end
end
axs = find_kind(fig, 'axes');
for i = 1:numel(axs)
    ax = axs(i);
    if ~ishghandle(ax) || in_legend(ax) || is_annotation_axes(ax)
        continue
    end
    plate = outside_axes_color(ax);
    [msgs, n] = check_pair(msgs, n, ax, safe_get(ax, 'XColor'), plate, T.minContrast);
    [msgs, n] = check_pair(msgs, n, ax, safe_get(ax, 'YColor'), plate, T.minContrast);
    [msgs, n] = check_pair(msgs, n, ax, safe_get(ax, 'ZColor'), plate, T.minContrast);
end
end


function [msgs, n] = check_pair(msgs, n, h, fg, bg, minimum)
if isempty(h) || ~ishghandle(h)
    return
end
% Legend axes are not tick labels. Strings inside a legend are text, and
% those are checked against the legend box.
if in_legend(h)
    kind = '';
    try
        kind = lower(char(get(h, 'Type')));
    catch
    end
    if ~strcmp(kind, 'text')
        return
    end
end
[msgs, n] = record_contrast(msgs, n, h, fg, bg, minimum);
end


function [msgs, n] = record_contrast(msgs, n, h, fg, bg, minimum)
fg = as_rgb(fg);
bg = as_rgb(bg);
if isempty(fg) || isempty(bg)
    return
end
n = n + 1;
ratio = contrast_ratio(fg, bg);
if ~isfinite(ratio) || ratio < minimum
    msgs{end + 1} = sprintf('%s contrast %.2f (needs %.1f)', ...
        object_name(h), ratio, minimum); %#ok<AGROW>
end
end


function name = object_name(h)
name = 'object';
try
    name = char(get(h, 'Type'));
catch
end
label = '';
try
    raw = get(h, 'String');
    if ischar(raw)
        label = strtrim(raw(:).');
    elseif iscell(raw) && ~isempty(raw)
        label = strtrim(char(raw{1}));
    end
catch
end
if ~isempty(label)
    if numel(label) > 24
        label = label(1:24);
    end
    name = [name ' "' label '"'];
end
end


function tf = blank_string(h)
tf = true;
raw = safe_get(h, 'String');
if ischar(raw)
    tf = isempty(strtrim(raw(:).'));
    return
end
if iscell(raw)
    for i = 1:numel(raw)
        if ~isempty(strtrim(char(raw{i})))
            tf = false;
            return
        end
    end
end
end


function legs = find_legends(fig)
legs = find_kind(fig, 'legend');
axs = find_kind(fig, 'axes');
for i = 1:numel(axs)
    if ~is_legend_node(axs(i))
        continue
    end
    if isempty(legs)
        legs = axs(i);
    else
        legs = [legs; axs(i)]; %#ok<AGROW>
    end
end
end


function rgb = ink_for(bg)
% White on a dark plate, black on a light plate. The winner is whichever
% WCAG ratio is higher. Against every sRGB gray, one of these two is at
% least 4.5.
T = theme_struct();
bg = as_rgb(bg);
if isempty(bg)
    rgb = T.inkLight;
    return
end
if contrast_ratio(T.inkLight, bg) >= contrast_ratio(T.inkDark, bg)
    rgb = T.inkLight;
else
    rgb = T.inkDark;
end
end


function ratio = contrast_ratio(a, b)
La = relative_luminance(a);
Lb = relative_luminance(b);
if ~isfinite(La) || ~isfinite(Lb)
    ratio = NaN;
    return
end
top = max(La, Lb);
bot = min(La, Lb);
ratio = (top + 0.05) / (bot + 0.05);
end


function L = relative_luminance(rgb)
rgb = as_rgb(rgb);
if isempty(rgb)
    L = NaN;
    return
end
lin = zeros(1, 3);
for i = 1:3
    c = rgb(i);
    if c <= 0.04045
        lin(i) = c / 12.92;
    else
        lin(i) = ((c + 0.055) / 1.055) ^ 2.4;
    end
end
L = 0.2126 * lin(1) + 0.7152 * lin(2) + 0.0722 * lin(3);
end


function bg = backdrop_of(h)
% Surface the glyphs are drawn on.
if in_legend(h)
    bg = legend_plate(h);
    return
end
plate = own_plate(h);
if ~isempty(plate)
    bg = composite_plate(h, plate);
    return
end
if is_margin_label(h)
    ax = [];
    try
        ax = get(h, 'Parent');
    catch
    end
    bg = outside_axes_color(ax);
    return
end
bg = nearest_plate(h);
end


function plate = own_plate(h)
% A solid BackgroundColor is the plate. 'none' lets the parent show.
plate = [];
kind = '';
try
    kind = lower(char(get(h, 'Type')));
catch
    return
end
if any(strcmp(kind, {'text', 'textbox', 'textboxshape', 'hggroup', ...
        'uicontrol', 'uipanel', 'uitab', 'uitabgroup'}))
    plate = as_rgb(safe_get(h, 'BackgroundColor'));
end
end


function bg = composite_plate(h, plate)
bg = plate;
alpha = 1;
try
    alpha = double(get(h, 'FaceAlpha'));
catch
end
if isempty(alpha) || ~isfinite(alpha) || alpha >= 1
    return
end
if alpha < 0
    alpha = 0;
end
behind = figure_color(h);
bg = alpha * plate + (1 - alpha) * behind;
end


function bg = nearest_plate(h)
bg = figure_color(h);
p = h;
for guard = 1:16
    try
        p = get(p, 'Parent');
    catch
        return
    end
    if isempty(p) || ~ishghandle(p)
        return
    end
    if is_legend_node(p)
        bg = legend_plate(p);
        return
    end
    kind = '';
    try
        kind = lower(char(get(p, 'Type')));
    catch
        return
    end
    if strcmp(kind, 'axes')
        if is_annotation_axes(p)
            continue
        end
        c = as_rgb(safe_get(p, 'Color'));
        if ~isempty(c)
            bg = c;
            return
        end
    elseif any(strcmp(kind, {'hggroup', 'uipanel', 'uitab', 'uitabgroup', ...
            'uicontainer', 'uicontrol'}))
        c = as_rgb(safe_get(p, 'BackgroundColor'));
        if ~isempty(c)
            bg = composite_plate(p, c);
            return
        end
    elseif strcmp(kind, 'figure')
        c = as_rgb(safe_get(p, 'Color'));
        if ~isempty(c)
            bg = c;
        end
        return
    end
end
end


function bg = outside_axes_color(ax)
% Titles and tick labels are outside the plot box, so the axes color
% (the camera sky) is not the surface under them.
bg = [];
if isempty(ax) || ~ishghandle(ax)
    bg = [0 0 0];
    return
end
parent = [];
try
    parent = get(ax, 'Parent');
catch
end
if ~isempty(parent) && ishghandle(parent)
    kind = '';
    try
        kind = lower(char(get(parent, 'Type')));
    catch
    end
    if strcmp(kind, 'figure')
        bg = as_rgb(safe_get(parent, 'Color'));
    elseif any(strcmp(kind, {'uipanel', 'uitab', 'uicontainer'}))
        bg = as_rgb(safe_get(parent, 'BackgroundColor'));
    end
end
if isempty(bg)
    bg = figure_color(ax);
end
end


function bg = figure_color(h)
bg = [0 0 0];
fig = h;
for guard = 1:16
    if isempty(fig) || ~ishghandle(fig)
        return
    end
    kind = '';
    try
        kind = lower(char(get(fig, 'Type')));
    catch
        return
    end
    if strcmp(kind, 'figure')
        c = as_rgb(safe_get(fig, 'Color'));
        if ~isempty(c)
            bg = c;
        end
        return
    end
    try
        fig = get(fig, 'Parent');
    catch
        return
    end
end
end


function bg = legend_plate(h)
bg = [1 1 1];
leg = h;
if ~is_legend_node(h)
    p = h;
    for guard = 1:16
        try
            p = get(p, 'Parent');
        catch
            p = [];
        end
        if isempty(p) || ~ishghandle(p)
            break
        end
        if is_legend_node(p)
            leg = p;
            break
        end
    end
end
c = as_rgb(safe_get(leg, 'Color'));
if ~isempty(c)
    bg = c;
end
end


function tf = is_margin_label(h)
tf = false;
try
    if ~strcmpi(get(h, 'Type'), 'text')
        return
    end
catch
    return
end
ax = [];
try
    ax = get(h, 'Parent');
catch
    return
end
if isempty(ax) || ~ishghandle(ax)
    return
end
try
    if ~strcmpi(get(ax, 'Type'), 'axes')
        return
    end
catch
    return
end
names = {'Title', 'Subtitle', 'XLabel', 'YLabel', 'ZLabel'};
for i = 1:numel(names)
    try
        if isequal(get(ax, names{i}), h)
            tf = true;
            return
        end
    catch
    end
end
end


function tf = is_annotation_axes(ax)
tf = false;
try
    tag = lower(strtrim(char(get(ax, 'Tag'))));
    if strcmp(tag, 'scribeoverlay') || strcmp(tag, 'scribe')
        tf = true;
        return
    end
catch
end
try
    if strcmpi(get(ax, 'Type'), 'annotationpane')
        tf = true;
    end
catch
end
end


function rgb = as_rgb(value)
rgb = [];
if isempty(value)
    return
end
if isnumeric(value)
    value = double(value(:)).';
    if numel(value) < 3 || any(~isfinite(value(1:3)))
        return
    end
    rgb = value(1:3);
    if max(rgb) > 1
        rgb = rgb / 255;
    end
    return
end
if ischar(value) || (isstring(value) && isscalar(value))
    switch lower(strtrim(char(value)))
        case {'k', 'black'}
            rgb = [0 0 0];
        case {'w', 'white'}
            rgb = [1 1 1];
    end
end
end


function value = safe_get(h, name)
value = [];
try
    value = get(h, name);
catch
end
end


function objs = join_kinds(fig, kinds)
objs = [];
for k = 1:numel(kinds)
    found = find_kind(fig, kinds{k});
    if isempty(found)
        continue
    end
    found = found(:);
    if isempty(objs)
        objs = found;
    else
        objs = [objs; found]; %#ok<AGROW>
    end
end
end


function objs = find_kind(fig, kind)
objs = [];
try
    found = findall(fig, 'Type', kind);
catch
    found = [];
end
if isempty(found)
    return
end
objs = found(:);
end


function tf = in_legend(h)
% True for a legend and for every object drawn inside one. The recolor
% walk uses this so legend text, swatches, and the legend font stay put.
% MATLAB legends are Type 'legend'. Octave's are axes tagged 'legend'.
tf = false;
if isempty(h) || ~ishghandle(h)
    return
end
if is_legend_node(h)
    tf = true;
    return
end
try
    leg = ancestor(h, 'legend');
    if ~isempty(leg)
        tf = true;
        return
    end
catch
end
p = h;
for guard = 1:16
    try
        p = get(p, 'Parent');
    catch
        return
    end
    if isempty(p) || ~ishghandle(p)
        return
    end
    if is_legend_node(p)
        tf = true;
        return
    end
    try
        kind = lower(char(get(p, 'Type')));
    catch
        return
    end
    if strcmp(kind, 'figure') || strcmp(kind, 'root')
        return
    end
end
end


function tf = is_legend_node(h)
tf = false;
try
    if strcmpi(get(h, 'Type'), 'legend')
        tf = true;
        return
    end
catch
end
try
    if strcmpi(strtrim(char(get(h, 'Tag'))), 'legend')
        tf = true;
    end
catch
end
end


function ok = try_set(h, varargin)
ok = false;
try
    set(h, varargin{:});
    ok = true;
catch
end
end
