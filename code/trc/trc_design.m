function [safety_factors] = trc_design(anthro, design_inputs, material_data)
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

shellLength = user.height/13.07; %m
partialSidebarLength = (user.height*1000 * 0.245 - 180)*10^-3; %m
shell_outer_radius = user.height/20;
shell_inner_radius = user.height/22;
fin_platform_extrusion = 60*user.height/1700;

velcro_inner_radius = user.height/20;

fin_hole_radius = 0.01; %m 
fin_thickness = 5*user.height/1500;
fin_platform_width = 2*user.height/20*sin(18/180*pi)-0.01
fin_platform_height = (70.58-60)/(2000-1700)*user.height - 0.01
platform_height_width = fin_platform_height/fin_platform_width;


a = 0.04; %distance from top of sidebar to velcro slot (will not change)

L =partialSidebarLength + shellLength;



%PARAMETRIZATION INITIALIZATIONS
count = 0;
cost_lowest = [fin_thickness, fin_platform_height, fin_platform_width, shell_outer_radius, 900000];
SF_best = [-10,-10,-10,-10,-10,-10, -10,-10];

while count<100
  
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

    current_specs = struct(...
        'SF_skin_pressure', SF_pressure, ...
        'SF_bending', SF_bending, ...
        'SF_fin_cyclical', SF_cyclical, ...
        'shell_outer_radius', shell_outer_radius, ...
        'fin_platform_width', fin_platform_width, ...
        'fin_platform_height', fin_platform_height, ...
        'fin_thickness', fin_thickness)


   if SF_pressure <2.5
       pressure_cost = 200*(2.5-SF_pressure);
   else
       pressure_cost = (SF_pressure-2.5);
   end
   if SF_bending <2.5
       bending_cost = 200*(2.5-SF_bending);
   else
       bending_cost = (SF_bending-2.5);
   end

   if SF_pressure < 2.5 || SF_bending <2.5
            shell_outer_radius = shell_outer_radius*0.98;
            if shell_outer_radius < shell_inner_radius + 0.003
                shell_outer_radius = shell_inner_radius + 0.003;
            end
   else
            shell_outer_radius = shell_outer_radius*1.02;
   end

    if SF_cyclical <2.5
       cyclical_cost = 1000*(2.5-SF_cyclical);
       fin_thickness = fin_thickness*1.02;
    else
       cyclical_cost = (SF_cyclical-2.5);
       fin_thickness = fin_thickness*0.98;
       if fin_thickness < 0.003
           fin_thickness = 0.003; % limited for manufacturing purposes
       end 
       fin_platform_height =fin_platform_height*0.98;
       if fin_platform_height < 0.0375
           fin_platform_height = 0.0375;
       end 
       fin_platform_width = fin_platform_height/platform_height_width;
    end

   cost = pressure_cost + bending_cost + cyclical_cost;
       
    if cost<cost_lowest(1,5)
        cost_lowest = [fin_thickness, fin_platform_height, fin_platform_width, shell_outer_radius,cost]; %store dimensions which give lowest cost
        SF_best = current_SF;
    end 

    count = count + 1;
end

fin_thickness = cost_lowest(:,1);
fin_platform_height = cost_lowest(:,2);
fin_platform_width = cost_lowest(:,3);
shell_outer_radius = cost_lowest(:,4);


safety_factors = struct(...
        'skin_pressure_SF', SF_best(:,1), ...
        'bending_SF', SF_best(:,2), ...
        'fin_cylical_SF', SF_best(:,3), ...
        'fin_thickness', fin_thickness, ...
        'fin_platform_width', fin_platform_width, ...
        'fin_platform_height', fin_platform_height, ...
        'shell_outer_radius', shell_outer_radius);

% WRITE DIMENSIONS IN TEXT FILE
fileID = fopen('C:\MCG4322B\MCG4322B\code\trc\thighcuff_dimensions.txt','w');
formatSpec = ['"userHeight" = %3.1f \n "shellLength" = %3.1f \n ' ...
    '"partialSidebarLength" = %3.1f \n "shell_outer_radius" = %3.1f \n' ...
    '"shell_inner_radius" = %3.1f \n' '"fin_platform_extrusion" = %3.1f \n'];
fprintf(fileID,formatSpec,user.height*1000,shellLength*1000, partialSidebarLength*1000, ...
    shell_outer_radius*1000, shell_inner_radius*1000, fin_platform_extrusion*1000);

fileID = fopen('C:\MCG4322B\MCG4322B\code\trc\thighFin_dimensions.txt','w');
formatSpec = ['"userHeight" = %3.1f \n "fin_hole_radius" = %3.1f \n "fin_thickness" = %3.1f \n ' ...
    '"fin_platform_width" = %3.1f \n "fin_platform_height" = %3.1f \n '];
fprintf(fileID,formatSpec,user.height*1000,fin_hole_radius*1000, fin_thickness*1000,  fin_platform_width*1000, fin_platform_height*1000);

fileID = fopen('C:\MCG4322B\MCG4322B\code\trc\velcroStrap_dimensions.txt','w');
formatSpec = '"userHeight" = %3.1f \n "velcro_inner_radius" = %3.1f \n ';
fprintf(fileID,formatSpec,user.height*1000, velcro_inner_radius*1000);
end 