% drift_tester with black circle instead of alien and white background
function drift_tester(arduinoObj)
    close all        % close all pre-opened figure windows
    clc              % clear the command window

    % declare and define global variables
    global m c screen_width screen_height;          % declare m, c, screen_width, and screen_height as globals
    m = 1;                                         % kg, ship mass
    c = 6;                                         % Ns/m damping constant

    screen_width  = 1920;                         % set screen width as 1080 data units
    screen_height = 1080;                         % set screen height as 1920 data units

    % classic RK4 Method parameters
    w1 = 1/6; w2 = 1/3; w3 = 1/3; w4 = 1/6;  c2 = 1/2; c3 = 1/2; c4 = 1;
    a21 = 1/2; a31 = 0; a32 = 1/2; a41 = 0; a42 = 0; a43 = 1;

    pause(2); % THIS 2 second PAUSE IS CRITICAL FOR MATLAB TO SETUP THE SERIAL PORT

    configureTerminator(arduinoObj, "CR/LF"); % setup I/O terminator to be "Carriage Return" and "Linefeed"
    flush(arduinoObj);                         % get rid of all data in arduino data stream

    % setup figure window with white background and circle
    [fig, circle_handle, radius] = figure_setup();

    n = 1000; % number of arduino - matlab communication events

    % preallocate storage arrays
    MATLAB_Data          = zeros(n,1);
    left_joystick_x      = zeros(n,1); left_joystick_y      = zeros(n,1);
    left_button          = zeros(n,1);
    right_joystick_x     = zeros(n,1); right_joystick_y     = zeros(n,1);
    right_button         = zeros(n,1);
    t                    = zeros(n,1); h                    = zeros(n,1);
    x                    = zeros(2, n+1);                       % initialize ship's x state
    y                    = zeros(2, n+1);                       % initialize ship's y state

    % initial conditions
    x(:,1) = [250; 0];        % initial x position (data units) and velocity
    y(:,1) = [960; 0];        % initial y position (data units) and velocity

    start_time = tic;         % start stopwatch for timestamping data (s)
    start_iteration = tic;    % start stopwatch for tracking sample times (s)

    for i = 1:n               % loop through communication events
        time_elapsed  = toc(start_time);           % elapsed time
        time_remaining = max(0, 30 - time_elapsed);% countdown timer
        time_string = sprintf('Time Remaining: %.1f s', time_remaining);

        if exist('time_display','var') && ishandle(time_display)
            delete(time_display);                  % delete previous time display
        end
        time_display = text(20, 20, time_string, 'Color', 'k', 'FontSize', 14, 'Units', 'pixels');

        MATLAB_Data(i) = i;                       % MATLAB sends loop counter data to Arduino
        writeline(arduinoObj, int2str(MATLAB_Data(i)));

        while arduinoObj.NumBytesAvailable == 0, end   % wait for Arduino data
        data = readline(arduinoObj);                % read Arduino string: [time,x,y,btn,x,y,btn]
        tmp  = split(data, ',');                    % split into strings
        vals = str2double(tmp);                     % convert to numeric vector

        Arduino_Counter = vals(1);                  % iteration count from Arduino
        rawX_left  = vals(2); rawY_left  = vals(3); btnL = vals(4);
        rawX_right = vals(5); rawY_right = vals(6); btnR = vals(7);

        % convert raw joystick values to force inputs
        left_joystick_x(i)  = (rawX_left  - 512 + -7)   * 12;
        left_joystick_y(i)  = (rawY_left  - 512 + 21)   * 12;
        right_joystick_x(i) = (rawX_right - 512 + 14.5) * 12;
        right_joystick_y(i) = (rawY_right - 512 + 9)    * 12;

        left_button(i)  = btnL;                      % save left button state
        right_button(i) = btnR;                      % save right button state

        t(i) = toc(start_time);                     % timestamp       
        h(i) = toc(start_iteration);                 % sample time
        start_iteration = tic;

        % handle button events
        if btnL == 1
            disp("Left Button clicked – ending game.");
            action = gameOverMenu(arduinoObj);
            switch action
                case 1, drift_tester(arduinoObj);
                case 2
                    choice = mainMenu(arduinoObj);
                    switch choice
                        case 1, game1(arduinoObj);
                        case 2, game2(arduinoObj);
                        case 3, game3(arduinoObj);
                        case 4, drift_tester(arduinoObj);
                        case 5, disp("Returning to Matlab"), close all;
                    end
                case 3, close all; return;
            end
        end
        if btnR == 1
            disp("Right Button clicked – ending game.");
            close all; break;                        % jump out of loop
        end

        % update physics via RK4
        x(:,i+1) = xRK4(left_joystick_x(i), t(i), x(:,i), h(i), w1,w2,w3,w4, c2,c3,c4, a21,a31,a32,a41,a42,a43);
        y(:,i+1) = yRK4(left_joystick_y(i), t(i), y(:,i), h(i), w1,w2,w3,w4, c2,c3,c4, a21,a31,a32,a41,a42,a43);

        % update circle position
        set(circle_handle, 'Position', [y(1,i+1)-radius, x(1,i+1)-radius, 2*radius, 2*radius]);
        pause(0.0001); % pause to enable display
    end

    clear arduinoObj;  % close the Serial Communication port
end

%% function to setup figure window with white bg and circle
function [fig, hCircle, radius] = figure_setup()
    global screen_width screen_height;             % bring global dimensions into scope
    fig = figure('Position',[-1 42 1920 1080],'Color','w'); % white background
    hold on;       % prevent axes flipping
    axis equal;    % equal axes scales
    xlim([0 screen_width]); ylim([0 screen_height]);
    set(gca, 'visible', 'off', 'Units', 'pixels', 'Position', [0 0 screen_width screen_height]);
    radius = 50;  % ~200 pixel diameter circle
    initX = 250; initY = 960;
    % Circle centered on the ship's initial position
    hCircle = rectangle('Position',[initY-radius, initX-radius, 2*radius, 2*radius], ...
                        'Curvature',[1 1], 'FaceColor','k', 'EdgeColor','k');
end

% original RK4 and differential equation functions remain unchanged
function x_new = xRK4(ui, ti, xi, h, w1,w2,w3,w4, c2,c3,c4, a21,a31,a32,a41,a42,a43)
    global screen_height;
    k1 = h * f(ui, ti, xi);
    k2 = h * f(ui, ti + c2*h, xi + a21*k1);
    k3 = h * f(ui, ti + c3*h, xi + a31*k1 + a32*k2);
    k4 = h * f(ui, ti + c4*h, xi + a41*k1 + a42*k2 + a43*k3);
    x_new = xi + w1*k1 + w2*k2 + w3*k3 + w4*k4;
    if x_new(1) < 0 || x_new(1) > (screen_height-75), x_new(2) = -x_new(2); end
end

function y_new = yRK4(ji, ti, yi, h, w1,w2,w3,w4, c2,c3,c4, a21,a31,a32,a41,a42,a43)
    global screen_width;
    k1 = h * l(ji, ti, yi);
    k2 = h * l(ji, ti + c2*h, yi + a21*k1);
    k3 = h * l(ji, ti + c3*h, yi + a31*k1 + a32*k2);
    k4 = h * l(ji, ti + c4*h, yi + a41*k1 + a42*k2 + a43*k3);
    y_new = yi + w1*k1 + w2*k2 + w3*k3 + w4*k4;
    if y_new(1) < 0 || y_new(1) > screen_width, y_new(2) = -y_new(2); end
end

function dxdt = f(u, ~, x)
    global m c;
    dxdt = [x(2); -c/m*x(2) + u/m];
end

function dydt = l(j, ~, y)
    global m c;
    dydt = [y(2); -c/m*y(2) + j/m];
end
