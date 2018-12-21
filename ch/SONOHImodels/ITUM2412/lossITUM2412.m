function lossdB = loss3gpp38901(Scenario, d_2d, d_3d, f_c, h_bs, h_ut, h, W, LOS)
	% https://www.itu.int/dms_pub/itu-r/opb/rep/R-REP-M.2412-2017-PDF-E.pdf
	% V1 - implemeted base UMa_A, B model is equal to 3GPP38901
	%
	% by Jakob Thrane, DTU Fotonik, 2018
	%
	% Scenario =
	% RMa_A, RMa_B - Rural macro
	% UMa_A, UMa_B - Urban macro
	% UMi_A, UMi_A - Urban micro
	
	% d_2d = 2d distance in meters
	% d_3d = 3d_distance in meters
	% f_c = carrier frequency in GHz
	% h_bs = height of tx in meters
	% h_ut = height of rx in meters
	% h = average height of buildings
	% W = average width of roads
	% LOS = LOS or not.
	
	c = physconst('LightSpeed');
	
	switch Scenario
		case 'UMa'
			if d_2d <= 18
				g = 0;
			else
				g = (5/4)*(d_2d/100)^3*exp(-d_2d/150);
			end
			
			if h_ut < 13
				h_e = 1;
			else
				h_e = 1/(1+((h_ut-13)^1.5/10)*g);
			end
			h_e_bs = h_bs - h_e;
			h_e_ut = h_ut - h_e;
			d_bp = 4*h_e_bs*h_e_ut*(f_c*10e8)/c;
		case 'UMi'
			h_e = 1;
			h_e_bs = h_bs - h_e;
			h_e_ut = h_ut - h_e;
			d_bp = 4*h_e_bs*h_e_ut*(f_c*10e8)/c;
		case 'RMa'
			d_bp = 4*h_bs*h_ut*(f_c*10e8)/c;
	end
	
	
	%% Scenario RMa
	switch Scenario
		case 'RMa_A'
			error('Not implemented yet.')
		case 'RMa_B'
			lossdB = loss3gpp38901('RMa', d_2d, d_3d, f_c, h_bs, h_ut, h, W, LOS);
		case 'UMa_A'

			if (10 <= d_2d) && (d_2d <= d_bp)
				PL1 = 28 + 22*log10(d_3d)+20*log10(f_c)
				PL_UMa_LOS = PL1;
			elseif (d_bp <= d_2d) && (d_2d <= 5000)
				PL2 = 40*log10(d_3d)+28+20*log10(f_c)-9*log10((d_bp)^2+(h_bs-h_ut)^2);
				PL_UMa_LOS = PL2;
			else 
				error('2D distance not within ranges of [10m, %i m] or [%i m, 5km]',floor(d_bp))
			end

			if LOS

				lossdB = PL_UMa_LOS;

			else

				if (0.5 <= f_c) && (fc <= 6)
					PL_UMa_NLOS = 161.05-7.1*log10(W)+7.5*log10(h)-(24.37-3.7*(h/h_bs)^2)*log10(h_bs)+(43.42-3.1*log10(h_bs))*(log10(d_3d)-3)+20*log10(f_c)-(3.2*(log10(17.625))^2-4.97)-0.6*(h_ut-1.5);
					lossdB = max(PL_UMa_LOS, PL_UMa_NLOS);
				else
					lossdB = max(PL_UMa_LOS, loss3gpp38901('UMa', d_2d, d_3d, f_c, h_bs, h_ut, h, W, LOS));

				end

			end
		case 'UMa_B'
			lossdB = loss3gpp38901('UMa', d_2d, d_3d, f_c, h_bs, h_ut, h, W, LOS)
		case 'UMi_A'
			error('Not implemented yet.')
		case 'UMi_B'
			lossdB = loss3gpp38901('UMi', d_2d, d_3d, f_c, h_bs, h_ut, h, W, LOS)
		otherwise
			error('Scenario not recognized.')	
			
	end
	
	
	end
	
	