function [safety_factors] = trc_design(app, anthro, design_inputs, material_data)
hdpe = material_data("hdpe");

% ANTHROPOMETRY 
user = anthro;

% FORCE PARAMETERS
min_force = design_inputs.external_loads.min_force;
max_force = design_inputs.external_loads.max_force;

% DIMENSIONS

V= 60*10^-3; %m, constant
t= 30*10^-3; %m, constant
s = 40*10^-3; %m, constant

if(user.height>1850)
    velcro_inner_radius = 0.092;
    shell_outer_radius = 0.086; %to be parametrized
    shell_inner_radius = 0.077;
    fin_platform_height = 0.06058823; %to be parametrized
    fin_platform_width = 0.0431509;
else
    velcro_inner_radius = 0.074;
    shell_outer_radius = 0.070; %to be parametrized
    shell_inner_radius = 0.065;
    fin_platform_height = 0.050; %to be parametrized
    fin_platform_width = 0.033265;
end 

log_to_output(app, sprintf("[trc_design] Initializing TRC parametrization: "));
log_to_output(app, sprintf("[trc_design]     shell_outer_radius:    %f8 m", shell_outer_radius));
log_to_output(app, sprintf("[trc_design]     fin_platform_height:   %f8 m", fin_platform_height));

shellLength = user.height/13.07; %m
fin_hole_radius = 0.01; %m 
a = 0.04; %distance from top of sidebar to velcro slot (will not change)
partialSidebarLength = (user.height*1000 * 0.245 - 180)*10^-3; %m
L =partialSidebarLength + shellLength;
fin_platform_extrusion = 60*user.height/1.7; %m "fin_platform_extrusion" 
fin_thickness = 5*user.height/1500;


%PARAMETRIZATION INITIALIZATIONS
count = 0;
cost_lowest = [fin_platform_height, shell_outer_radius, 900000];
SF_best = [-10,-10,-10,-10,-10,-10, -10,-10];

while count<50
  
    % deflection/pressure on wearer SF -> divide/multiply sidebar length 
    
    max_deflection = L*tan(7/180*pi);
    
    I_x_x = t*(shell_outer_radius -shell_inner_radius)^3/12; %not counter balanced with thigh bar breaking 
    
    deflection_force = 6*max_deflection*hdpe.modulus*I_x_x/(a^2*(3*L-a)); %N, not the same result as working analysis, even with same Ixx used
    velcro_area = 0.055*pi*velcro_inner_radius;%m^2
    deflection_pressure = deflection_force/velcro_area; %N/m^2


    max_pressure = 20532; %N/m^2
    SF_pressure = max_pressure/deflection_pressure;

    %bending stress on thigh bar
    thigh_bar_area = t*(shell_outer_radius -shell_inner_radius);
    bending_stress = deflection_force/thigh_bar_area;
    SF_bending = hdpe.yield/bending_stress;


    % fatigue SF -> divide/multiply fin radii
    
    K_f = 2.5; %assumed constant since small variation in outer-inner radius
    fin_base_area = fin_thickness*fin_platform_height; %m^2
    stress_max = K_f*max_force.spring_force*sin(max_force.cable_thigh_right_angle)/(fin_base_area); %N/m^2
    stress_min = K_f*min_force.spring_force*sin(min_force.cable_thigh_right_angle)/(fin_base_area); %N/m^2
    
    SF_cyclical = fatigue([stress_min, stress_max], hdpe, true);
    
    current_SF = [SF_pressure, SF_bending, SF_cyclical];

    current_dimensions = [shell_outer_radius, fin_thickness];


   if SF_pressure <2.5
       pressure_cost = 1000*(2.5-SF_pressure);
   else
       pressure_cost = (SF_pressure-2.5);
   end
   if SF_bending <2.5
       bending_cost = 1000*(2.5-SF_bending);
   else
       bending_cost = (SF_bending-2.5);
   end

   if pressure_cost > bending_cost
       if SF_pressure < 2.5
            shell_outer_radius = shell_outer_radius*0.98;
       else
            shell_outer_radius = shell_outer_radius*1.02;
       end
   else
        if SF_bending < 2.5
            shell_outer_radius = shell_outer_radius*1.02;
       else
            shell_outer_radius = shell_outer_radius*0.98;
        end
   end
   

    if SF_cyclical <2.5
       cyclical_cost = 1000*(2.5-SF_cyclical);
       fin_thickness = fin_thickness*1.02;
    else
       cyclical_cost = (SF_cyclical-2.5);
       fin_thickness = fin_thickness*0.98;
    end

   cost = pressure_cost + bending_cost + cyclical_cost;
       
    if cost<cost_lowest(1,3)
        cost_lowest = [fin_thickness, shell_outer_radius,cost]; %store dimensions which give lowest cost
        SF_best = current_SF;
    end 

    count = count + 1;
end

cost_lowest;
safety_factors = struct(...
        'skin_pressure_SF', SF_best(:,1), ...
        'bending_SF', SF_best(:,2), ...
        'fin_cylical_SF', SF_best(:,3));

% WRITE DIMENSIONS IN TEXT FILE
fileID = fopen('C:\MCG4322B\MCG4322B\code\trc\thighcuff_dimensions.txt','w');
formatSpec = ['"userHeight" = %3.1f \n "shellLength" = %3.1f \n ' ...
    '"partialSidebarLength" = %3.1f \n "fin_platform_extrusion" = %3.1f \n '];
fprintf(fileID,formatSpec,user.height,shellLength, partialSidebarLength, fin_platform_extrusion);

fileID = fopen('C:\MCG4322B\MCG4322B\code\trc\thighFin_dimensions.txt','w');
formatSpec = ['"userHeight" = %3.1f \n "fin_thickness" = %3.1f \n ' ...
    '"fin_platform_width" = %3.1f \n "fin_platform_height" = %3.1f \n  "fin_platform_extrusion" = %3.1f \n '];
fprintf(fileID,formatSpec,user.height,fin_thickness, fin_platform_width, fin_platform_height, fin_platform_extrusion);

fileID = fopen('C:\MCG4322B\MCG4322B\code\trc\velcroStrap_dimensions.txt','w');
formatSpec = '"userHeight" = %3.1f \n ';
fprintf(fileID,formatSpec,user.height);

log_to_output(app, sprintf("[trc_design] TRC parametrization complete."));
log_to_output(app, sprintf("[trc_design] Final values: "));
log_to_output(app, sprintf("[trc_design]     shell_outer_radius:    %f8 m", shell_outer_radius));
log_to_output(app, sprintf("[trc_design]     fin_platform_height:   %f8 m", fin_platform_height));
log_to_output(app, sprintf("[trc_design] Final safety factors: "));
log_to_output(app, sprintf("[trc_design]     skin_pressure_SF:  %f2", safety_factors.skin_pressure_SF));
log_to_output(app, sprintf("[trc_design]     bending_SF: %f2", safety_factors.bending_SF));
log_to_output(app, sprintf("[trc_design]     fin_cylical_SF: %f2", safety_factors.fin_cylical_SF));
log_to_output(app, sprintf("[trc_design] TRC design completed successfully in %d iterations.", count));
log_to_output(app, sprintf("[trc_design] Equations exported to: 'C:/MCG4322b/Group4/code/trc/trc_output.txt'"));
end 
