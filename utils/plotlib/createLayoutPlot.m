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
%Depending on position scenario and radius resize axes to that or resize to building grid
%Check macro
if Param.macroRadius >maxRadius
    maxRadius = Param.macroRadius;
end
%Check micro
if (strcmp(Param.microPos,'uniform')  && Param.microUniformRadius > maxRadius)
    maxRadius = Param.microUniformRadius;
end
%If hexagonal
if (strcmp(Param.microPos,'hexagonal')  && (Param.macroRadius*3/2 > maxRadius && Param.numMicro > 6 ))
    maxRadius = Param.macroRadius*3/2;
end
%Check pico
if (strcmp(Param.picoPos,'uniform') && Param.picoUniformRadius > maxRadius)
    maxRadius = Param.picoUniformRadius;
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

%% tab test
voronoiTab = uitab(tabgp, 'Title', 'Voronoi plot');
layout_axes = axes('parent', voronoiTab);
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