function distFig(varargin)
% ===== Syntax ============================================================
%
% distFig(...,'Screen',Value)
% distFig(...,'Position',Value)
% 
% distFig(...,'Rows',Value)
% distFig(...,'Columns',Value)
% 
% distFig(...,'Not',Value)
% distFig(...,'Only',Value)
% distFig(...,'Offset',Value)
% 
% distFig(...,'AspectRatio',Value)
% distFig(...,'Extra',Value)
% distFig(...,'Menu',Value)
% distFig(...,'Transpose',Value)
% distFig(...,'Simulink',Value)
% distFig(...,'Tight',Value)
%
% ===== Description =======================================================
%
% distFig(...,'Screen',Value) assigns where the figures will be
% distributed. 
% Synonums for 'Screen' are 'Scr', 'S'. Value can be:
% 'Left' / 'L'
% 'Right' / 'R'
% 'Center' / 'C' (Default)
%
% distFig(...,'Position',Value) assigns in which part of the screen the
% figures will be distributed.
% Synonums for 'Position' are 'Pos', 'P'. Value can be:
% 'W' / 'West' / 'Left' / 'L'
% 'E' / 'East' / 'Right' / 'R'
% 'N' / 'North'
% 'S' / 'South'
% 'Center' / 'C' (Default)
% Positions can be combined to limit the area of distributing. For
% instance: 'WW' only distributes in the left quarter, whereas 'EW'
% distributes in the eastern part, but only in the west of this area.
%
% distFig(...,'Rows',Value) assigns how many rows the figures will be
% distributed on.
% Synonums for 'Rows' are 'R'. Value can be:
% 1...n
% 'Auto' / -1
% 'Auto' indicates that it automatically calculates the number of required
% rows.
% 
% distFig(...,'Columns',Value) assigns how many rows the figures will be
% distributed on.
% Synonums for 'Columns' are 'Column', 'Cols' or 'Col'. Value can be:
% 1...n
% 'Auto' / -1
% 'Auto' indicates that it automatically calculates the number of required
% columns.
%
% distFig(...,'Not',Value) excludes specified figures from the distribution
% list. Value must be an array with the excluded figure numbers. The
% default value is [].
%
% distFig(...,'Only',Value) does only distrubute specified figures. Value
% must be an array with the figure which will be destributed. The
% default value is [].
%
% distFig(...,'Offset',Value) can be used to shift all figures on the
% distribution list. Value must be an integer larger or equal to zero. The
% default offset value is 0.
% 
% distFig(...,'AspectRatio',Value) is used if both 'Columns' and 'Rows' are
% set to 'auto'. The function then tries to get all figures to match a
% reference value for the aspect ratio (Width / Height). The default value
% is 1.1228, which is the aspect ratio of a default matlab figure.
% 
% distFig(...,'Extra',Value) is used to handle the extra figures, which
% might not fit into 'Rows' * 'Cols'. For instance, 5 figure are to be
% distributed on a 2x2 = 4 area. The fifth figure is then places on top of
% the first figure if 'Extra' is 'restart'. It can be ignored by setting
% 'Extra' to 'ignore'.
% 
% distFig(...,'Menu',Value) can be used to remove the menu bare from all
% distributed figures by setting value to 'none'. It is usefull if many
% figures are to be distributed. 
% 
% distFig(...,'Transpose',Value) can be used to tranpose the order of
% distributing. The default value is false.
% 
% distFig(...,'Simulink',Value) can be used to handle simulink figures.
% Value can be:
% true (default)
% false / 'not'
% 'only'
% If value is true, simulink figures will be distributed along with the
% other figures. If value if false or 'not' simulink figures will be
% ignored. If value is 'only', only the simulink figures will be
% distributed and not the ordinary figures. 
% 
% distFig(...,'Tight',Value) can be used to stretch the figure to the 
% border of the figure, so no unnecessary "whitespace" is present.
%
% ===== Examples ==========================================================
%
% distFig();
% This will distribute all open figures on the primary screen in two rows.
%
% distFig('Screen','Left','Position','East','Only',[1,2,4])
% This will only distrubute figure 1, 2 and 4 on the right part of the left
% screen.
%
% distFig('Offset',2,'Not',[1,2])
% This will distribute all figure but figure 1 and 2 in the same pattern as
% distFig(), but figure 1 and 2 will not be distributed, but instead there will
% be blank spots where they would have been distributed.

% =========================================================================
% =========================================================================
% =========================================================================

% Anders Schou Simonsen, AndersSSimonsen@GMail.com
% Version 4.0
% 19/08-2014

% =========================================================================
% ===== Default values ====================================================
% =========================================================================

Scr = 'Center';			% {'Center'}
Pos = 'Center';			% {'Center'}

Rows = 'auto';			% {-1/'auto'}
Cols = 'auto';			% {-1/'auto'}

AR = 1.1228;			% {1.1228} (Width / Height)
Extra = 'Restart';		% {'Restart'} or 'Ignore'
Menu = 'figure';		% {'figure'} or 'none'
Transpose = false;		% {false} or true
Taskbar_Height = 40;	% {40}
Offset = 0;				% {0}
Not = [];				% {[]}
Only = [];				% {[]}
Simulink = true;		% {true} or false/'not' or 'only'
Tight = false;			% {false} or true

% =========================================================================
% ===== Get inputs ========================================================
% =========================================================================

if (mod(nargin,2) ~= 0)
	error('Uneven number of inputs! Returning...');
	return;
end

for i = 1:2:nargin
	switch lower(varargin{i})
		case {'scr','screen','s'}
			Scr = varargin{i+1};
		case {'pos','position','p'}
			Pos = varargin{i+1};
		case {'rows','row','r'}
			Rows = varargin{i+1};
		case {'cols','col','columns','column','c'}
			Cols = varargin{i+1};
		case {'ar','aspectratio'}
			AR = varargin{i+1};
		case {'ext','extra','e'}
			Extra = varargin{i+1};
		case {'menu','bar'}
			Menu = varargin{i+1};
		case {'transpose','t'}
			Transpose = varargin{i+1};
		case {'offset'}
			Offset = varargin{i+1};
		case {'not'}
			Not = varargin{i+1};
		case {'only'}
			Only = varargin{i+1};
		case {'simu','simulink'}
			Simulink = varargin{i+1};
		case {'tight'}
			Tight = varargin{i+1};
		otherwise
			fprintf('Input ''%s'' not recognized!\n',varargin{i});
	end
end

if (strcmpi(Rows,'auto'))
	Rows = -1;
end
if (strcmpi(Cols,'auto'))
	Cols = -1;
end

% =========================================================================
% ===== Generate figure list ==============================================
% =========================================================================

% ===== Get figure list ===================================================
Figs = findall(0,'type','figure');
if (~isempty(strfind(version,'R2014b')))
	Figs = sort(arrayfun(@(n) (Figs(n).Number),1:numel(Figs)));
end
if (isempty(Figs))
	fprintf('No figures to distribute...\n');
	return;
end

% ===== Simulink figures ==================================================
if ((~ischar(Simulink)) && ((Simulink == false) || (Simulink == 0))) || ((ischar(Simulink)) && (strcmpi(Simulink,'not')))
	Tag = get(Figs,'Tag');
	Trigger = arrayfun(@(n) (isempty(Tag{n})),1:numel(Tag));
	Figs = Figs(Trigger);
end
if ((ischar(Simulink)) && (strcmpi(Simulink,'only')))
	Tag = get(Figs,'Tag');
	Trigger = arrayfun(@(n) (isempty(Tag{n})),1:numel(Tag));
	Figs = Figs(~Trigger);
end

% ===== Not ===============================================================
Figs(ismember(Figs,Not)) = [];

% ===== Only ==============================================================
if (~isempty(Only))
	Figs(~ismember(Figs,Only)) = [];
end

% ===== Offset ============================================================
if ~((Cols == (-1)) && (Rows == (-1)))
	Figs = [-ones(Offset,1);Figs];
end

% ===== Monitor ===========================================================
Monitor = get(0,'MonitorPositions');

% =========================================================================
% ===== Calculate sizes and positions =====================================
% =========================================================================

% ===== Active screen size and position ===================================
switch upper(Scr)
	case {'L','LEFT','W','WEST'}
		Mon_Index = find(Monitor(:,1) == min(Monitor(:,1)));
	case {'R','RIGHT','E','EAST'}
		Mon_Index = find(Monitor(:,1) == max(Monitor(:,1)));
	otherwise % {'C','CENTER',''}
		Mon_Index = find(Monitor(:,1) == 1);
end

if (~isempty(strfind(version,'R2014b')))
	Size = Monitor(Mon_Index,3:4) + 1 - [0,Taskbar_Height];
	Orig = Monitor(Mon_Index,1:2) + [0,Taskbar_Height - 5];
else
	Main_Native = get(0,'screensize');
	Size = [diff(Monitor(Mon_Index,[1,3])')',diff(Monitor(Mon_Index,[2,4])')'] + 1 - [0,Taskbar_Height];
	Orig = Monitor(Mon_Index,1:2) .* [1,-1] + [0,Taskbar_Height - Main_Native(2) - 1];
	if (Mon_Index ~= 1)
		Orig = Orig + [0,diff(Monitor(:,2)) - diff(Monitor(:,4))];
	end
end

% ===== Grid ==============================================================
switch upper(Pos)
	case {'N','NORTH'}
		Sub.Size = Size ./ [1,2];
		Sub.Orig = Size .* [0,0.5];
	case {'NN','NORTHNORTH'}
		Sub.Size = Size ./ [1,4];
		Sub.Orig = Size .* [0,0.75];
	case {'NS','NORTHSOUTH'}
		Sub.Size = Size ./ [1,4];
		Sub.Orig = Size .* [0,0.5];
	case {'S','SOUTH'}
		Sub.Size = Size ./ [1,2];
		Sub.Orig = Size .* [0,0];
	case {'SS','SOUTHSOUTH'}
		Sub.Size = Size ./ [1,4];
		Sub.Orig = Size .* [0,0];
	case {'SN','SOUTHNORTH'}
		Sub.Size = Size ./ [1,4];
		Sub.Orig = Size .* [0,0.25];
	case {'E','EAST','R','RIGHT'}
		Sub.Size = Size ./ [2,1];
		Sub.Orig = Size .* [0.5,0];
	case {'EE','EASTEAST'}
		Sub.Size = Size ./ [4,1];
		Sub.Orig = Size .* [0.75,0];
	case {'EW','EASTWEST'}
		Sub.Size = Size ./ [4,1];
		Sub.Orig = Size .* [0.5,0];
	case {'W','WEST','L','LEFT'}
		Sub.Size = Size ./ [2,1];
		Sub.Orig = Size .* [0,0];
	case {'WW','WESTWEST'}
		Sub.Size = Size ./ [4,1];
		Sub.Orig = Size .* [0,0];
	case {'WE','WESTEAST'}
		Sub.Size = Size ./ [4,1];
		Sub.Orig = Size .* [0.25,0];
	case {'NE','EN','NORTHEAST','EASTNORTH'}
		Sub.Size = Size ./ [2,2];
		Sub.Orig = Size .* [0.5,0.5];
	case {'SE','ES','SOUTHEAST','EASTSOUTH'}
		Sub.Size = Size ./ [2,2];
		Sub.Orig = Size .* [0.5,0];
	case {'SW','WS','SOUTHWEST','WESTSOUTH'}
		Sub.Size = Size ./ [2,2];
		Sub.Orig = Size .* [0,0];
	case {'NW','WN','NORTHWEST','WESTNORTH'}
		Sub.Size = Size ./ [2,2];
		Sub.Orig = Size .* [0,0.5];
	otherwise
		Sub.Size = Size ./ [1,1];
		Sub.Orig = Size .* [0,0];
end
Sub.Orig = Sub.Orig + Orig;

% =========================================================================
% ===== Calculate figure sizes ============================================
% =========================================================================

n_Figs = sum(Figs ~= (-1));
if ((Cols == (-1)) && (Rows == (-1)))
	AR_Temp = zeros(50,1);
	for i = 1:50
		Rows = i;
		Cols = ceil(n_Figs / Rows);
		Size_Temp = Sub.Size ./ [Cols,Rows];
		AR_Temp(i) = Size_Temp(1) / Size_Temp(2);
	end
	Rows = find(abs(AR_Temp - AR) == min(abs(AR_Temp - AR)),1,'first');
	Cols = ceil(n_Figs / Rows);
elseif (Cols == (-1))
	Cols = ceil(n_Figs / Rows);
elseif (Rows == (-1))
	Rows = ceil(n_Figs / Cols);
end

Fig.Size = Sub.Size ./ [Cols,Rows];

% =========================================================================
% ===== Distribute figures ================================================
% =========================================================================

% ===== Transpose =========================================================
if (Transpose)
	II = 1:Cols;
	JJ = 1:Rows;
else
	II = 1:Rows;
	JJ = 1:Cols;
end

% ===== Extra figures =====================================================
if (~strcmpi(Extra,'Restart'))
	Iter = 1;
else
	Iter = ceil(numel(Figs) / (Rows * Cols));
end

% ===== Calculate positions ===============================================
n = 0;
Position = nan(numel(Figs),4);
i = zeros(1,1);
j = zeros(1,1);
for k = 1:Iter
	for I = II
		i(Transpose) = I;
		j(~Transpose) = I;
		for J = JJ
			i(~Transpose) = J;
			j(Transpose) = J;
			
			n = n + 1;
			if (n <= numel(Figs))
				if (Figs(n) ~= (-1))
					Pos_Temp = [...
						(i - 1) * Fig.Size(1) + Sub.Orig(1)...
						(Sub.Orig(2) + Sub.Size(2) + 4) - (j * Fig.Size(2))...
						Fig.Size(1)...
						Fig.Size(2)...
						];
					Position(n,:) = Pos_Temp;
				end
			end
		end
	end
end

% ===== Distribute figures ================================================
for n = 1:size(Position,1)
	if (~isnan(Position(n,1)))
		set(figure(Figs(n)),'MenuBar',Menu);
		Units_Prev = get(gcf,'Units');
		set(figure(Figs(n)),'Units','pixels','OuterPosition',Position(n,:));
		set(figure(Figs(n)),'Units',Units_Prev);
		if (Tight)
			drawnow;
			set(gca,'Position',[get(gca,'TightInset') * eye(4,2),1 - get(gca,'TightInset') * [1,0,1,0;0,1,0,1]']);
		end
	end
end