%Plot voronoi tab for each BST type
function voronoiplots(Param, networkLayout)

    %Macro
    if Param.numMacro >2
        voronoi(Param.LayoutAxes(3),networkLayout.MacroCoordinates(:,1),networkLayout.MacroCoordinates(:,2));
        [v,c] = voronoin(networkLayout.MacroCoordinates);
        for i =1:length(c)
            if all(c{i}~=1)
                patch(Param.LayoutAxes(3),v(c{i},1),v(c{i},2),i,'FaceAlpha',.25);
            end
        end	
    end

    %Micro
    if Param.numMicro >2
        voronoi(Param.LayoutAxes(4),networkLayout.MicroCoordinates(:,1),networkLayout.MicroCoordinates(:,2));
        [v,c] = voronoin(networkLayout.MicroCoordinates);
        for i =1:length(c)
            if all(c{i}~=1)
                patch(Param.LayoutAxes(4),v(c{i},1),v(c{i},2),i,'FaceAlpha',.25);
            end
        end
    end
    %pico
    if Param.numPico >2
        voronoi(Param.LayoutAxes(5),networkLayout.PicoCoordinates(:,1),networkLayout.PicoCoordinates(:,2));
        [v,c] = voronoin(networkLayout.PicoCoordinates);
        for i =1:length(c)
            if all(c{i}~=1)
                patch(Param.LayoutAxes(5),v(c{i},1),v(c{i},2),i,'FaceAlpha',.25);
            end
        end
    end

end 