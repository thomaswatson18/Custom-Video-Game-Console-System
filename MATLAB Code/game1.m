function game1(arduinoObj)

    close all        % close all pre-opened figure windows
    clc              % clear the command window

    % declare and define global variables
    global m c screen_width screen_height;          % declare m, c, screen_width, and screen_height as global variables for ease of use in main code and functions.
    m=1;                                            % kg, alien ship mass
    c=6; % Ns/m damping constant
    screen_width = 1080;                            % set screen width as 1080 pixels wide.
    screen_height = 1920;                           % set screen height as 1920 pixels high.

    % classic RK4 Method parameters
    w1=1/6; w2=1/3; w3=1/3; w4=1/6;  c2=1/2; c3=1/2; c4=1;
    a21=1/2; a31=0; a32=1/2; a41=0; a42=0; a43=1;

    % create a serial client for communication with the Arduino UNO
    % note this command also "resets" the Arduino UNO as if
    % the red "reset" button on the Arduino UNO was pressed
    % need to ensure COM port number and baud rate is correct and consistent
    % with Arduino IDE code
    % arduinoObj = serialport("COM3",2000000); % set serial port to be used as COM3 and baud rate at 2000000.

    pause(2); % THIS 2 second PAUSE IS CRITICAL FOR MATLAB TO SETUP THE SERIAL PORT

    configureTerminator(arduinoObj,"CR/LF"); % setup I/O terminator to be "Carriage Return" and "Linefeed"
                                             % Tells MATLAB that one
                                             % complete line of data has
                                             % arrived.

                                             % CR is ASCII byte 13: tells cursor
                                             % to go back to the start of
                                             % the line

                                             % LF is ASCII byte 10 


 

    [fig, alien, alpha, asteroid_image1, asteroid_alpha1, asteroid_image2, ...
    asteroid_alpha2, asteroid_image3, asteroid_alpha3, asteroid_image4, asteroid_alpha4,] = figure_setup(); % function to setup figure window

    n = 1000; % number of communication events;

    % pre-allocate arrays for speed
    MATLAB_Data     = zeros(n,1); % store data sent from MATLAB
    u               = zeros(n,1); % store joystick x axis values received from Arduino
    j               = zeros(n,1); % store joystick y axis values received from Arduino
    t               = zeros(n,1); % time stamp vector (s)
    h               = zeros(n,1); % store sample times (s)
    x               = zeros(2,n); % store RK4 solution of 2x1 system state for x axis:
                                  % [mass x position;
                                  %  mass x velocity];
                                  % at time i in column i of a 2xn matrix
    y               = zeros(2,n); % store RK4 solution of 2x1 system state for y axis:
                                  % [mass y position;
                                  %  mass y velocity];
                                  % at time i in colum i of a 2xn matrix

    left_button          = zeros(n,1); % store button as a nx1 matrix


    collision_threshold = 230; % Threshold for collision between alien ship 
                               % and asteroid. Asteroid image has non-uniform 
                               % radius of roughly 250 pixels.
                               % Therefore, we make the threshold for
                               % collision 240 pixels to account for the
                               % refresh rate. We don't want MATLAB
                               % detecting collision when the ship doesn't
                               % touch the asteroid, so we make the
                               % threshold just inside the asteroid.

    x_asteroid1 = randi([0, 650]);          % set initial x position of asteroid1 as a random number between 650 and 1300.
                                            % This makes the asteroids fall
                                            % randomly from the top of the
                                            % screen on the lefthand side
                                            % for even distribution of
                                            % asteroids and ensures that they
                                            % do no spawn out of the
                                            % screen.
    y_asteroid1 = 1080; % initial y position of asteroid1 at top of screen

    x_asteroid2 = randi([0, 650]);          % set initial x position of asteroid2 as a random number between 0 and 650.
                                            % This makes the asteroids fall
                                            % randomly from the top of the
                                            % screen on the lefthand side
                                            % for even distribution of
                                            % asteroids and ensures that they
                                            % do no spawn out of the
                                            % screen.

    y_asteroid2 = 1080; % initial y position of asteroid2 at top of screen

    x_asteroid3 = randi([650, 1300]);       % set initial x position of asteroid3 as a random number between 650 and 1300.
                                            % This makes the asteroids fall
                                            % randomly from the top of the
                                            % screen on the righthand side
                                            % for even distribution of
                                            % asteroids and ensures that they
                                            % do no spawn out of the
                                            % screen.
    y_asteroid3 = 1080; % initial y position of asteroid3 at top of screen

    x_asteroid4 = randi([650, 1300]);       % set initial x position of asteroid4 as a random number between 650 and 1300.
                                            % This makes the asteroids fall
                                            % randomly from the top of the
                                            % screen on the righthand side
                                            % for even distribution of
                                            % asteroids and ensures that they
                                            % do no spawn out of the
                                            % screen.

    y_asteroid4 = 1080; % initial y position of asteroid4 at top of screen

    x(:,1) = [250;      % initial x position (m)
              0];       % initial x velocity (m/s)

    y(:,1) = [960;      % initial y position (m)
              0];       % initial y velocity (m/s)

    [b, a, ~] = size(alien);   % plot initial alien location in figure window
    scale = 0.17;              % scale image

    % display initial image of alien
    alien_handle = image(alien, 'XData', [0-scale*a/2, 0+scale*a/2],...  % display alien x data
                    'YData', [x(1,1)-scale*b/2, x(1,1)+scale*b/2],...    % display alien y data
                    'AlphaData', alpha);                                 % display alien alpha channel data
  
    % display initial images of asteroids

    asteroid_handle1 = image(asteroid_image1, 'XData', x_asteroid1,...
                    'YData', y_asteroid1,...
                    'AlphaData', asteroid_alpha1); % display asteroid1
    asteroid_handle2 = image(asteroid_image2, 'XData', x_asteroid2,...
                    'YData', y_asteroid2,...
                    'AlphaData', asteroid_alpha2); % display asteroid2
    asteroid_handle3 = image(asteroid_image3, 'XData', x_asteroid3,...
                    'YData', y_asteroid3,...
                    'AlphaData', asteroid_alpha3); % display asteroid3
    asteroid_handle4 = image(asteroid_image4, 'XData', x_asteroid4,...
                    'YData', y_asteroid4,...
                    'AlphaData', asteroid_alpha4); % display asteroid4

    start_time = tic;      % start stopwatch for timestamping data (s)
    start_iteration = tic; % start stopwatch for tracking sample times (s)

 for i = 1:n            % loop through num_iter communication events

    time_elapsed = toc(start_time);             % initialize timer.
    time_remaining = max(0, 30 - time_elapsed); % set timer to start at 30 seconds
                                                % amd count down to 0.
                                                % This also ensures time remaining doesn't go negative

    time_string = sprintf('Time Remaining: %.1f s', time_remaining); % display time.
    
    if exist('time_display', 'var') && ishandle(time_display) % if statement to delete previous time display
        delete(time_display); % delete previous time display
    end
    
    time_display = text(20, 20, time_string, 'Color', 'white', 'FontSize', 14); % graphical settings for timer

    MATLAB_Data(i) = i; % update the 1x1 array (the MATLAB loop counter) with the current iteration
    writeline(arduinoObj,int2str(MATLAB_Data(i))); % convert current iteration to a string
                                               % It then sends this string
                                               % followed by CR and LF

                                               % This is the >2? question
                                               % Arduino is asking so it
                                               % can read another input
                                               % signal. Arduino will only
                                               % do a read if this
                                               % condition is true (if it
                                               % got here)
                                              
% Like saying “Hey Arduino, it’s request number 1 (or 2, or 3)… ready for your data?”
% Now, Arduino is doing its thing (at this moment)

% So, it will clear current bytes stored in the COM port, Read all inputs,
% add CR and LF at the end and then send this over via arduinoObj (It is
% currently empty as at the end of every MATLAB loop, ArduinoOBJ is cleared

        % MATLAB waits for Arduino to respond with data
        while true
           if arduinoObj.NumBytesAvailable > 0 % Arduino has data ready 
                                               % for MATLAB
              break;                           % stop waiting for data from arduino and process data using code below.
           end
        end

        % MATLAB does the following once data is cleared:

        data = readline(arduinoObj);      % e.g. "17,523,498,1,1023,652" - reads arduino string
                                          % Reads only until CR/LF, as this
                                          % terminator for arduinoObj was
                                          % already set above

        disp("Raw line from Arduino: " + data); % Display what is read for each loop
        tmp  = split(data,',');                 % split into 7 strings, store as temp as it needs to
                                                % be converted into a
                                                % double to do math.

                                                % NOTE: splitting a string
                                                % by commas turns it into
                                                % an array, as MATLAB
                                                % counts string-delimited
                                                % datasets as arrays

        vals = str2double(tmp);                 % converts string array to double array [17; 523; 498; 1]

        Arduino_Counter = vals(1);        % iteration of data input event

        rawX            = vals(2);        % raw X value read from input array (0-1023)
        rawY            = vals(3);        % raw Y value read from input array (0-1023)
        btnState        = vals(4);        % 0 = not pressed, 1 = pressed 

        u(i) = (rawX - 512 + -7)*12;      % convert joystick x value between 0 - 1023 to -512 to 512
                                          % add 7 as a correction to "drift"

                                          % neg values now count as down,
                                          % pos are up. 

                                          % note that u(i) is a 1x1 array

                                          % also scale input values by 12
                                          % (-3024 to 3024) - this tunes
                                          % how sentitive the joystick
                                          % feels

        j(i) = (rawY - 512 + 22)*12;      % convert joystick y value bewteen 0 -1023 to -512 to 512
                                          % add x as a correction to "drift"

        left_button(i) = btnState;        % save button state in current iteration as btnstate

        t(i)=toc(start_time);             % timestamp collected data as t(i)
                                          % (current time stamp at
                                          % iteration i)

        h(i)=toc(start_iteration);        % timer step size for iteration of RK4 - the amount i want to advance
                                          % movement in the game/the entire
                                          % simulation by

        start_iteration=tic;              % restart stopwatch for timestep iteration time - next loop will account for this

        if btnState == 1

            disp("Left Button clicked – ending game.");
            disp("Game ended on iteration " + Arduino_Counter);
            close all
            break;                        % jump out of the for-loop
            
        end


        % use xRK4 function to update the x position of the alien
        x(:,i+1)=xRK4(u(i),t(i),x(:,i),h(i),w1,w2,w3,w4,c2,c3,c4,a21,...
                 a31,a32,a41,a42,a43); % pass these variables to xRK4 function
           
        % use yRK4 function to update the y position of the alien
        y(:,i+1)=yRK4(j(i),t(i),y(:,i),h(i),w1,w2,w3,w4,c2,c3,c4,a21,...
                 a31,a32,a41,a42,a43); % pass these variables to yRK4 function

        delete(alien_handle); % delete previous position of the alien ship

        % update position of alien ship
        alien_handle = image(alien, 'XData', [y(1,1+i)-scale*a/2, y(1,1+i)+scale*a/2],... % update new version of alien x data
                'YData', [x(1,1+i)-scale*b/2, x(1,1+i)+scale*b/2],... % update new version of alien y data
                'AlphaData', alpha); % update new version of alien alpha channel data
    
        % update position of asteroid1
        y_asteroid1 = y_asteroid1 - 30; % constant velocity downward at roughly 30 pixels per second
        delete(asteroid_handle1);
     
        % update position of asteroid2
        y_asteroid2 = y_asteroid2 - 70; % constant velocity downward at roughly 70 pixels per second
        delete(asteroid_handle2);
        
        % update position of asteroid3
        y_asteroid3 = y_asteroid3 - 40; % constant velocity downward at roughly 40 pixels per second
        delete(asteroid_handle3);
    
        % update position of asteroid4
        y_asteroid4 = y_asteroid4 - 80; % constant velocity downward at roughly 80 pixels per second
        delete(asteroid_handle4);
   
        asteroid_handle1 = image(asteroid_image1, 'XData', x_asteroid1,...
                           'YData', y_asteroid1,...
                           'AlphaData', asteroid_alpha1); % display new position of asteroid1
        asteroid_handle2 = image(asteroid_image2, 'XData', x_asteroid2,...
                           'YData', y_asteroid2,...
                           'AlphaData', asteroid_alpha2); % display new position of asteroid2
        asteroid_handle3 = image(asteroid_image3, 'XData', x_asteroid3,...
                           'YData', y_asteroid3,...
                           'AlphaData', asteroid_alpha3); % display new position of asteroid3
        asteroid_handle4 = image(asteroid_image4, 'XData', x_asteroid4,...
                           'YData', y_asteroid4,...
                           'AlphaData', asteroid_alpha4); % display new position of asteroid4


    % check if asteroid1 has reached the bottom of the screen
    if y_asteroid1 < -500 % set as -500 so that the asteroid fully leaves the screen
                         % prior to being deleted
     x_asteroid1 = randi([0, 650]); % reset x position of asteroid1 as a random number between 0 and 650 to generate at the top of the screen.
     y_asteroid1 = screen_height; % reset asteroid1 position to the top of the screen
    end

    % check if asteroid2 has reached the bottom of the screen
    if y_asteroid2 < -500 % set as -500 so that the asteroid fully leaves the screen
                         % prior to being deleted
     x_asteroid2 = randi([0, 650]); % reset x position of asteroid2 as a random number between 0 and 650 to generate at the top of the screen.
     y_asteroid2 = screen_height; % reset asteroid2 position to the top of the screen
    end

    % check if asteroid3 has reached the bottom of the screen
    if y_asteroid3 < -500 % set as -500 so that the asteroid fully leaves the screen
                         % prior to being deleted
     x_asteroid3 = randi([650, 1300]); % reset x position of asteroid3 as a random number between 650 and 1300 to generate at the top of the screen.
     y_asteroid3 = screen_height; % reset asteroid3 position to the top of the screen
    end

    % check if asteroid4 has reached the bottom of the screen
    if y_asteroid4 < -500 % set as -500 so that the asteroid fully leaves the screen
                         % prior to being deleted
     x_asteroid4 = randi([650, 1300]); % reset x position of asteroid4 as a random number between 650 and 1300 to generate at the top of the screen.
     y_asteroid4 = screen_height; % reset asteroid4 position to the top of the screen
    end

    
   % calculate distance between the center of the asteroid and the center
   % of the alien ship
   distance1 = sqrt((y(1,i) - (x_asteroid1 + 264))^2 + (x(1,i) - (y_asteroid1 + 246))^2); % distance formula between center of asteroids and center of the alien ship.
                                                                                          % +264 and +246 are corrections for where the position of the asteroid is actually
                                                                                          % tracked by MATLAB. The asteroid is actually tracked in the bottom left of its image.
                                                                                          % The addition corrects this and makes it so it calculates the distance between
                                                                                          % the center of the asteroid an the center of the alien ship
   distance2 = sqrt((y(1,i) - (x_asteroid2 + 264))^2 + (x(1,i) - (y_asteroid2 + 246))^2);
   distance3 = sqrt((y(1,i) - (x_asteroid3 + 264))^2 + (x(1,i) - (y_asteroid3 + 246))^2);
   distance4 = sqrt((y(1,i) - (x_asteroid4 + 264))^2 + (x(1,i) - (y_asteroid4 + 246))^2); 

   distances = [distance1, distance2, distance3, distance4];


   % check for collision between alien and asteroid by comparing the
   % distance to the centers with the collision threshold
   if any(distances < collision_threshold) % radius of asteroid is ~250 pixels. Therefore, we have the collision_threshold be 230 to account for non-uniform radius.
        disp('Game Over: Alien collided with asteroid.'); % display words to say that you lost.

        [gameOverImage, ~, alphaChannel] = imread('gameover.png'); % load game over image with alpha channel
        
        [h_img, w_img, ~] = size(gameOverImage);

        x0 = (screen_width  - w_img) / 2;  % center horizontally
        y0 = (screen_height - h_img) / 2; % center vertically
        
        % Apply manual tweak
        x0 = x0 + 400;  % move right 400 pixels
        y0 = y0 - 400; % move down 400 pixels
        
        delete(asteroid_handle1); % delete asteroid1 when game over image is displayed
        delete(asteroid_handle2); % delete asteroid2 when game over image is displayed
        delete(asteroid_handle3); % delete asteroid3 when game over image is displayed
        delete(asteroid_handle4); % delete asteroid4 when game over image is displayed
        delete(alien_handle); % delete alien ship when game over image is displayed

        h = imshow(gameOverImage, ... % display the game over image
            'XData', [x0, x0 + w_img], ...
            'YData', [y0, y0 + h_img]);

        set(h, 'AlphaData', alphaChannel); % alpha channel for game over image
        title('Game Over'); % title it "Game Over"
        % break; % exit the loop, end the game

        pause(0.5);
        action = gameOverMenu(arduinoObj);

        switch action
          case 1
            game1(arduinoObj);
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
   end

    if (time_remaining == 0) % if statement to load the winner image when the timer reaches zero

        [WinnerImage, ~, alphaWinnerChannel] = imread('winner.png'); % load winner image with alpha channel
        delete(asteroid_handle1); % delete asteroid1 when game over image is displayed
        delete(asteroid_handle2); % delete asteroid2 when game over image is displayed
        delete(asteroid_handle3); % delete asteroid3 when game over image is displayed
        delete(asteroid_handle4); % delete asteroid4 when game over image is displayed
        delete(alien_handle); % delete alien ship when game over image is displayed
        h = imshow(WinnerImage); % display the winner image
        set(h, 'AlphaData', alphaWinnerChannel); % alpha channel for winner image
        title('Winner'); % title it "Winner"

    end       

pause(0.0001); % pause to enable MATLAB to display everything. Without this,
               % MATLAB would not display everything
    
    end % loop back and send data to Arduino

    clear arduinoObj;  % close the Serial Communication port
                       % if you do not close the serial COM port
                       % then you will not be able to download
                       % programs to the Arduino board
end

%% function to setup figure window
function [f, alien_image, alpha_channel, asteroid_image1, asteroid_alpha1, asteroid_image2, asteroid_alpha2, ...
    asteroid_image3, asteroid_alpha3, asteroid_image4, asteroid_alpha4] = figure_setup() % input variables to this function
    f=figure('position',[-1 42 1920 1080]); % moved figure where I wanted it,
    hold on % prevent axes from flipping y-axis when plotting images
    axis('equal') % ensure same scales for x- and y-axes
    bkgrnd=imread('space.jpg'); % load image
    bkgrnd=flipud(bkgrnd); % flip image so it is right-side-up on normal y-ascending axes
    BK1=image(bkgrnd); % plot image
                       % to use up full figure window resize and reposition axes of plot
                       % to its normalized limits (0 to 1)
    ax=gca; % get current axes handle
    ax.Position=[0 0 1 1]; % normalized position of axes [left bottom width height]
    set(gcf,'Toolbar','none','Menu','none'); % remove toolbar and menu
    set(gca,'visible','off'); % remove axis labels
    axis('manual') % freeze all axis limits for subsequent plots so they
                   % do not automatically adjust on the fly


    [alien_image, ~, alpha_channel]=imread('alienresize.png'); % read image of alien to track
    alien_image = flipud(alien_image); % flip the image to make it right side up
    alpha_channel = flipud(alpha_channel); % flip the alphachannel to make it match the image

    [asteroid_image1, ~, asteroid_alpha1] = imread('asteroid.png'); % read image of asteroid1 to track
    asteroid_image1 = flipud(asteroid_image1); % flip the asteroid1 to make it right side up
    asteroid_alpha1 = flipud(asteroid_alpha1); % flip the alphachannel1 to make it match the image

    [asteroid_image2, ~, asteroid_alpha2] = imread('asteroid.png'); % read image of asteroid2 to track
    asteroid_image2 = flipud(asteroid_image2); % flip the asteroid2 to make it right side up
    asteroid_alpha2 = flipud(asteroid_alpha2); % flip the alphachannel2 to make it match the image

    [asteroid_image3, ~, asteroid_alpha3] = imread('asteroid.png'); % read image of asteroid3 to track
    asteroid_image3 = flipud(asteroid_image3); % flip the asteroid3 to make it right side up
    asteroid_alpha3 = flipud(asteroid_alpha3); % flip the alphachannel3 to make it match the image

    [asteroid_image4, ~, asteroid_alpha4] = imread('asteroid.png'); % read image of asteroid4 to track
    asteroid_image4 = flipud(asteroid_image4); % flip the asteroid4 to make it right side up
    asteroid_alpha4 = flipud(asteroid_alpha4); % flip the alphachannel4 to make it match the image
    
end

% Runge-Kutta (RK) fourth order method for alien's x-coordinate
% Essentially maps, or guesses the next predicted x coordinate for the 
% specified (in this case read in) timestep. This is smooth because the
% timestep is read as the amount of time the iteration of the loop before
% calling this took.


function x_new = xRK4(ui, ti, xi, h, w1, w2, w3, w4, c2, c3, c4, a21, a31, a32, a41, a42, a43)

    % Brings in local variables in function call ^

    % calls global variables
    global screen_width; 

    % in each k calculation, the dxdt function is called and the RK4
    % variables are passed in. The dxdt fuction returns next velocity (1,1)
    % and the next expected acceleration (2,1)


    % multiply this 2x1 vector f(1,2) by a scaler, k ends up being a 2x1
    % vector that is used as the steering/governing state (k1 =
    %                                                          [
    %                                                           h * velocity;   ≈ change in position
    %                                                           h * acceleration  ≈ change in velocity
    %                                                            ]
    % These are used in x_new to display next expected x-coordinate

    k1 = h * f(ui, ti, xi); % Runge-Kutta calculations
    k2 = h * f(ui, ti + c2 * h, xi + a21 * k1); % Runge-Kutta calculations
    k3 = h * f(ui, ti + c3 * h, xi + a31 * k1 + a32 * k2); % Runge-Kutta calculations
    k4 = h * f(ui, ti + c4 * h, xi + a41 * k1 + a42 * k2 + a43 * k3); % Runge-Kutta calculations
    x_new = xi + w1 * k1 + w2 * k2 + w3 * k3 + w4 * k4; % Runge-Kutta calculations

    % check for collision with screen edges
    if x_new(1) < 0 || x_new(1) > screen_width % check if the current x position of the alien
                                               % is past the screen width
                                               
        x_new(2) = -x_new(2); % reverse velocity if alien is at the edge of the screen 
    end
end

% function containing the differential equations dx/dt=f(t,x) to solve for alien's x-coordinate
% This 2x1 solution is what is passed into the RK4 method to return a "K1" or ... "K4"
% value

% function to output the current velocity (dxdt(1,1)) which is different
% for the four k values in rk4

% and to output the accecleration (derivative of velocity)

function dxdt=f(u,~,x) % function input variables, u is input force (scaled already - read from joystick)
                       % x is the current state vector (x = [position;
                       %                                    velocity];

                       % so x(1) is position (irrelevant)
                       % x(2) is current velocity

    global m c;        % call global variables (mass and damping constant)

    dxdt(1,1)=x(2);    % rate of change of position is velocity - which is already x(2)
                       % so (-c/m)*(velocity) + u/m = acceleration

    dxdt(2,1)=-c/m*x(2) + u/m; % mass-drag system in zero-g with applied force 
                               % function now returns velocity and acceleration

end


% Runge-Kutta (RK) fourth order method for alien's y-coordinate
function y_new = yRK4(ji, ti, yi, h, w1, w2, w3, w4, c2, c3, c4, a21, a31, a32, a41, a42, a43) % function input variables
    global screen_height; % call global variables
    k1 = h * l(ji, ti, yi); % Runge-Kutta calculations
    k2 = h * l(ji, ti + c2 * h, yi + a21 * k1); % Runge-Kutta calculations
    k3 = h * l(ji, ti + c3 * h, yi + a31 * k1 + a32 * k2); % Runge-Kutta calculations
    k4 = h * l(ji, ti + c4 * h, yi + a41 * k1 + a42 * k2 + a43 * k3); % Runge-Kutta calculations
    y_new = yi + w1 * k1 + w2 * k2 + w3 * k3 + w4 * k4; % Runge-Kutta calculations
    % check for collision with screen edges
    if y_new(1) < 0 || y_new(1) > screen_height % check if the y position of the alien
                                                % is past the screen height
        y_new(2) = -y_new(2); % reverse velocity if alien is at the edge of the screen
    end
end


% function containing the differential equations dx/dt=f(t,x) to solve for alien's y-coordinate
function dydt=l(j,~,y) % function input variables
    global m c; % bring global variables that were defined at beginning of code
    dydt(1,1)=y(2); % mass drag system for y
    dydt(2,1)=-c/m*y(2) + j/m; % mass-drag system in zero-g with applied force u
end
