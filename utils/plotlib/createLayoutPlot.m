function Param = createLayoutPlot(Param)
fig = figure('Name','Layout','Position',[100, 100, 1000, 1000]);
tabgp = uitabgroup(fig,'Position',[.05 .05 .9 .9]);


%Find simulation area
buildings = Param.buildings;
area = [min(buildings(:, 1)), min(buildings(:, 2)), max(buildings(:, 3)), ...
	max(buildings(:, 4))];
xc = (area(3) - area(1))/2;
yc = (area(4) - area(2))/2;
maxRadius = max(area(3)/2,area(4)/2);
%Depending on position scenario and radius resize axes to match, otherwise resize to building grid

%Check macro
if Param.macroRadius*Param.numMacro >maxRadius
    maxRadius = Param.macroRadius*Param.numMacro;
end

%Set axes accordingly

%%Setup "normal" plot
overViewTab = uitab(tabgp, 'Title', 'Overview' );
layout_axes = axes('parent', overViewTab);
set(layout_axes,'XLim',[xc-maxRadius-10,xc+maxRadius+10],'YLim',[yc-maxRadius-10,yc+maxRadius+10]); %+/-10 for better looks
set(layout_axes,'XTick',[]);
set(layout_axes,'XTickLabel',[]);
set(layout_axes,'YTick',[]);
set(layout_axes,'YTickLabel',[]);
set(layout_axes,'Box','on');
hold(layout_axes,'on');


%%Setup heatmap of Rx power
RxHeatmapTab = uitab(tabgp, 'Title', 'Heatmap of Rx Power');
layout_axes = axes('parent', RxHeatmapTab);
set(layout_axes,'XLim',[xc-maxRadius-10,xc+maxRadius+10],'YLim',[yc-maxRadius-10,yc+maxRadius+10]); %+/-10 for better looks
set(layout_axes,'XTick',[]);
set(layout_axes,'XTickLabel',[]);
set(layout_axes,'YTick',[]);
set(layout_axes,'YTickLabel',[]);
set(layout_axes,'Box','on');
hold(layout_axes,'on');

%%Setup voronoi map macro layer
voronoiMacroTab = uitab(tabgp, 'Title', 'Voronoi Macro layer');
layout_axes = axes('parent', voronoiMacroTab);
set(layout_axes,'XLim',[xc-maxRadius-10,xc+maxRadius+10],'YLim',[yc-maxRadius-10,yc+maxRadius+10]); %+/-10 for better looks
set(layout_axes,'XTick',[]);
set(layout_axes,'XTickLabel',[]);
set(layout_axes,'YTick',[]);
set(layout_axes,'YTickLabel',[]);
set(layout_axes,'Box','on');
hold(layout_axes,'on');

%%Setup voronoi micro layer
voronoiMicroTab = uitab(tabgp, 'Title', 'Voronoi Micro layer');
layout_axes = axes('parent', voronoiMicroTab);
set(layout_axes,'XLim',[xc-maxRadius-10,xc+maxRadius+10],'YLim',[yc-maxRadius-10,yc+maxRadius+10]); %+/-10 for better looks
set(layout_axes,'XTick',[]);
set(layout_axes,'XTickLabel',[]);
set(layout_axes,'YTick',[]);
set(layout_axes,'YTickLabel',[]);
set(layout_axes,'Box','on');
hold(layout_axes,'on');

%%Setup voronoi pico layer
voronoiPicoTab = uitab(tabgp, 'Title', 'Voronoi Pico layer');
layout_axes = axes('parent', voronoiPicoTab);
set(layout_axes,'XLim',[xc-maxRadius-10,xc+maxRadius+10],'YLim',[yc-maxRadius-10,yc+maxRadius+10]); %+/-10 for better looks
set(layout_axes,'XTick',[]);
set(layout_axes,'XTickLabel',[]);
set(layout_axes,'YTick',[]);
set(layout_axes,'YTickLabel',[]);
set(layout_axes,'Box','on');
hold(layout_axes,'on');

%%UE Association
UEAssociationTab = uitab(tabgp, 'Title', 'UE Association');
layout_axes = axes('parent', UEAssociationTab);
set(layout_axes,'XLim',[xc-maxRadius-10,xc+maxRadius+10],'YLim',[yc-maxRadius-10,yc+maxRadius+10]); %+/-10 for better looks
set(layout_axes,'XTick',[]);
set(layout_axes,'XTickLabel',[]);
set(layout_axes,'YTick',[]);
set(layout_axes,'YTickLabel',[]);
set(layout_axes,'Box','on');
hold(layout_axes,'on');

%%Signal to noise ratio
SNRMacroTab = uitab(tabgp, 'Title', 'SNR Macro Layer');
layout_axes = axes('parent', SNRMacroTab);
set(layout_axes,'XLim',[xc-maxRadius-10,xc+maxRadius+10],'YLim',[yc-maxRadius-10,yc+maxRadius+10]); %+/-10 for better looks
set(layout_axes,'XTick',[]);
set(layout_axes,'XTickLabel',[]);
set(layout_axes,'YTick',[]);
set(layout_axes,'YTickLabel',[]);
set(layout_axes,'Box','on');
hold(layout_axes,'on');

%%Signal to noise ratio
SNRMicroTab = uitab(tabgp, 'Title', 'SNR Micro Layer');
layout_axes = axes('parent', SNRMicroTab);
set(layout_axes,'XLim',[xc-maxRadius-10,xc+maxRadius+10],'YLim',[yc-maxRadius-10,yc+maxRadius+10]); %+/-10 for better looks
set(layout_axes,'XTick',[]);
set(layout_axes,'XTickLabel',[]);
set(layout_axes,'YTick',[]);
set(layout_axes,'YTickLabel',[]);
set(layout_axes,'Box','on');
hold(layout_axes,'on');

%%Signal to noise ratio
SNRPicoTab = uitab(tabgp, 'Title', 'SNR Pico Layer');
layout_axes = axes('parent', SNRPicoTab);
set(layout_axes,'XLim',[xc-maxRadius-10,xc+maxRadius+10],'YLim',[yc-maxRadius-10,yc+maxRadius+10]); %+/-10 for better looks
set(layout_axes,'XTick',[]);
set(layout_axes,'XTickLabel',[]);
set(layout_axes,'YTick',[]);
set(layout_axes,'YTickLabel',[]);
set(layout_axes,'Box','on');
hold(layout_axes,'on');

%% tab test
tabTestTab = uitab(tabgp, 'Title', 'Testtab');
layout_axes = axes('parent', tabTestTab);
set(layout_axes,'XLim',[xc-maxRadius-10,xc+maxRadius+10],'YLim',[yc-maxRadius-10,yc+maxRadius+10]); %+/-10 for better looks
set(layout_axes,'XTick',[]);
set(layout_axes,'XTickLabel',[]);
set(layout_axes,'YTick',[]);
set(layout_axes,'YTickLabel',[]);
set(layout_axes,'Box','on');
hold(layout_axes,'on');

Param.LayoutFigure = fig;
Param.LayoutAxes = findall(fig,'type','axes');
end