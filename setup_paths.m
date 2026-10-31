function paths = setup_paths()
%SETUP_PATHS  Find matlab-rocket-sim and rocket-controls-simulink, then addpath.
%
%   paths = setup_paths()
%
%   Search order for each repo:
%     1. /MATLAB Drive/Repositories/<name>   (MATLAB Online)
%     2. the sibling of this folder          (a desktop checkout)
%     3. a copy already on the MATLAB path
%   If the folder is missing, it is cloned with gitclone into the MATLAB
%   Drive repositories folder when that folder exists, otherwise next to
%   this file (when that directory is writable). A non-empty branch in
%   playback_config is then checked out.
%
%   This does not use git submodules and does not modify either source repo
%   beyond that optional checkout. The octave/ shims inside matlab-rocket-sim
%   are not added to the path.

cfg = playback_config();
here = fileparts(mfilename('fullpath'));
sibling = fileparts(here);
if isempty(sibling) || strcmp(sibling, '/') || strcmp(sibling, filesep)
    % Repo sits at the filesystem root. Do not clone next to it.
    sibling = '';
end

if isfolder(cfg.driveRoot)
    cloneParent = cfg.driveRoot;
elseif ~isempty(sibling) && can_write(sibling)
    cloneParent = sibling;
else
    cloneParent = '';
end

paths.playback = here;
paths.sim = locate_or_clone(cfg.simRepo, cfg.simUrl, cfg.simBranch, ...
    'rocket_params.m', cfg.driveRoot, sibling, cloneParent);
paths.controls = locate_or_clone(cfg.controlsRepo, cfg.controlsUrl, ...
    cfg.controlsBranch, 'vehicle_params.m', cfg.driveRoot, sibling, cloneParent);

addpath(paths.playback);
addpath(paths.sim);
addpath(paths.controls);
end


function folder = locate_or_clone(repoName, url, branch, marker, driveRoot, sibling, cloneParent)
candidates = {fullfile(driveRoot, repoName)};
if ~isempty(sibling)
    candidates{end + 1} = fullfile(sibling, repoName); %#ok<AGROW>
end
folder = first_hit(candidates, marker);
if isempty(folder)
    located = which(marker);
    if ~isempty(located)
        folder = first_hit({fileparts(located)}, marker);
    end
end
if isempty(folder)
    if isempty(cloneParent) || ~isfolder(cloneParent)
        error('setup_paths:NoDestination', ...
            ['Cannot find %s. Clone it into /MATLAB Drive/Repositories ' ...
             '(MATLAB Online) or next to this folder, then run again.\n%s'], ...
            repoName, url);
    end
    folder = fullfile(cloneParent, repoName);
    if isfolder(folder)
        error('setup_paths:BadTree', ...
            '%s exists but does not contain %s.', folder, marker);
    end
    fprintf('setup_paths: cloning %s\n  into %s\n', url, folder);
    do_clone(url, folder);
    if ~isfile(fullfile(folder, marker))
        error('setup_paths:CloneIncomplete', ...
            'Cloned %s but %s is not there.', folder, marker);
    end
end
ensure_branch(folder, branch);
fprintf('setup_paths: %s\n  %s\n', repoName, folder);
end


function folder = first_hit(candidates, marker)
folder = '';
for k = 1:numel(candidates)
    hit = candidates{k};
    if isfolder(hit) && isfile(fullfile(hit, marker))
        folder = hit;
        return
    end
end
end


function tf = can_write(folder)
probe = fullfile(folder, '.playback_write_probe');
fid = fopen(probe, 'w');
if fid < 0
    tf = false;
    return
end
fclose(fid);
delete(probe);
tf = true;
end


function do_clone(url, folder)
if exist('gitclone', 'file') == 2
    gitclone(url, folder);
    return
end
cmd = sprintf('git clone --depth 1 "%s" "%s"', url, folder);
[status, message] = system(cmd);
if status ~= 0
    error('setup_paths:Clone', 'git clone failed:\n%s', message);
end
end


function ensure_branch(folder, branch)
branch = strtrim(char(branch));
if isempty(branch)
    return
end
[status, current] = system(sprintf('git -C "%s" rev-parse --abbrev-ref HEAD', folder));
if status == 0 && strcmp(strtrim(current), branch)
    fprintf('setup_paths: %s already on %s\n', folder, branch);
    return
end
cmd = sprintf(['git -C "%s" fetch --depth 1 origin "%s" ' ...
    '&& git -C "%s" checkout "%s"'], folder, branch, folder, branch);
[status, message] = system(cmd);
if status ~= 0
    error('setup_paths:Branch', ...
        'Could not check out "%s" in %s.\n%s', branch, folder, message);
end
fprintf('setup_paths: checked out %s\n  %s\n', branch, folder);
end
