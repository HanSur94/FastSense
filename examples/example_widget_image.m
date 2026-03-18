%% ImageWidget — All Configurations Demo
% Demonstrates ImageWidget with procedurally generated images (no external
% files required), caption text, and the stretch scaling mode.
%
% ImageWidget Properties:
%   ImageFcn  — function_handle returning an image matrix:
%                 MxN      — grayscale (intensity values as uint8 or double)
%                 MxNx3    — RGB (uint8 [0,255] or double [0,1])
%               Polled on refresh; no external file dependency.
%   File      — path to image file (PNG, JPG); existence validated at render.
%   Caption   — string displayed below the image.
%   Scaling   — 'fit' (default), 'fill', or 'stretch'.
%   Title     — widget title.
%   Position  — [col row width height] on the 24-column grid.
%
% Usage:
%   example_widget_image

close all force;
clear functions;
projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'install.m'));

%% 1. Build images procedurally (no imread / no file I/O)

% --- Topographic surface — peaks(64) → grayscale uint8 ---
Z = peaks(64);
Z = Z - min(Z(:));
Z = Z ./ max(Z(:));
peaksImg = uint8(round(Z * 255));  % 64x64 grayscale

% --- False-colour thermal map — sin/cos gradient → RGB ---
[X, Y] = meshgrid(linspace(0, 2*pi, 128), linspace(0, 2*pi, 128));
R = uint8(round((0.5 + 0.5*sin(X))   * 255));
G = uint8(round((0.5 + 0.5*cos(Y))   * 255));
B = uint8(round((0.5 + 0.5*sin(X+Y)) * 255));
thermalImg = cat(3, R, G, B);  % 128x128x3 RGB

% --- Checkerboard calibration pattern ---
sz = 128; sqSize = 16;
nSq = sz / sqSize;
tileRow = repmat([0 1], 1, ceil(nSq/2));
tileRow = tileRow(1:nSq);
tileCol = tileRow;
block = xor(repmat(tileRow, nSq, 1), repmat(tileCol(:), 1, nSq));
checkerImg = uint8(kron(block, ones(sqSize, sqSize)) * 255);  % 128x128

%% 2. Build dashboard
d = DashboardEngine('Image Widget Demo');
d.Theme = 'light';

% Row 1-8: Topographic surface (grayscale), caption visible
d.addWidget('image', 'Title', 'Terrain Elevation Map', ...
    'Position', [1 1 8 8], ...
    'ImageFcn', @() peaksImg, ...
    'Caption', 'Generated from peaks(64)', ...
    'Scaling', 'fit');

% Row 1-8: False-colour thermal map (RGB), no caption
d.addWidget('image', 'Title', 'False-Colour Thermal Map', ...
    'Position', [9 1 8 8], ...
    'ImageFcn', @() thermalImg, ...
    'Scaling', 'fit');

% Row 1-8: Checkerboard — tests pixel rendering, stretch scaling
d.addWidget('image', 'Title', 'Calibration Pattern', ...
    'Position', [17 1 8 8], ...
    'ImageFcn', @() checkerImg, ...
    'Caption', '128x128, 16-px squares', ...
    'Scaling', 'stretch');

%% 3. Render
d.render();
fprintf('Dashboard rendered with %d image widgets.\n', numel(d.Widgets));
fprintf('Images: grayscale %dx%d, RGB %dx%dx3, grayscale %dx%d (checker)\n', ...
    size(peaksImg, 1), size(peaksImg, 2), ...
    size(thermalImg, 1), size(thermalImg, 2), size(thermalImg, 3), ...
    size(checkerImg, 1), size(checkerImg, 2));
fprintf('All images generated procedurally — no external files required.\n');
