close all;
clear all;
addpath '../../../../../utilities/matlab/'

name = {'australopithecus','habilis','erectus','neandertalis','sapiens'};

% load data
P = cell(1,5);
E = cell(1,5);
for s = 1:5
	[P{s},E{s}] = VTKPolyDataReader(['data/skull_' name{s} '.vtk']);
end

% load the initial model we provide as input of the atlas construction method	
[InitTemplatePts,InitTemplateEdges] = VTKPolyDataReader('data/template.vtk');

pos = [3 4 1 2 6];
figure;
for s=1:5
	subplot(2,3,pos(s));
	hold on
	for k=1:size(E{s},1)
		plot(P{s}(E{s}(k,:),1),P{s}(E{s}(k,:),2),'-r','LineWidth',3);
	end
	title(name{s});
	axis([-150 100 -100 120]);
end
subplot(2,3,5)
hold on
for k=1:size(InitTemplateEdges,1)
	plot(InitTemplatePts(InitTemplateEdges(k,:),1),InitTemplatePts(InitTemplateEdges(k,:),2),'-b','LineWidth',3);
end
axis([-150 100 -100 120]);
title('Initial template model');
set(gcf,'OuterPosition',[-1500 1200 1500 1000]);
