function varargout = playback_theme(action, varargin)
%PLAYBACK_THEME  Colors for the mission-control window.
%
%   T = playback_theme
%   playback_theme('figure', fig)     dark figure, light Theme when present
%   playback_theme('graph', ax)       dark plot area, white labels and ticks
%   playback_theme('overlay', ax)     leave the plot color, white labels
%   playback_theme('reinforce', fig)  put those colors back after a redraw
%
%   The figure chrome and the graph interiors are dark. Line colors, the
%   Earth disk, and the camera scenes are not changed here. Titles, axis
%   labels, tick numbers, panel and tab titles, annotations, and other
%   text are near-white (#F0F0F0). Grid lines stay grey.
%
%   Legends are not part of that pass. Their text, box, edge, and font stay
%   whatever style_legend already set (near-black type, white box). T.text
%   and T.legendBack exist so that styling does not follow the white ink.
%
%   R2025a figure Theme 'light' stops a dark MATLAB Online desktop from
%   restyling the window (and from repainting the legends). The colors
%   below are then set explicitly. Call 'reinforce' after every redraw so
%   a theme repaint cannot put black type back. Reinforce does not call
%   theme() again and does not walk legend objects.

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
    otherwise
        error('playback_theme:Action', 'Unknown action "%s".', char(action));
end
end


function T = theme_struct()
% Figure chrome is a step darker than the graph panels so the panels read
% as separate instruments. T.text is legend ink only.
T.figure = [0.10 0.10 0.12];
T.plot = [0.16 0.16 0.18];
T.text = [0.1 0.1 0.1];
T.inPlot = [240 240 240] / 255; % #F0F0F0
T.grid = [0.62 0.63 0.66];
T.gridAlpha = 0.4;
T.bannerBack = [0.22 0.18 0.16];
T.legendBack = [1 1 1];
T.fontAxes = 10;
T.fontSmall = 9;
T.fontTitle = 11;
T.fontBanner = 13;
T.fontHud = 10;
end


function apply_figure(fig)
T = theme_struct();
% Theme first. A dark desktop theme would repaint legends; 'light' blocks
% that, then the explicit colors paint the dark figure and the white type.
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
try_set(fig, 'Color', T.figure);
try_set(fig, 'DefaultAxesColor', T.plot);
try_set(fig, 'DefaultAxesXColor', T.inPlot);
try_set(fig, 'DefaultAxesYColor', T.inPlot);
try_set(fig, 'DefaultAxesZColor', T.inPlot);
try_set(fig, 'DefaultAxesGridColor', T.grid);
try_set(fig, 'DefaultAxesMinorGridColor', T.grid);
try_set(fig, 'DefaultAxesGridAlpha', T.gridAlpha);
try_set(fig, 'DefaultTextColor', T.inPlot);
try_set(fig, 'DefaultAxesFontSize', T.fontAxes);
try_set(fig, 'DefaultTextFontSize', T.fontSmall);
try_set(fig, 'DefaultUipanelForegroundColor', T.inPlot);
try_set(fig, 'DefaultUipanelBackgroundColor', T.figure);
try_set(fig, 'DefaultUipanelHighlightColor', T.grid);
try_set(fig, 'DefaultUitabForegroundColor', T.inPlot);
try_set(fig, 'DefaultUitabBackgroundColor', T.figure);
try_set(fig, 'DefaultUitabgroupForegroundColor', T.inPlot);
try_set(fig, 'DefaultUitabgroupBackgroundColor', T.figure);
try_set(fig, 'DefaultUicontrolForegroundColor', T.inPlot);
try_set(fig, 'DefaultUicontrolBackgroundColor', T.plot);
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
        % the dark plot underneath. Its tick labels still turn white.
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
% XColor is white. Set the grid afterwards so the axis color does not
% take the grid lines with it.
try_set(ax, 'GridColor', T.grid);
try_set(ax, 'MinorGridColor', T.grid);
try_set(ax, 'GridAlpha', T.gridAlpha);
try_set(ax, 'MinorGridAlpha', T.gridAlpha * 0.6);
try_set(ax, 'GridColorMode', 'manual');
try_set(ax, 'MinorGridColorMode', 'manual');
end


function paint_chrome(ax, T, setFont)
try_set(ax, 'XColor', T.inPlot);
try_set(ax, 'YColor', T.inPlot);
try_set(ax, 'ZColor', T.inPlot);
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
for k = 1:numel(rulers)
    rk = rulers(k);
    try_set(rk, 'Color', T.inPlot);
    lbl = [];
    try
        lbl = get(rk, 'Label');
    catch
    end
    if isempty(lbl) || ~ishghandle(lbl)
        continue
    end
    try_set(lbl, 'Color', T.inPlot);
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
if isempty(h) || ~ishghandle(h)
    return
end
try_set(h, 'Color', T.inPlot);
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
restyle_text(fig, T);
restyle_boxes(fig, T);
restyle_panels(fig, T);
end


function restyle_text(fig, T)
objs = find_kind(fig, 'text');
for i = 1:numel(objs)
    h = objs(i);
    if ~ishghandle(h) || in_legend(h)
        continue
    end
    try_set(h, 'Color', T.inPlot);
end
end


function restyle_boxes(fig, T)
% Textbox annotations carry the banner. Text arrows keep their line color
% and only the string is recolored. Kinds are joined without mixing an
% empty double with a graphics array (that concat errors on MATLAB).
boxes = join_kinds(fig, {'textboxshape', 'textbox'});
for i = 1:numel(boxes)
    h = boxes(i);
    if ~ishghandle(h) || in_legend(h)
        continue
    end
    try_set(h, 'Color', T.inPlot);
    try_set(h, 'BackgroundColor', T.bannerBack);
end
arrows = join_kinds(fig, {'textarrowshape', 'textarrow'});
for i = 1:numel(arrows)
    h = arrows(i);
    if ~ishghandle(h) || in_legend(h)
        continue
    end
    try_set(h, 'TextColor', T.inPlot);
end
% Octave stores a textbox annotation as an hggroup (String, FitBoxToText)
% on a scribe overlay. Bar and contour groups do not have FitBoxToText,
% so their face colors are left alone.
groups = find_kind(fig, 'hggroup');
for i = 1:numel(groups)
    h = groups(i);
    if ~ishghandle(h) || in_legend(h) || ~is_textbox_group(h)
        continue
    end
    try_set(h, 'Color', T.inPlot);
    try_set(h, 'BackgroundColor', T.bannerBack);
end
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


function tf = is_annotation_axes(ax)
% Octave's annotation layer is an axes tagged scribeoverlay. Painting it
% would turn the overlay into a visible set of axes behind the banner.
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


function restyle_panels(fig, T)
% Title ink is ForegroundColor. The body is dark so that ink stays readable.
restyle_fg_bg(fig, 'uipanel', T.inPlot, T.figure);
restyle_fg_bg(fig, 'uitab', T.inPlot, T.figure);
restyle_fg_bg(fig, 'uitabgroup', T.inPlot, T.figure);
restyle_fg_bg(fig, 'uicontrol', T.inPlot, T.plot);
end


function restyle_fg_bg(fig, kind, fg, bg)
objs = find_kind(fig, kind);
for i = 1:numel(objs)
    h = objs(i);
    if ~ishghandle(h) || in_legend(h)
        continue
    end
    try_set(h, 'ForegroundColor', fg);
    try_set(h, 'BackgroundColor', bg);
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
% True for a legend and for every object drawn inside one. The theme walk
% uses this so legend text, swatches, and the legend font are left alone.
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
