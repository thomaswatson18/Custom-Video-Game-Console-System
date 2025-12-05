function game3(arduinoObj)
    % Close all pre-opened figure windows and clear the command window
    close all
    clc

    % Declare and define global variables
    global m c screen_width screen_height;
    m = 1;           % kg, alien ship mass
    c = 6;           % Ns/m damping constant
    screen_width = 1920;  % pixels, horizontal dimension
    screen_height = 1080; % pixels, vertical dimension

    % Classic RK4 Method parameters
    w1 = 1/6; w2 = 1/3; w3 = 1/3; w4 = 1/6; c2 = 1/2; c3 = 1/2; c4 = 1;
    a21 = 1/2; a31 = 0; a32 = 1/2; a41 = 0; a42 = 0; a43 = 1;

    % Initialize start_time at the beginning
    start_time = tic;  % Start stopwatch for timestamping data (s)

    % Setup figure window
    [fig, alien, alpha] = figure_setup();
    figure(fig);  % Ensure figure has focus after creation
    drawnow;

    % Number of communication events
    n = 1000;

    % Pre-allocate arrays for speed
    MATLAB_Data = zeros(n,1);
    left_joystick_x = zeros(n,1);
    left_joystick_y = zeros(n,1);
    left_button = zeros(n,1);
    right_joystick_x = zeros(n,1);
    right_joystick_y = zeros(n,1);
    right_button = zeros(n,1);
    t = zeros(n,1);
    h = zeros(n,1);
    x = zeros(2, n+1);
    y = zeros(2, n+1);

    % Initialize ship position and velocity
    x(:,1) = [250; 0];  % initial x position and velocity (vertical)
    y(:,1) = [960; 0];  % initial y position and velocity (horizontal)

    % Display initial alien image
    [b, a, ~] = size(alien);
    scale = 0.3;
    alien_handle = image(alien, 'XData', [0 - scale*a/2, 0 + scale*a/2], ...
                                'YData', [x(1,1) - scale*b/2, x(1,1) + scale*b/2], ...
                                'AlphaData', alpha);

    % Initialize aim circle
    radius = 100;
    circle_handle = rectangle('Position', [y(1,1) - radius, x(1,1) - radius, 2*radius, 2*radius], ...
                              'Curvature', [1 1], 'EdgeColor', 'w', 'LineWidth', 2);

    % Initialize small aim circle
    small_radius = 20;
    threshold = 100;
    initial_theta = 0;
    initial_aim_x = x(1,1) + radius * cos(initial_theta);
    initial_aim_y = y(1,1) + radius * sin(initial_theta);
    aim_handle = rectangle('Position', [initial_aim_x - small_radius, initial_aim_y - small_radius, 2*small_radius, 2*small_radius], ...
                           'Curvature', [1 1], 'FaceColor', 'w');

    % Initialize shooting variables
    prev_btnState_right = 0;
    shot_handles = {};
    shot_data = [];

    % Score tracking
    score = 0;
    score_display = text(20, 40, 'Score: 0', 'Color', 'white', 'FontSize', 14);

    % Falling shapes parameters
    falling_speed = 400; % pixels per second base speed
    min_radius = 70;    % minimum radius of green circles
    max_radius = 200;    % maximum radius of green circles (2x min_radius)
    falling_handles = {};
    falling_data = [];   % [pos_x, pos_y, vx, vy, radius]

    % Shape spawning timer
    rand_interval = 0.1 + rand() * 0.25; % between 0.5 and 1.5 seconds
    next_shape_time = toc(start_time) + rand_interval;

    % Start iteration timer
    start_iteration = tic;

    % Configure serial port to minimize output
    try
        configureTerminator(arduinoObj, "CR/LF");
        flush(arduinoObj);
    catch e
        fid = fopen('game3_error.log', 'a');
        fprintf(fid, 'Serial setup error: %s\n', e.message);
        fclose(fid);
    end

    % Main game loop
    for i = 1:n
        time_elapsed = toc(start_time);
        time_remaining = max(0, 30 - time_elapsed);

        time_string = sprintf('Time Remaining: %.1f s', time_remaining);

        if exist('time_display', 'var') && ishandle(time_display)
            delete(time_display);
        end
        time_display = text(20, 20, time_string, 'Color', 'white', 'FontSize', 14);

        % Spawn new falling shape if it's time
    if time_elapsed > next_shape_time
        shape_radius = min_radius + rand() * (max_radius - min_radius); % Random radius, e.g., between 120 and 240
        speed = falling_speed * (1 + rand()); % Random speed between falling_speed and 2*falling_speed
    
        spawn_type = randi(2); % 1 = corner, 2 = side
    
        if spawn_type == 1 % Spawn from a corner
            corner = randi(4); % 1 = top-left, 2 = top-right, 3 = bottom-left, 4 = bottom-right
            switch corner
                case 1 % Top-left
                    pos_x = -shape_radius;
                    pos_y = -shape_radius;
                    vx = speed / sqrt(2); % Diagonal toward center or bottom-right
                    vy = speed / sqrt(2);
                case 2 % Top-right
                    pos_x = screen_width + shape_radius;
                    pos_y = -shape_radius;
                    vx = -speed / sqrt(2); % Diagonal toward bottom-left
                    vy = speed / sqrt(2);
                case 3 % Bottom-left
                    pos_x = -shape_radius;
                    pos_y = screen_height + shape_radius;
                    vx = speed / sqrt(2); % Diagonal toward top-right
                    vy = -speed / sqrt(2);
                case 4 % Bottom-right
                    pos_x = screen_width + shape_radius;
                    pos_y = screen_height + shape_radius;
                    vx = -speed / sqrt(2); % Diagonal toward top-left
                    vy = -speed / sqrt(2);
            end
        else % Spawn from a side
            side = randi(4); % 1 = top, 2 = bottom, 3 = left, 4 = right
            switch side
                case 1 % Top
                    pos_x = rand() * screen_width;
                    pos_y = -shape_radius;
                    vx = 0;
                    vy = speed; % Move downward
                case 2 % Bottom
                    pos_x = rand() * screen_width;
                    pos_y = screen_height + shape_radius;
                    vx = 0;
                    vy = -speed; % Move upward
                case 3 % Left
                    pos_x = -shape_radius;
                    pos_y = rand() * screen_height;
                    vx = speed; % Move right
                    vy = 0;
                case 4 % Right
                    pos_x = screen_width + shape_radius;
                    pos_y = rand() * screen_height;
                    vx = -speed; % Move left
                    vy = 0;
            end
        end
    
        % Create the new circle with a random color
        new_shape_handle = rectangle('Position', [pos_x - shape_radius, pos_y - shape_radius, 2*shape_radius, 2*shape_radius], ...
                                     'Curvature', [1 1], 'FaceColor', rand(1,3));
        falling_handles{end+1} = new_shape_handle;
        falling_data(end+1, :) = [pos_x, pos_y, vx, vy, shape_radius];
    
        % Set time for next spawn
        rand_interval = 0.15 + rand() * 0.5; % Spawn every 0.5 to 1.5 seconds
        next_shape_time = time_elapsed + rand_interval;
    end

        % Send data to Arduino
        try
            MATLAB_Data(i) = i;
            writeline(arduinoObj, int2str(MATLAB_Data(i)));
        catch e
            fid = fopen('game3_error.log', 'a');
            fprintf(fid, 'Write error at iteration %d: %s\n', i, e.message);
            fclose(fid);
            continue;
        end

        % Wait for Arduino response
        try
            while true
                if arduinoObj.NumBytesAvailable > 0
                    break;
                end
            end
            data = readline(arduinoObj);
            tmp = split(data, ',');
            vals = str2double(tmp);
        catch e
            fid = fopen('game3_error.log', 'a');
            fprintf(fid, 'Read error at iteration %d: %s\n', i, e.message);
            fclose(fid);
            continue;
        end

        Arduino_Counter = vals(1);
        rawX_left = vals(2);
        rawY_left = vals(3);
        btnState_left = vals(4);
        rawX_right = vals(5);
        rawY_right = vals(6);
        btnState_right = vals(7);

        disp("Raw Arduino Data: " + data);

        left_joystick_x(i) = (rawX_left - 512 - 7) * 12;
        left_joystick_y(i) = (rawY_left - 512 + 21) * 12;
        right_joystick_x(i) = (rawX_right - 512 + 14.5) * 12;
        right_joystick_y(i) = (rawY_right - 512 + 9) * 12;

        left_button(i) = btnState_left;
        right_button(i) = btnState_right;

        t(i) = toc(start_time);
        h(i) = toc(start_iteration);
        start_iteration = tic;

        if btnState_left == 1
            disp("Left Button clicked – ending game.");
            disp("Game ended on iteration " + Arduino_Counter);
            close all
            break;
        end

        % Handle shooting with right joystick button
        if prev_btnState_right == 0 && btnState_right == 1
            dy = right_joystick_x(i);
            dx = right_joystick_y(i);
            mag = sqrt(dy^2 + dx^2);
            if mag > threshold
                shot_pos_x = aim_x;
                shot_pos_y = aim_y;
                shot_speed = 1000; % Adjust ball speed (that are shot)
                shot_vel_x = shot_speed * cos(theta);
                shot_vel_y = shot_speed * (-sin(theta));
                new_shot_handle = rectangle('Position', [shot_pos_x - small_radius, shot_pos_y - small_radius, 2*small_radius, 2*small_radius], ...
                                            'Curvature', [1 1], 'FaceColor', 'r');
                shot_handles{end+1} = new_shot_handle;
                shot_data(end+1, :) = [shot_pos_x, shot_pos_y, shot_vel_x, shot_vel_y];
            end
        end
        prev_btnState_right = btnState_right;

        % Update alien position using RK4
        x(:,i+1) = xRK4(left_joystick_x(i), t(i), x(:,i), h(i), w1, w2, w3, w4, c2, c3, c4, a21, a31, a32, a41, a42, a43);
        y(:,i+1) = yRK4(left_joystick_y(i), t(i), y(:,i), h(i), w1, w2, w3, w4, c2, c3, c4, a21, a31, a32, a41, a42, a43);

        delete(alien_handle);
        alien_handle = image(alien, 'XData', [y(1,i+1) - scale*a/2, y(1,i+1) + scale*a/2], ...
                                    'YData', [x(1,i+1) - scale*b/2, x(1,i+1) + scale*b/2], ...
                                    'AlphaData', alpha);

        set(circle_handle, 'Position', [y(1,i+1) - radius, x(1,i+1) - radius, 2*radius, 2*radius]);

        % Update aim position based on right joystick
        dy = right_joystick_x(i);
        dx = right_joystick_y(i);
        mag = sqrt(dy^2 + dx^2);

        disp("dy = " + dy + ", dx = " + dx + ", magnitude = " + mag);
        theta = 0;
        if mag > threshold
            theta = atan2(-dy, dx);
            set(aim_handle, 'Visible', 'on');
            disp("Threshold Met! Current angle is: " + theta + " radians");
        else
            set(aim_handle, 'Visible', 'off');
        end
        aim_x = y(1,i+1) + radius * cos(theta);
        aim_y = x(1,i+1) - radius * sin(theta);
        set(aim_handle, 'Position', [aim_x - small_radius, aim_y - small_radius, 2*small_radius, 2*small_radius]);

        % Update shot circles
        if ~isempty(shot_data)
            shot_data(:,1:2) = shot_data(:,1:2) + shot_data(:,3:4) * h(i);
            for k = 1:length(shot_handles)
                set(shot_handles{k}, 'Position', [shot_data(k,1) - small_radius, shot_data(k,2) - small_radius, 2*small_radius, 2*small_radius]);
            end
            off_screen = shot_data(:,1) < 0 | shot_data(:,1) > screen_width | shot_data(:,2) < 0 | shot_data(:,2) > screen_height;
            if any(off_screen)
                delete([shot_handles{off_screen}]);
                shot_handles = shot_handles(~off_screen);
                shot_data = shot_data(~off_screen, :);
            end
        end

        % Update falling shapes
        if ~isempty(falling_data)
            % Update positions using velocity components
            falling_data(:,1) = falling_data(:,1) + falling_data(:,3) * h(i); % x-position
            falling_data(:,2) = falling_data(:,2) + falling_data(:,4) * h(i); % y-position
            for k = 1:length(falling_handles)
                shape_radius_k = falling_data(k,5);
                set(falling_handles{k}, 'Position', [falling_data(k,1) - shape_radius_k, falling_data(k,2) - shape_radius_k, 2*shape_radius_k, 2*shape_radius_k]);
            end
            % Check if shapes are off-screen in any direction
            off_screen = (falling_data(:,1) < -falling_data(:,5)) | (falling_data(:,1) > screen_width + falling_data(:,5)) | ...
                         (falling_data(:,2) < -falling_data(:,5)) | (falling_data(:,2) > screen_height + falling_data(:,5));
            if any(off_screen)
                delete([falling_handles{off_screen}]);
                falling_handles = falling_handles(~off_screen);
                falling_data = falling_data(~off_screen, :);
            end
        end

        % Check for collisions between shots and shapes
        if ~isempty(shot_data) && ~isempty(falling_data)
            shots_to_remove = false(size(shot_data,1),1);
            shapes_to_remove = false(size(falling_data,1),1);
            for s = 1:size(shot_data,1)
                for f = 1:size(falling_data,1)
                    dist = sqrt((shot_data(s,1) - falling_data(f,1))^2 + (shot_data(s,2) - falling_data(f,2))^2);
                    if dist < (small_radius + falling_data(f,5))
                        shots_to_remove(s) = true;
                        shapes_to_remove(f) = true;
                        score = score + 1;
                    end
                end
            end
            delete([shot_handles{shots_to_remove}]);
            shot_handles = shot_handles(~shots_to_remove);
            shot_data = shot_data(~shots_to_remove, :);
            delete([falling_handles{shapes_to_remove}]);
            falling_handles = falling_handles(~shapes_to_remove);
            falling_data = falling_data(~shapes_to_remove, :);
        end

        % Check for collision between ship circle and green circles
        ship_pos = [y(1,i+1), x(1,i+1)];  % [horizontal, vertical]
        for k = 1:size(falling_data,1)
            green_pos = [falling_data(k,1), falling_data(k,2)];
            dist = sqrt((ship_pos(1) - green_pos(1))^2 + (ship_pos(2) - green_pos(2))^2);
            if dist < (radius + falling_data(k,5))
                disp('Game Over: Ship collided with green circle.');
                [gameOverImage, ~, alphaChannel] = imread('gameover.png');
                [h_img, w_img, ~] = size(gameOverImage);

                x0 = ((screen_width - w_img) / 2) + 0;  % Adjusted as in game1.m
                y0 = ((screen_height - h_img) / 2) - 0;
                
                delete(alien_handle);
                delete(circle_handle);
                delete(aim_handle);
                for s = 1:length(shot_handles)
                    delete(shot_handles{s});
                end
                for f = 1:length(falling_handles)
                    delete(falling_handles{f});
                end
                h = imshow(gameOverImage, 'XData', [x0, x0 + w_img], 'YData', [y0, y0 + h_img]);
                set(h, 'AlphaData', alphaChannel);
                title('Game Over');
                pause(0.5);
                action = gameOverMenu(arduinoObj);
                switch action
                    case 1
                        game3(arduinoObj);
                    case 2
                        choice = mainMenu(arduinoObj);
                        switch choice
                            case 1, game1(arduinoObj);
                            case 2, game2(arduinoObj);
                            case 3, game3(arduinoObj);
                            case 4, drift_tester(arduinoObj);
                            case 5 
                                disp("Returning to Matlab");
                                close all;
                        end
                    case 3
                        close all;
                        return;
                end
                break;
            end
        end

        % Update score display
        set(score_display, 'String', sprintf('Score: %d', score));

        % Ensure figure retains focus
        figure(fig);
        drawnow;

        pause(0.0001);
    end

    clear arduinoObj;
end

% Placeholder for figure_setup function
function [f, alien_image, alpha_channel] = figure_setup()
    f = figure('position', [-1 42 1920 1080]);
    hold on
    axis('equal')
    bkgrnd = imread('bg3.jpg');
    bkgrnd = flipud(bkgrnd);
    image(bkgrnd);
    ax = gca;
    ax.Position = [0 0 1 1];
    set(gcf, 'Toolbar', 'none', 'Menu', 'none');
    set(gca, 'visible', 'off');
    axis('manual')
    [alien_image, ~, alpha_channel] = imread('alienresize.png');
    alien_image = flipud(alien_image);
    alpha_channel = flipud(alpha_channel);
end

% Placeholder for xRK4 and yRK4 functions
function x_new = xRK4(ui, ti, xi, h, w1, w2, w3, w4, c2, c3, c4, a21, a31, a32, a41, a42, a43)
    global screen_height; % Vertical dimension for x (YData)
    k1 = h * f(ui, ti, xi);
    k2 = h * f(ui, ti + c2 * h, xi + a21 * k1);
    k3 = h * f(ui, ti + c3 * h, xi + a31 * k1 + a32 * k2);
    k4 = h * f(ui, ti + c4 * h, xi + a41 * k1 + a42 * k2 + a43 * k3);
    x_new = xi + w1 * k1 + w2 * k2 + w3 * k3 + w4 * k4;
    if x_new(1) < 0 || x_new(1) > screen_height
        x_new(2) = -x_new(2);
    end
end

function y_new = yRK4(ji, ti, yi, h, w1, w2, w3, w4, c2, c3, c4, a21, a31, a32, a41, a42, a43)
    global screen_width; % Horizontal dimension for y (XData)
    k1 = h * l(ji, ti, yi);
    k2 = h * l(ji, ti + c2 * h, yi + a21 * k1);
    k3 = h * l(ji, ti + c3 * h, yi + a31 * k1 + a32 * k2);
    k4 = h * l(ji, ti + c4 * h, yi + a41 * k1 + a42 * k2 + a43 * k3);
    y_new = yi + w1 * k1 + w2 * k2 + w3 * k3 + w4 * k4;
    if y_new(1) < 0 || y_new(1) > screen_width
        y_new(2) = -y_new(2);
    end
end

function dxdt = f(u, ~, x)
    global m c;
    dxdt = [x(2); -c/m*x(2) + u/m];
end

function dydt = l(j, ~, y)
    global m c;
    dydt = [y(2); -c/m*y(2) + j/m];
end