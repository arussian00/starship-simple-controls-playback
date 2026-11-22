function varargout = playback_theme(action, varargin)
%PLAYBACK_THEME  Colors for the mission-control window.
%
%   T = playback_theme
%   playback_theme('figure', fig)     white figure, light Theme when present
%   playback_theme('graph', ax)       dark plot area, black labels and ticks
%   playback_theme('overlay', ax)     leave the plot color, black labels
%   playback_theme('reinforce', fig)  put the same colors back after a resize
%
%   The figure background is white. Graph interiors stay dark. Line colors,
%   the Earth disk, and the camera scenes are not changed here. Text that
%   sits on the white figure (titles, axis labels, ticks, legends) is
%   near-black. Text drawn inside a dark plot stays light.
%
%   R2025a figure Theme 'light' stops a dark MATLAB Online desktop from
%   repainting this window. Older releases get the same colors explicitly.

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
T.figure = [1 1 1];
T.plot = [0.16 0.16 0.18];
T.text = [0.1 0.1 0.1];
T.inPlot = [0.94 0.95 0.96];
T.grid = [0.62 0.63 0.66];
T.gridAlpha = 0.4;
T.bannerBack = [1 0.96 0.93];
T.legendBack = [1 1 1];
T.fontAxes = 10;
T.fontSmall = 9;
T.fontTitle = 11;
T.fontBanner = 13;
T.fontHud = 10;
end


function apply_figure(fig)
T = theme_struct();
try_set(fig, 'Color', T.figure);
if ~try_set(fig, 'Theme', 'light')
    try
        theme(fig, 'light');
    catch
    end
end
try_set(fig, 'Color', T.figure);
try_set(fig, 'DefaultAxesXColor', T.text);
try_set(fig, 'DefaultAxesYColor', T.text);
try_set(fig, 'DefaultAxesZColor', T.text);
try_set(fig, 'DefaultTextColor', T.text);
try_set(fig, 'DefaultAxesFontSize', T.fontAxes);
try_set(fig, 'DefaultTextFontSize', T.fontSmall);
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
        % the dark plot underneath. Its tick labels still turn black.
        paint_chrome(partner, T, true);
    end
end
paint_chrome(ax, T, true);
end


function paint_plot(ax, T)
try_set(ax, 'Color', T.plot);
try_set(ax, 'GridColor', T.grid);
try_set(ax, 'MinorGridColor', T.grid);
try_set(ax, 'GridAlpha', T.gridAlpha);
try_set(ax, 'MinorGridAlpha', T.gridAlpha * 0.6);
try_set(ax, 'Box', 'on');
try_set(ax, 'TickDir', 'out');
end


function paint_chrome(ax, T, setFont)
try_set(ax, 'XColor', T.text);
try_set(ax, 'YColor', T.text);
try_set(ax, 'ZColor', T.text);
if setFont
    try_set(ax, 'FontSize', T.fontAxes);
end
try
    yy = get(ax, 'YAxis');
    for k = 1:numel(yy)
        try_set(yy(k), 'Color', T.text);
    end
catch
end
paint_label(ax, 'Title', T, setFont);
paint_label(ax, 'XLabel', T, setFont);
paint_label(ax, 'YLabel', T, setFont);
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
try_set(h, 'Color', T.text);
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
try_set(fig, 'Color', T.figure);
try
    axs = findall(fig, 'Type', 'axes');
catch
    axs = [];
end
for i = 1:numel(axs)
    ax = axs(i);
    if ~ishghandle(ax)
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
    paint_chrome(ax, T, false);
end
try
    legs = findall(fig, 'Type', 'legend');
catch
    legs = [];
end
for i = 1:numel(legs)
    leg = legs(i);
    if ~ishghandle(leg)
        continue
    end
    try_set(leg, 'TextColor', T.text);
    try_set(leg, 'Color', T.legendBack);
    try_set(leg, 'EdgeColor', T.text);
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
