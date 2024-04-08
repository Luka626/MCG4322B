function [external_loads] = gait_analysis(anthro)

    % GAIT DATA
    gait_param = readmatrix('left_right_thigh_angles.csv');

    % ANTHROPOMETRY
    user = anthro;
    user.L_thigh = (0.53-0.285)*user.height; %m
    user.stride_length = -2.234 + 0.106*user.age - 0.0008*user.age^2; % m 
    
    % EXOSKELETON CONSTANTS

    LA_pulley_center = 0.08; %m
    waist_cuff_thickness = 0.010; %m, should it be constant or change with weight?
    length_pin = 0.030; % m
    LA_length = 1/4*user.stride_length - user.waist_radius - length_pin - waist_cuff_thickness;
    hip_pulley_length = waist_cuff_thickness + length_pin + LA_length + user.waist_radius + LA_pulley_center;
    cuff_disp = 7/8*user.L_thigh; %m
    spring_coeff = 500; %N/m


    % ANGLES OF STUDIED FRAMES
    max_force_right_angle = gait_param(46,3);
    min_force_right_angle= gait_param(1,3);
    max_force_left_angle = gait_param(46,5);
    min_force_left_angle= gait_param(1,5);



    % SPRING LENGTH AT PEAK FLEXION
    og_right_y_length = cuff_disp*sin(min_force_right_angle);
    og_right_x_length = LA_length - cuff_disp*cos(min_force_right_angle);
    og_left_y_length = cuff_disp*sin(min_force_left_angle);
    og_left_x_length = LA_length - cuff_disp*cos(min_force_left_angle);
    
    og_spring_length = (((og_left_x_length+og_right_x_length)/2)^2 + ((og_left_y_length+og_right_y_length)/2)^2)^(1/2);
    
    % FORCE AND RELATED PARAMETERS AT STUDIED FRAMES
    external_loads = struct();
    external_loads.max_force = find_spring_force(spring_coeff, cuff_disp, max_force_right_angle, max_force_left_angle, og_spring_length, hip_pulley_length);
    external_loads.min_force = find_spring_force(spring_coeff, cuff_disp, min_force_right_angle, max_force_left_angle, og_spring_length, hip_pulley_length);


end

function [force_param] = find_spring_force(spring_coeff, cuff_disp, thigh_LA_right_angle, thigh_LA_left_angle, og_spring_length, hip_pulley_length)
spring_right_y_length = cuff_disp*sin(thigh_LA_right_angle);
spring_right_x_length = hip_pulley_length - cuff_disp*cos(thigh_LA_right_angle);
cable_LA_right_angle = atan(spring_right_y_length/spring_right_x_length);

spring_left_y_length = cuff_disp*sin(thigh_LA_left_angle);
spring_left_x_length = hip_pulley_length - cuff_disp*cos(thigh_LA_left_angle);

spring_length = (((spring_right_x_length + spring_left_x_length)/2)^2 + ((spring_right_y_length + spring_left_y_length)/2)^2)^(1/2);
spring_force = spring_coeff*(spring_length - og_spring_length);
spring_x_force = spring_force*cos(cable_LA_right_angle);
spring_y_force = spring_force*sin(cable_LA_right_angle);

cable_thigh_right_angle = pi -thigh_LA_right_angle - cable_LA_right_angle;

force_param = struct();
force_param.spring_length = spring_length;
force_param.spring_force = spring_force;
force_param.spring_x_force = spring_x_force;
force_param.spring_y_force = spring_y_force;
force_param.thigh_LA_right_angle = thigh_LA_right_angle;
force_param.cable_thigh_right_angle = cable_thigh_right_angle;
end
