function cfg = playback_config()
%PLAYBACK_CONFIG  Where the two source repos live, and which branch to use.
%
%   Edit the branch fields to try a controls feature before it is merged.
%   Leave a branch empty to keep the checkout that is already on disk
%   (a fresh clone stays on the default branch, which is main).
%
%   Example, once you want max-q load relief before it reaches main:
%       cfg.controlsBranch = 'cursor/maxq-load-relief-bd91';
%
%   setup_paths never commits, pushes, or otherwise edits those repos.

cfg.simRepo = 'matlab-rocket-sim';
cfg.controlsRepo = 'rocket-controls-simulink';
cfg.simUrl = 'https://github.com/arussian00/matlab-rocket-sim.git';
cfg.controlsUrl = 'https://github.com/arussian00/rocket-controls-simulink.git';
cfg.simBranch = '';
cfg.controlsBranch = '';
cfg.driveRoot = '/MATLAB Drive/Repositories';
end
