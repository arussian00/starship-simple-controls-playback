function cfg = playback_config()
%PLAYBACK_CONFIG  Where the two source repos live, and which ref to read.
%
%   cfg.controlsBranch defaults to main, where pitch-controller steps 1-2
%   are merged. setup_paths reads that ref from a separate folder
%   (rocket-controls-simulink-main). It does not checkout, pull, or reset
%   a rocket-controls-simulink folder that is already on disk, so a step
%   branch with local edits to vehicle_params.m is left alone.
%
%   Point controlsBranch at another ref to try it the same way:
%       cfg.controlsBranch = 'cursor/maxq-load-relief-bd91';
%   That uses rocket-controls-simulink-cursor-maxq-load-relief-bd91.
%
%   cfg.simBranch empty means "use the matlab-rocket-sim checkout already
%   on disk". setup_paths never commits or pushes either source repo.

cfg.simRepo = 'matlab-rocket-sim';
cfg.controlsRepo = 'rocket-controls-simulink';
cfg.simUrl = 'https://github.com/arussian00/matlab-rocket-sim.git';
cfg.controlsUrl = 'https://github.com/arussian00/rocket-controls-simulink.git';
cfg.simBranch = '';
cfg.controlsBranch = 'main';
cfg.driveRoot = '/MATLAB Drive/Repositories';
end
