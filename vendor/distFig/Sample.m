clc;
clear;
close all;

% ===== Generate figures ==================================================
for i = 1:14
	figure('Color','w');
	text(0,0,num2str(i),'HorizontalAlignment','Center','FontSize',50);
	xlim([-1,1]);
	ylim([-1,1]);
	axis off;
end

% ===== Colors ============================================================
set(1,'Color',[1,0.6,0.6])
set(2:4,'Color',[0.6,0.9,0.6])
set(5:6,'Color',[0.7,0.7,1])
set(7:14,'Color',[1,0.8,0.5])

% ===== Distribute figures ================================================
distFig('Pos','NW' , 'Only',1);
distFig('Pos','SW' , 'Only',[2,3,4] , 'Cols', 3);
distFig('Pos','NE' , 'Rows',2		, 'Only', [5,6]);
distFig('Pos','SE' , 'Cols',4		, 'Not',  (1:6));