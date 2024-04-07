
function [safety_factors] = la_design(anthro, design_inputs, material_data)

al1100 = material_data("al1100");
al6061 = material_data("al6061");

% Anthropometry
user = anthro;
user.L_thigh = (0.53-0.285)*user.height; %m
user.stride_length = -2.234 + 0.106*user.age - 0.0008*user.age^2; % m 

% pulley specs
weight_pulley = 0.11189; %N


% CONSTANT DIMENSIONS
    waist_cuff_thickness = 0.01;%m, variable? 
    LA_pulley_center = 0.008;%m
    length_dowel_bolt = 0.03; %m, distance from end of dowel pin to centroid of screws
    length_pin = 0.03; %length of dowel pin
    hip_cuff_distance = 7/8*user.L_thigh; %m
    waist_hip_length = 0.1*user.height;
    LA_length = 1/4*user.stride_length - user.waist_radius - length_pin - waist_cuff_thickness;

    
% INITIAL CONDITIONS
    h = 0.0188; 
    b = 0.013;
    ratio_b_h = b/h;
    diameter_bolt = 0.003; %M3 bolt
    radius_pin = b/2; 
    cost_lowest = [b, h,radius_pin, 900000];
    SF_best = [-10,-10,-10,-10,-10,-10, -10,-10];
    count = 0;

%Pulley reaction forces
spring_min_force = design_inputs.external_loads.min_force.spring_force;
spring_min_force_angle = design_inputs.external_loads.min_force.thigh_LA_right_angle;
spring_max_force = design_inputs.external_loads.max_force.spring_force;
spring_max_force_angle = design_inputs.external_loads.max_force.thigh_LA_right_angle;

[angle_max_force_pulley, force_max_pulley_y, force_max_pulley_x] = find_pulley_force(spring_max_force_angle,spring_max_force, waist_hip_length, hip_cuff_distance, user.stride_length, weight_pulley);
[angle_min_force_pulley, force_min_pulley_y, force_min_pulley_x] = find_pulley_force(spring_min_force_angle,spring_min_force, waist_hip_length, hip_cuff_distance, user.stride_length, weight_pulley);

SF = struct(...
        'SF_static_bending_pin', 0, ...
        'SF_static_bending_LA', 0, ...
        'SF_cyclical_bending_pin', 0, ...
        'SF_cyclical_bending_LA', 0, ...
        'SF_static_axial_pin', 0, ...
        'SF_static_axial_LA', 0, ...
        'SF_cyclical_axial_pin', 0, ...
        'SF_cyclical_axial_LA', 0);

while count<100
  
    radius_pin = b/2; %new addition
    area_cross_section_LA = b*h;
    moment_of_inertia_LA = b*h^3/12;
      
    LA_volume = LA_length*area_cross_section_LA;
    pin_volume = pi*radius_pin^2*length_pin;
    
    LA_mass = (LA_volume + pin_volume)*al6061.density;
    LA_center_of_mass = (length_pin/2)*(radius_pin*2*length_pin) + (length_pin + LA_length/2)*(LA_length*h);
    
    
    % Deflection 
    a_bending = length_pin/2 + length_dowel_bolt; 
    L_bending = LA_length + LA_pulley_center + length_pin/2; 
    b_bending = L_bending - a_bending;
    
    deflection_max = force_max_pulley_y*b_bending^2*L_bending/(3*al1100.modulus*moment_of_inertia_LA);
    
    % STRESSES
    
    % bending stress
    force_max_bending= force_max_pulley_y;
    force_min_bending = force_min_pulley_y;
    
    bending_max_moment_pin = force_max_bending*b_bending/(a_bending)*0.015;
    stress_max_bending_pin = 2.8*32*bending_max_moment_pin/(pi*(2*radius_pin)^3); % 2.8 is theoretical stress concentrion at fillet (connection btwn pin + LA)
    
    bending_max_moment_LA = force_max_bending*b_bending;
    stress_max_bending_LA = 2.1*6*bending_max_moment_LA/((h-diameter_bolt)*b^2); % max stress at bolt hole (rect section) from bending
    
    bending_min_moment_pin = force_min_bending*(LA_length-length_dowel_bolt)/(length_pin/2 + length_dowel_bolt);
    stress_min_bending_pin = 2.8*32*bending_min_moment_pin/(pi*(2*radius_pin)^3); % 2.8 is theoretical stress concentrion at fillet (connection btwn pin + LA)
    
    bending_min_moment_LA = force_min_bending*b_bending;
    stress_min_bending_LA = 2.1*6*bending_min_moment_LA/((h-diameter_bolt)*b^2); % max stress at bolt hole (rect section) from bending
    
    SF.SF_static_bending_pin = al6061.yield/stress_max_bending_pin;
    SF.SF_static_bending_LA = al6061.yield/stress_max_bending_LA;
    
    SF.SF_cyclical_bending_pin = fatigue([stress_min_bending_pin, stress_max_bending_pin], al6061, false);
    SF.SF_cyclical_bending_LA = fatigue([stress_min_bending_LA, stress_max_bending_LA], al6061, false);
    
    % axial stress
    force_max_axial = force_max_pulley_x;
    force_min_axial = force_min_pulley_x;
    
    stress_max_axial_pin = force_max_axial/(area_cross_section_LA)*2.5; %max concentration at fillet
    stress_max_axial_LA = force_max_axial/((h-diameter_bolt)*b)*3.25; %max concentration at bolt hole
    
    stress_min_axial_pin = force_min_axial/(area_cross_section_LA)*2.5; %min loading at max stress location
    stress_min_axial_LA = force_min_axial/((h-diameter_bolt)*b)*3.25; %min loading at max stress location
    
    SF.SF_static_axial_pin = al6061.yield/stress_max_axial_pin; 
    SF.SF_static_axial_LA = al6061.yield/stress_max_axial_LA;
    
    SF.SF_cyclical_axial_pin = fatigue([stress_min_axial_pin, stress_max_axial_pin], al6061, true); 
    SF.SF_cyclical_axial_LA = fatigue([stress_min_axial_LA, stress_max_axial_LA], al6061, true);
    
    SF  ;  
    SF_list = [SF.SF_static_bending_pin, SF.SF_static_bending_LA, SF.SF_cyclical_bending_pin, SF.SF_cyclical_bending_LA, SF.SF_static_axial_pin, SF.SF_static_axial_LA, SF.SF_cyclical_axial_pin, SF.SF_cyclical_axial_LA];
    dimensions = [h,b, radius_pin];

        current_specs = struct(...
        'SF_static_bending_pin', SF.SF_static_bending_pin, ...
        'SF_static_bending_LA', SF.SF_static_bending_LA, ...
        'SF_cyclical_bending_pin', SF.SF_cyclical_bending_pin, ...
        'SF_cyclical_bending_LA', SF.SF_cyclical_bending_LA, ...
        'height', h, ...
        'width', b, ...
        'radius_pin', radius_pin)
    increase = 0;
    cost = 0;
    for S_F = SF_list
        if S_F < 2.5
            increase = 1;
            cost = cost+200*(2.5-S_F); %large cost for SF under 2.5
        else 
            cost = cost+ (S_F-2.5); %small cost for SF exceeding 2.5
        end
    end
    cost
    cost_lowest(1,4)

    if cost<cost_lowest(1,4)
        cost_lowest = [b,h,radius_pin, cost]; %store dimensions which give lowest cost
        SF_best = SF_list;
    end 

   if increase == 1
       b=b*1.02;
       h = h/ratio_b_h;
    else
       b=b*0.98;
       if b < 0.013
            b = 0.013;
       end 
       h = h/ratio_b_h;
   end
    count = count + 1;


end

b = cost_lowest(:,1)
h = cost_lowest(:,2)

  %% SAFETY FACTORS:

    %safety_factors = struct(...
     %   'pin_static_bending_SF', SF_static_bending_pin, ...
     %   'LA_static_bending_SF', SF_static_bending_LA, ...
     %   'pin_cyclical_bending_SF', SF_cyclical_bending_pin, ...
     %   'LA_cyclical_bending_SF', SF_cyclical_bending_LA, ...
     %   'pin_static_axial_SF', SF_static_axial_pin, ...
     %   'LA_static_axial_SF', SF_static_axial_LA, ...
     %   'pin_cyclical_axial_SF', SF_cyclical_axial_pin, ...
     %   'LA_cyclical_axial_SF', SF_cyclical_axial_LA);

      safety_factors = struct(...
        'pin_static_bending_SF', SF_best(:,1), ...
        'LA_static_bending_SF', SF_best(:,2), ...
        'pin_cyclical_bending_SF', SF_best(:,3), ...
        'LA_cyclical_bending_SF', SF_best(:,4), ...
        'pin_static_axial_SF', SF_best(:,5), ...
        'LA_static_axial_SF', SF_best(:,6), ...
        'pin_cyclical_axial_SF', SF_best(:,7), ...
        'LA_cyclical_axial_SF', SF_best(:,8));

%% WRITE DIMENSIONS IN TEXT FILE
fileID = fopen('C:\MCG4322B\MCG4322B\code\la\LA_dimensions.txt','w');
formatSpec = '"LA_height" = %3.1f \n "LA_width" = %3.1f \n "LA_length" = %3.1f';
fprintf(fileID,formatSpec,h*1000, b*1000, LA_length*1000);

end


% PULLEY REACTION FORCES
function [angle_force_pulley, force_pulley_y, force_pulley_x] = find_pulley_force(angle_thigh,force_spring,waist_hip_length, hip_cuff_distance, stride_length, weight_pulley)

    angle_centerline_thigh = pi/2 - angle_thigh; %rads
    
    angle_LA_cable = atan((waist_hip_length + cos(angle_centerline_thigh) * hip_cuff_distance)/(1/4*stride_length-sin(angle_centerline_thigh)*hip_cuff_distance));
    angle_force_pulley = angle_LA_cable/2;
    
    %force_weight_CoM = LA_mass*9.81; %never used, should it be?
    
    force_pulley_reaction = 2*force_spring*cos(angle_force_pulley);
    
    force_pulley_reaction_x = force_pulley_reaction*cos(angle_force_pulley);
    force_pulley_reaction_y = force_pulley_reaction*sin(angle_force_pulley);
    
    force_pulley_y = force_pulley_reaction_y + weight_pulley;
    force_pulley_x = force_pulley_reaction_x;
end
