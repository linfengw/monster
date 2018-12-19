classdef MonsterChannel < handle


	properties
		Mode;
		Region;
		BuildingFootprints;
		ChannelModel;
		enableFading;
		enableInterference;
		enableShadowing;
	end

	methods 
		function obj = MonsterChannel(Stations, Users, Param)
			obj.Mode = Param.channel.mode;
			obj.Region = Param.channel.region;
			obj.enableFading = Param.channel.enableFading;
			obj.enableInterference = Param.channel.enableInterference;
			obj.enableShadowing = Param.channel.enableShadowing;
			obj.BuildingFootprints = Param.buildings;
			obj.setupChannel(Stations)
		end
		
		function setupChannel(obj, Stations, Users)
			switch obj.Mode
				case '3GPP38901'
					obj.ChannelModel = Monster3GPP38901(obj, Stations);
				case 'Quadriga'
					obj.setupQuadrigaLayout(Stations, Users)
			end
		end

		function traverse(obj, Stations, Users, Mode)
			% This function manipulates the waveform of the Tx module of either stations, or users depending on the selected mode
			% E.g. `Mode='uplink'` uses the Tx modules of the Users, and hereof waveforms, transmission power etc.
			% `Mode='downlink'` uses the Tx modules of the Stations, and hereof configurations. 
			% 
			% This function can only be used if the Stations have assigned users.
			if ~strcmp(Mode,'downlink') && ~strcmp(Mode,'uplink')
				sonohilog('Unknown channel type selected.','ERR', 'MonsterChannel:noChannelMode')
			end

			if any(~isa(Stations, 'EvolvedNodeB'))
				sonohilog('Unknown type of stations.','ERR', 'MonsterChannel:WrongStationClass')
			end

			if any(~isa(Users, 'UserEquipment'))
				sonohilog('Unknown type of users.','ERR', 'MonsterChannel:WrongUserClass')
			end

			% Filter stations and users
			[stations,users] = obj.getAssociated(Stations,Users);
			
			% Propagate waveforms
			if ~isempty(stations)
				obj.callChannelModel(Stations, Users, Mode)
			else
				sonohilog('No users found for any of the stations. Quitting traverse', 'ERR', 'MonsterChannel:NoUsersAssigned')
			end

		end

		function callChannelModel(obj, Stations, Users, Mode)
			if isa(obj.ChannelModel, 'Monster3GPP38901')
				obj.ChannelModel.propagateWaveforms(Stations, Users, Mode)
			end

		end

		

		%%%%%%%%%%%%%%%%%%%%%%%%%%%
		%%%%% Quardiga model %%%%%%
		%%%%%%%%%%%%%%%%%%%%%%%%%%%
		function setupQuadrigaLayout(obj, Stations, Users)
			% Call Quadriga setup function
		end

	end

	methods(Static)
		
		
		
		function distance = getDistance(txPos,rxPos)
			% Get distance between txPos and rxPos
			distance = norm(rxPos-txPos);
		end
		
		
		function [stations, users] = getAssociated(Stations,Users)
			% Returns stations and users that are associated
			stations = [];
			for istation = 1:length(Stations)
				UsersAssociated = [Stations(istation).Users.UeId];
				UsersAssociated = UsersAssociated(UsersAssociated ~= -1);
				if ~isempty(UsersAssociated)
					stations = [stations, Stations(istation)];
				end
			end
			
			
			UsersAssociated = [Stations.Users];
			UserIds = [UsersAssociated.UeId];
			UserIds = unique(UserIds);
			UserIds = UserIds(UserIds ~= -1);
			users = Users(ismember([Users.NCellID],UserIds));
			
		end

		function Pairing = getPairing(Stations)
			% Output: [Nlinks x 2] sized vector with pairings
			% where Nlinks is equal to the total number of scheduled users
			% for Input Stations.
			% E.g. Pairing(1,:) = All station ID's
			% E.g. Pairing(2,:) = All user ID's
			% and Pairing(1,1) = Describes the pairing of Station and User
					
			% Get number of links associated with the station.
			
			nlink=1;
			for i = 1:length(Stations)
				schedule = [Stations(i).Users];
				users = extractUniqueIds([schedule.UeId]);
				for ii = 1:length(users)
					Pairing(:,nlink) = [Stations(i).NCellID; users(ii)]; %#ok
					nlink = nlink+1;
				end
			end
			
		end
		
	end





end