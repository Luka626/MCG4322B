function [safety_factors] = wrc_design(anthro, design_inputs, material_data)
    %% INITIALIZE VALUES 
    hdpe = material_data("hdpe");
    al6061 = material_data("al6061");

    backplate = struct();
    adjustment = struct();
    frontplate = struct();
    belt = struct();
    padding = struct();
    spring = struct();
    hinge = struct();

    % Anthropometry %
    user = anthro;

    % Force Inputs %
    spring.x = design_inputs.external_loads.max_force.spring_x_force;
    spring.y = design_inputs.external_loads.max_force.spring_y_force;

    % For parametrization %
    best_configuration = struct();
    cost = intmax;
    cost_threshold = 0.05;
    num_iterations = 0;
    MAX_ITER = 10000;
    GOAL_SF = 2.5;

    % Parameterized Dimensions %
    backplate.thickness = 0.0075;       % PARAMETER: [0.003175, _]      %
    frontplate.height = 0.02;           % PARAMETER: [0.03, _]          %
    adjustment.thickness = 0.00635;     % PARAMETER: [0.003175, _]      %         
    hinge.diameter = 0.008;             % PARAMETER: [0.00157, _]       %
    padding.area = 0.001;                % PARAMETER: [_, 2*bplate_area] %

    %% MASS CALCULATIONS
    % Anthropometrized/Constant Dimensions%
    backplate.height = 0.15*user.height;                     % Func. of user height: 0.15 exp. determined %
    backplate.width = 3*user.waist_circumference/10;        % Func. assumes nominal 75% back coverage %
    belt.width = user.waist_radius*2*pi / 10;               % Span of user's waist circumference %
    adjustment.length = user.waist_radius*2/5;              % CONST, to allow for sizing options
    frontplate.thickness = 0.02;                            % CONST, agreed upon with LA %
    belt.release_radius = 0.09;                             % CONST, manufacturer spec.
    belt.roller_radius = 0.06;                              % CONST, manufacturer spec.
    frontplate.load = -1*2*spring.y;                        % From frontplate
    padding.pressure = design_inputs.pain_pressure;         % From requirements

    %% PARAMETRIZATION LOOP

    while (cost > cost_threshold && num_iterations <= MAX_ITER)
    
        % Derived Dimensions %
        frontplate.length = user.waist_radius*2*pi / 4 - belt.width/4; % Leave room for belt width %
        frontplate.thickness_total = (frontplate.thickness + 0.03*1/2*(frontplate.length-frontplate.height)); % derived from simplified geometrty %
        adjustment.height = backplate.height/10;
        hinge.length = frontplate.height;
        belt.tension = design_inputs.strength*belt.release_radius/belt.roller_radius;
    
        %% MASS ANALYSIS
        wrc = struct(...
            "backplate", backplate, ...
            "frontplate", frontplate, ...
            "adjustment", adjustment, ...
            "hinge", hinge, ...
            "padding", padding);  
        [backplate.mass, frontplate.mass, adjustment.mass, hinge.mass] = compute_masses(wrc, hdpe, al6061);
    
        %% BACKPLATE ANALYSIS
        components = struct(...
            "backplate", backplate, ...
            "padding", padding, ...
            "adjustment", adjustment, ...
            "frontplate", frontplate);
        [padding.SF, backplate.SF] = compute_backplate_SF(components, spring, user, hdpe);
    
        %% ADJUSTMENT ANALYSIS
        components = struct(...
            "backplate", backplate, ...
            "adjustment", adjustment);
        [adjustment.SF] = compute_adjustment_SF(components, user, al6061);
    
        %% FRONTPLATE ANALYSIS %%
        components = struct(...
            "belt", belt, ...
            "frontplate", frontplate, ...
            "hinge", hinge);
        [hinge.SF, frontplate.SF] = compute_frontplate_SF(components, user, al6061, hdpe);
   
        %% SAFETY FACTORS, DIMENSIONS:
    
        % safety factors to log %
        config.safety_factors = struct(...
            'backplate_SF', backplate.SF, ...
            'frontplate_SF', frontplate.SF, ...
            'adjustment_SF', adjustment.SF, ...
            'hinge_SF', hinge.SF, ...
            'padding_SF', padding.SF);
        config.cost = compute_cost(config.safety_factors);

        % dimensions to log %
        config.dimensions = struct(...
            'backplate_thickness', backplate.thickness*1000, ...
            'backplate_height', backplate.height*1000, ...
            'backplate_width', backplate.width*1000, ...
            'hinge_diameter', hinge.diameter*1000, ...
            'hinge_height', hinge.length*1000, ...
            'frontplate_height', frontplate.height*1000, ...
            'frontplate_thickness', frontplate.thickness*1000, ...
            'adjustment_thickness', adjustment.thickness*1000, ...
            'adjustment_height', adjustment.height*1000, ...
            'Padding_Area1', 0.45*3*padding.area*1000*1000, ...
            'Padding_Area2', 0.45*3*padding.area*1000*1000, ...
            'Padding_Area3', 0.1*3*padding.area*1000*1000);

        %% LOOP
        % Check if we found the best configuration so far %
        if (config.cost < cost)
            best_configuration = config;
            cost = config.cost;
        end

        % Increment/Decrement parameter based on SF %
        kick = (1/100)*sqrt(cost);
        if (backplate.SF < GOAL_SF)
            backplate.thickness = backplate.thickness + backplate.thickness*kick;
        else
            backplate.thickness = backplate.thickness - backplate.thickness*kick;
        end

        if (frontplate.SF < GOAL_SF)
            frontplate.height = frontplate.height + frontplate.height*kick;
        else
            frontplate.height = frontplate.height - frontplate.height*kick;
        end

        if (adjustment.SF < GOAL_SF)
            adjustment.thickness = adjustment.thickness + adjustment.thickness*kick;
        else
            adjustment.thickness = adjustment.thickness - adjustment.thickness*kick;
        end
        if (hinge.SF < GOAL_SF)
            hinge.diameter = hinge.diameter + hinge.diameter*kick;
        else
            hinge.diameter = hinge.diameter - hinge.diameter*kick;
        end
        if (padding.SF < GOAL_SF)
            padding.area = padding.area + padding.area*kick;
        else
            padding.area = padding.area - padding.area*kick;
        end

        num_iterations = num_iterations + 1;
    end

    log_dimensions("code/wrc/wrc_output.txt", best_configuration.dimensions);
    safety_factors = best_configuration.safety_factors
    num_iterations
end