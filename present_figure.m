function varargout = present_figure(action, varargin)
%PRESENT_FIGURE  One full-size playback window, reused on the next run.
%
%   fig = present_figure('obtain', name)
%   present_figure('arm', fig)         remember layout, scale fonts on resize
%   present_figure('raise', fig)       drawnow, then maximized or docked again
%   present_figure('closeothers')      close every figure except this one
%   present_figure('reflow', fig)      SizeChangedFcn / ResizeFcn callback
%
%   cfg.figureMode in playback_config is 'maximized' (default) or 'docked'.
%   WindowState, WindowStyle, and SizeChangedFcn are applied when this
%   MATLAB has them. Octave keeps the normalized OuterPosition fallback.

switch lower(strtrim(char(action)))
    case 'obtain'
        varargout{1} = obtain_figure(varargin{:});
    case 'arm'
        arm_figure(varargin{:});
    case 'raise'
        raise_figure(varargin{:});
    case 'closeothers'
        close_others();
    case 'reflow'
        reflow_figure(varargin{:});
    otherwise
        error('present_figure:Action', 'Unknown action "%s".', char(action));
end
end


function fig = obtain_figure(name, tag)
if nargin < 2 || isempty(tag)
    tag = playback_figure_tag();
end
name = char(name);
mode = playback_figure_mode();
fig = find_tagged(tag);
if isempty(fig)
    fig = figure('Name', name, 'Tag', tag, 'NumberTitle', 'off', ...
        'Color', 'w', 'Visible', 'on');
else
    safe_set(fig, 'SizeChangedFcn', '');
    safe_set(fig, 'ResizeFcn', '');
    figure(fig);
    clf(fig);
    safe_set(fig, 'Name', name, 'Tag', tag, 'NumberTitle', 'off', ...
        'Color', 'w', 'Visible', 'on');
    setappdata(fig, 'PlaybackReflowing', false);
end
playback_theme('figure', fig);
apply_mode(fig, mode);
drawnow;
apply_mode(fig, mode);
end


function arm_figure(fig)
if ~is_figure(fig)
    return
end
remember_layout(fig);
install_reflow(fig);
reflow_figure(fig);
end


function raise_figure(fig)
if ~is_figure(fig)
    return
end
drawnow;
apply_mode(fig, playback_figure_mode());
end


function close_others(tag)
if nargin < 1 || isempty(tag)
    tag = playback_figure_tag();
end
figs = all_figures();
for k = 1:numel(figs)
    fig = figs(k);
    if ~is_figure(fig)
        continue
    end
    if strcmp(figure_tag(fig), tag)
        continue
    end
    try
        close(fig);
    catch
    end
end
end


function reflow_figure(src, varargin)
fig = ancestor_figure(src);
if ~is_figure(fig)
    return
end
if isappdata(fig, 'PlaybackReflowing') && getappdata(fig, 'PlaybackReflowing')
    return
end
setappdata(fig, 'PlaybackReflowing', true);
try
    scale = font_scale(figure_pixels(fig));
    scale_fonts(fig, scale);
    restore_positions(fig);
    playback_theme('reinforce', fig);
catch
end
if is_figure(fig)
    setappdata(fig, 'PlaybackReflowing', false);
end
end


function apply_mode(fig, mode)
% OuterPosition [0 0 1 1] fills the figure container. WindowState maximized
% is what fills the MATLAB Online browser; it is set again after drawnow
% because the first request is often ignored until the window exists.
% Docked is optional (cfg.figureMode). Properties this host lacks are skipped.
if strcmp(mode, 'docked') && safe_set(fig, 'WindowStyle', 'docked')
    return
end
safe_set(fig, 'WindowStyle', 'normal');
safe_set(fig, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);
safe_set(fig, 'WindowState', 'maximized');
end


function install_reflow(fig)
if ~safe_set(fig, 'SizeChangedFcn', @reflow_entry)
    safe_set(fig, 'ResizeFcn', @reflow_entry);
end
end


function reflow_entry(varargin)
if isempty(varargin)
    return
end
reflow_figure(varargin{1});
end


function remember_layout(fig)
axs = findall(fig, 'Type', 'axes');
for i = 1:numel(axs)
    ax = axs(i);
    if ~ishghandle(ax)
        continue
    end
    safe_set(ax, 'Units', 'normalized');
    try
        setappdata(ax, 'PlaybackPos', get(ax, 'Position'));
    catch
    end
end
objs = font_objects(fig);
for i = 1:numel(objs)
    obj = objs(i);
    if ~ishghandle(obj) || isappdata(obj, 'PlaybackFont')
        continue
    end
    try
        setappdata(obj, 'PlaybackFont', get(obj, 'FontSize'));
    catch
    end
end
end


function scale_fonts(fig, scale)
objs = font_objects(fig);
for i = 1:numel(objs)
    obj = objs(i);
    if ~ishghandle(obj)
        continue
    end
    base = [];
    if isappdata(obj, 'PlaybackFont')
        base = getappdata(obj, 'PlaybackFont');
    end
    if isempty(base)
        try
            base = get(obj, 'FontSize');
            setappdata(obj, 'PlaybackFont', base);
        catch
            continue
        end
    end
    safe_set(obj, 'FontSize', max(7, base * scale));
end
end


function restore_positions(fig)
axs = findall(fig, 'Type', 'axes');
for i = 1:numel(axs)
    ax = axs(i);
    if ~ishghandle(ax) || ~isappdata(ax, 'PlaybackPos')
        continue
    end
    pos = getappdata(ax, 'PlaybackPos');
    if numel(pos) ~= 4
        continue
    end
    safe_set(ax, 'Units', 'normalized', 'Position', pos);
end
end


function objs = font_objects(fig)
objs = [];
try
    found = findall(fig, '-property', 'FontSize');
catch
    found = [];
end
if ~isempty(found)
    objs = found(:);
    return
end
types = {'axes', 'text', 'legend', 'colorbar'};
for k = 1:numel(types)
    try
        found = findall(fig, 'Type', types{k});
    catch
        found = [];
    end
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


function px = figure_pixels(fig)
px = [1500 860];
old = '';
try
    old = get(fig, 'Units');
catch
end
try
    set(fig, 'Units', 'pixels');
    pos = get(fig, 'Position');
    px = pos(3:4);
catch
end
if ~isempty(old)
    try
        set(fig, 'Units', old);
    catch
    end
end
end


function scale = font_scale(px)
% 1500 x 860 is the size the panel titles were written for. Below that,
% type shrinks so a four-column title does not cross into the next panel.
scale = 1;
if numel(px) < 2 || any(~isfinite(px)) || any(px <= 0)
    return
end
scale = min(px(1) / 1500, px(2) / 860);
if scale < 0.55
    scale = 0.55;
elseif scale > 1.15
    scale = 1.15;
end
end


function fig = find_tagged(tag)
fig = [];
figs = all_figures();
for k = 1:numel(figs)
    if ~is_figure(figs(k))
        continue
    end
    if strcmp(figure_tag(figs(k)), tag)
        fig = figs(k);
        return
    end
end
end


function figs = all_figures()
try
    figs = findall(0, 'Type', 'figure');
catch
    figs = [];
end
figs = figs(:);
end


function tag = figure_tag(fig)
tag = '';
try
    tag = char(get(fig, 'Tag'));
catch
end
end


function fig = ancestor_figure(src)
fig = [];
if ~ishghandle(src)
    return
end
try
    if strcmp(get(src, 'Type'), 'figure')
        fig = src;
        return
    end
catch
end
try
    fig = ancestor(src, 'figure');
catch
    fig = [];
end
end


function tf = is_figure(fig)
tf = ~isempty(fig) && ishghandle(fig);
if ~tf
    return
end
try
    tf = strcmp(get(fig, 'Type'), 'figure');
catch
    tf = false;
end
end


function ok = safe_set(h, varargin)
ok = false;
try
    set(h, varargin{:});
    ok = true;
catch
end
end


function tag = playback_figure_tag()
tag = 'starshipPlayback';
cfg = read_config();
if isfield(cfg, 'figureTag') && ~isempty(cfg.figureTag)
    tag = char(cfg.figureTag);
end
end


function mode = playback_figure_mode()
mode = 'maximized';
cfg = read_config();
if isfield(cfg, 'figureMode') && ~isempty(cfg.figureMode)
    mode = lower(strtrim(char(cfg.figureMode)));
end
if ~any(strcmp(mode, {'maximized', 'docked'}))
    mode = 'maximized';
end
end


function cfg = read_config()
cfg = struct();
try
    cfg = playback_config();
catch
end
end
