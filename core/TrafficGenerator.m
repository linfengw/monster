%   TrafficGenerator defines a value class for the core network

classdef TrafficGenerator
	%   TrafficGenerator 
	properties
		TrafficModel;
		Source;	
		Position;
	end
	
	methods
		% Constructor
		function obj = TrafficGenerator(Param)
			obj.TrafficModel = Param.trafficModel;
			obj.Position = Param.trafficServerPosition;
			switch Param.trafficModel
				case 'videoStreaming'
					if (exist('traffic/videoStreaming.mat', 'file') ~= 2 || Param.reset)
						obj = loadVideoStreamingTraffic(obj, 'traffic/videoStreaming.csv', true);
					else
						traffic = load('traffic/videoStreaming.mat');
						obj.Source = traffic.trSource;
						clear traffic
					end
				case 'fullBuffer'
					if (exist('traffic/fullBuffer.mat', 'file') ~= 2 || Param.reset)
						obj = loadFullBufferTraffic(obj, 'traffic/fullBuffer.csv');
					else
						traffic = load('traffic/fullBuffer.mat');
						obj.Source = traffic.trSource;
						clear traffic
					end
			end
			% Add to plot if the parameters are on
			if Param.draw
				x = obj.Position(1);
				y = obj.Position(2);
				text(x,y-6,strcat('Traffic Generator (',num2str(round(x)),', ', num2str(round(y)),')'),'HorizontalAlignment','center','FontSize',9);
				rectangle('Position',[x-5 y-5 10 10],'EdgeColor', [0 0 0],'FaceColor',[0 0 0]);
			end
		end

		% Load video streaming data
		function obj = loadVideoStreamingTraffic(obj, path, sort)
			formatSpec = '%*s%s%*s%*s%*s%s%*s%*s%*s%*s%*s%*s%*s%s%[^\n\r]';
  		fileID = fopen(path,'r');
			dataArray = textscan(fileID, formatSpec, 'Delimiter', ',',  'ReturnOnError', false);
			fclose(fileID) ;
			raw = repmat({''},length(dataArray{1})-1,length(dataArray)-1);
			for col=1:length(dataArray)-1
				raw(1:length(dataArray{col}),col) = dataArray{col};
			end
			numericData = NaN(size(dataArray{1},1),size(dataArray,2));
			for col=[2,3]
				rawData = dataArray{col};
				for row=1:size(rawData, 1);
					regexstr = '(?<prefix>.*?)(?<numbers>([-]*(\d+[\,]*)+[\.]{0,1}\d*[eEdD]{0,1}[-+]*\d*[i]{0,1})|([-]*(\d+[\,]*)*[\.]{1,1}\d+[eEdD]{0,1}[-+]*\d*[i]{0,1}))(?<suffix>.*)';
					try
						result = regexp(rawData{row}, regexstr, 'names');
						numbers = result.numbers;
						invalidThousandsSeparator = false;
						if any(numbers==',');
							thousandsRegExp = '^\d+?(\,\d{3})*\.{0,1}\d*$';
							if isempty(regexp(numbers, thousandsRegExp, 'once'));
								numbers = NaN;
								invalidThousandsSeparator = true;
							end
						end
						if ~invalidThousandsSeparator;
							numbers = textscan(strrep(numbers, ',', ''), '%f');
							numericData(row, col) = numbers{1};
							raw{row, col} = numbers{1};
						end
					catch me
					end
				end
			end
			rawNumericColumns = raw(:, [2,3]);
			rawNumericColumns(1,:) = [];
			rawNumericColumns(length(rawNumericColumns), :) = [];
			R = cellfun(@(x) ~isnumeric(x) && ~islogical(x),rawNumericColumns);
			rawNumericColumns(R) = {NaN};
			data.time = cell2mat(rawNumericColumns(:, 1));
			data.size = cell2mat(rawNumericColumns(:, 2));
			dataCell = struct2cell(data);
			dataSize = size(dataCell);
			dataCell = reshape(dataCell, dataSize(1), []);
			trSource = cell2mat(dataCell');
			if (sort);
				trSource = sortrows(trSource, 1);
			end

			obj.Source = trSource;
			% Save to MAT file to avoid loading next time
			save('traffic/videoStreaming.mat', 'trSource');

		end

		% Load full buffer data
		function obj = loadFullBufferTraffic(obj, path)
			delimiter = ',';
			startRow = 2;
			endRow = inf;
			formatSpec = '%f%f%[^\n\r]';
			fileID = fopen(path,'r','n','UTF-8');
			fseek(fileID, 3, 'bof');
			dataArray = textscan(fileID, formatSpec, endRow(1)-startRow(1)+1, 'Delimiter', delimiter, 'TextType', 'string', 'EmptyValue', NaN, 'HeaderLines', startRow(1)-1, 'ReturnOnError', false, 'EndOfLine', '\r\n');
			for block=2:length(startRow)
				frewind(fileID);
				dataArrayBlock = textscan(fileID, formatSpec, endRow(block)-startRow(block)+1, 'Delimiter', delimiter, 'TextType', 'string', 'EmptyValue', NaN, 'HeaderLines', startRow(block)-1, 'ReturnOnError', false, 'EndOfLine', '\r\n');
				for col=1:length(dataArray)
					dataArray{col} = [dataArray{col};dataArrayBlock{col}];
				end
			end
			fclose(fileID);
			trSource(1:length(dataArray{1}),1) = dataArray{1};
			trSource(1:length(dataArray{2}),2) = dataArray{2};

			obj.Source = trSource;
			% Save to MAT file to avoid loading next time
			save('traffic/fullBuffer.mat', 'trSource');
		end





				
	end
	
end
