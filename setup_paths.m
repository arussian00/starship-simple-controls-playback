function paths = setup_paths()
%SETUP_PATHS  Find matlab-rocket-sim and rocket-controls-simulink, then addpath.
%
%   paths = setup_paths()
%
%   Search order for each repo:
%     1. /MATLAB Drive/Repositories/<name>   (MATLAB Online)
%     2. the sibling of this folder          (a desktop checkout)
%     3. a copy already on the MATLAB path
%   A missing sim repo is cloned with gitclone into the MATLAB Drive
%   repositories folder when that folder exists, otherwise next to this
%   file. The octave/ shims inside matlab-rocket-sim are not added.
%
%   cfg.controlsBranch (main by default) is read from a separate folder
%   named rocket-controls-simulink-<branch>, for example
%   rocket-controls-simulink-main. That folder is a worktree or a clone.
%   An existing rocket-controls-simulink checkout is not checked out,
%   pulled, reset, or otherwise modified, so a step branch with local
%   edits stays as it is. An empty branch keeps the checkout already on
%   disk. This does not use git submodules.

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
[paths.controls, paths.controlsNote] = locate_or_clone(cfg.controlsRepo, ...
    cfg.controlsUrl, cfg.controlsBranch, 'vehicle_params.m', ...
    cfg.driveRoot, sibling, cloneParent);

addpath(paths.sim);
addpath(paths.controls);
addpath(paths.playback);
rehash;
end


function [folder, note] = locate_or_clone(repoName, url, branch, marker, driveRoot, sibling, cloneParent)
note = '';
branch = clean_branch(branch);
existing = find_existing(repoName, marker, driveRoot, sibling);
if isempty(branch)
    if isempty(existing)
        existing = clone_default(url, repoName, cloneParent, marker);
    end
    folder = existing;
    fprintf('setup_paths: %s\n  %s\n', repoName, folder);
    return
end

if clean_on_branch(existing, branch) && head_matches_remote(existing, branch)
    folder = existing;
    fprintf('setup_paths: %s\n  %s\n', repoName, folder);
    fprintf('setup_paths: %s is already a clean %s\n', folder, branch);
    return
end

parent = folder_parent(existing, cloneParent);
if isempty(parent)
    error('setup_paths:NoDestination', ...
        ['Cannot find %s. Clone it into /MATLAB Drive/Repositories ' ...
         '(MATLAB Online) or next to this folder, then run again.\n%s'], ...
        repoName, url);
end
dedicated = fullfile(parent, branch_dirname(repoName, branch));
if folder_ready(dedicated, marker)
    folder = dedicated;
else
    folder = materialize_branch(existing, dedicated, url, branch, marker);
end
fprintf('setup_paths: %s\n  %s\n', repoName, folder);
if ~isempty(existing) && ~strcmp(existing, folder)
    untouched = current_branch(existing);
    fprintf(['setup_paths: left %s on %s\n' ...
        '  (separate folder for %s; that checkout was not modified)\n'], ...
        existing, untouched, branch);
    note = sprintf('left %s on %s', existing, untouched);
end
end


function existing = find_existing(repoName, marker, driveRoot, sibling)
candidates = {fullfile(driveRoot, repoName)};
if ~isempty(sibling)
    candidates{end + 1} = fullfile(sibling, repoName); %#ok<AGROW>
end
existing = first_hit(candidates, marker);
if isempty(existing)
    located = which(marker);
    if ~isempty(located)
        existing = first_hit({fileparts(located)}, marker);
    end
end
end


function folder = materialize_branch(existing, dedicated, url, branch, marker)
if ~isempty(existing) && is_git(existing)
    ref = local_ref(existing, branch);
    if isempty(ref)
        [status, message] = system(sprintf( ...
            'git -C "%s" fetch --depth 1 origin "%s"', existing, branch));
        if status == 0
            ref = 'FETCH_HEAD';
        else
            fprintf('setup_paths: fetch of %s did not update %s (%s)\n', ...
                branch, existing, strtrim(message));
            ref = '';
        end
    end
    if ~isempty(ref) && ~isfolder(dedicated)
        [status, message] = system(sprintf( ...
            'git -C "%s" worktree add --detach "%s" "%s"', ...
            existing, dedicated, ref));
        if status == 0 && folder_ready(dedicated, marker)
            folder = dedicated;
            fprintf('setup_paths: worktree of %s\n  %s\n', branch, folder);
            return
        end
        fprintf('setup_paths: worktree was not used (%s)\n', strtrim(message));
        if isfolder(dedicated) && ~folder_ready(dedicated, marker)
            system(sprintf('git -C "%s" worktree remove --force "%s"', ...
                existing, dedicated));
        end
    end
end
folder = clone_branch(url, dedicated, branch, marker);
end


function folder = clone_default(url, repoName, cloneParent, marker)
if isempty(cloneParent) || ~isfolder(cloneParent)
    error('setup_paths:NoDestination', ...
        ['Cannot find %s. Clone it into /MATLAB Drive/Repositories ' ...
         '(MATLAB Online) or next to this folder, then run again.\n%s'], ...
        repoName, url);
end
folder = fullfile(cloneParent, repoName);
if folder_ready(folder, marker)
    return
end
if isfolder(folder)
    error('setup_paths:BadTree', ...
        '%s exists but does not contain %s.', folder, marker);
end
fprintf('setup_paths: cloning %s\n  into %s\n', url, folder);
do_clone(url, folder, '');
if ~folder_ready(folder, marker)
    error('setup_paths:CloneIncomplete', ...
        'Cloned %s but %s is not there.', folder, marker);
end
end


function folder = clone_branch(url, folder, branch, marker)
if folder_ready(folder, marker)
    return
end
if isfolder(folder)
    error('setup_paths:BadTree', ...
        '%s exists but does not contain %s.', folder, marker);
end
parent = fileparts(folder);
if isempty(parent) || ~isfolder(parent)
    error('setup_paths:NoDestination', ...
        'Cannot create %s for branch %s.', folder, branch);
end
fprintf('setup_paths: cloning %s\n  branch %s into %s\n', url, branch, folder);
do_clone(url, folder, branch);
if ~folder_ready(folder, marker)
    error('setup_paths:CloneIncomplete', ...
        'Cloned %s but %s is not there.', folder, marker);
end
end


function do_clone(url, folder, branch)
if isempty(branch) && exist('gitclone', 'file') == 2
    gitclone(url, folder);
    return
end
if isempty(branch)
    cmd = sprintf('git clone --depth 1 "%s" "%s"', url, folder);
else
    cmd = sprintf('git clone --depth 1 --branch "%s" --single-branch "%s" "%s"', ...
        branch, url, folder);
end
[status, message] = system(cmd);
if status ~= 0 && isempty(branch) && exist('gitclone', 'file') == 2
    gitclone(url, folder);
    return
end
if status ~= 0
    error('setup_paths:Clone', 'git clone failed:\n%s', message);
end
end


function parent = folder_parent(existing, cloneParent)
if ~isempty(existing)
    parent = fileparts(existing);
    if ~isempty(parent) && isfolder(parent)
        return
    end
end
parent = cloneParent;
end


function name = branch_dirname(repoName, branch)
safe = regexprep(branch, '[^A-Za-z0-9._-]', '-');
name = [repoName '-' safe];
end


function branch = clean_branch(branch)
if ~ischar(branch)
    branch = char(branch);
end
branch = strtrim(branch);
if isempty(branch)
    return
end
if isempty(regexp(branch, '^[A-Za-z0-9._/-]+$', 'once'))
    error('setup_paths:Branch', ...
        'Branch "%s" has characters setup_paths will not pass to git.', branch);
end
end


function folder = first_hit(candidates, marker)
folder = '';
for k = 1:numel(candidates)
    hit = candidates{k};
    if folder_ready(hit, marker)
        folder = hit;
        return
    end
end
end


function tf = folder_ready(folder, marker)
tf = ~isempty(folder) && isfolder(folder) && isfile(fullfile(folder, marker));
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


function tf = is_git(folder)
tf = ~isempty(folder) && isfolder(fullfile(folder, '.git'));
end


function name = current_branch(folder)
name = '(not a git checkout)';
if ~is_git(folder)
    return
end
[status, current] = system(sprintf( ...
    'git -C "%s" rev-parse --abbrev-ref HEAD', folder));
if status == 0
    name = strtrim(current);
end
end


function tf = clean_on_branch(folder, branch)
tf = false;
if ~is_git(folder) || ~strcmp(current_branch(folder), branch)
    return
end
[status, dirty] = system(sprintf('git -C "%s" status --porcelain', folder));
tf = status == 0 && isempty(strtrim(dirty));
end


function tf = head_matches_remote(folder, branch)
tf = false;
ref = local_ref(folder, branch);
if isempty(ref)
    tf = true;
    return
end
[statusHead, head] = system(sprintf('git -C "%s" rev-parse HEAD', folder));
[statusRef, tip] = system(sprintf('git -C "%s" rev-parse "%s"', folder, ref));
tf = statusHead == 0 && statusRef == 0 && strcmp(strtrim(head), strtrim(tip));
end


function ref = local_ref(folder, branch)
ref = '';
if ~is_git(folder)
    return
end
candidates = {['origin/' branch], branch};
for k = 1:numel(candidates)
    [status, ~] = system(sprintf( ...
        'git -C "%s" rev-parse --verify --quiet "%s"', folder, candidates{k}));
    if status == 0
        ref = candidates{k};
        return
    end
end
end
