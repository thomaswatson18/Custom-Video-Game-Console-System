 % launcher.m 
close all        % close all pre-opened figure windows
clc              % clear the command window


% Open Arduino port here and pass the arduino connection into each function
% (each game)

arduinoObj = serialport("COM3",2000000);    % set serial port to be used as COM3 and baud rate at 2000000.

pause(2);                                   % THIS 2 second PAUSE IS CRITICAL FOR MATLAB TO SETUP 
                                            % THE SERIAL PORT

% setup I/O terminator to be "Carriage Return" and "Linefeed"
configureTerminator(arduinoObj,"CR/LF"); % MATLAB will read arduino data until there is CR (ASCII byte 13)
                                         % and (ASCII byte 10). It is
                                         % essentially, for each line of
                                         % code, is how it knows where to
                                         % stop reading into MATLAB.

                                         % Note this only is setting up the
                                         % byte terminator, not actually
                                         % reading it

% get rid of all data in arduino data stream before reading in arduino data
flush(arduinoObj);

% Show the menu, pass in arduino connection, get choice 1–3 (whatever the
% mainMenu returns), Basically calls the mainMenu, and whatever the Main
% menu returns is the choice it uses.
choice = mainMenu(arduinoObj); % This also means MainMenu.m can connect to the Arduino Serial port.

% 3) Call the correct game - based on the main menu, it calls the correct
% game. So if mainmenu returns case 1, it calls game1 and passes the
% arduino connection to that function (that .m code).

switch choice
  case 1
    game1(arduinoObj);
  case 2
    game2(arduinoObj);
  case 3
    game3(arduinoObj);
  case 4
    drift_tester(arduinoObj);
  case 5
    disp("Returning to Matlab");
    close all;
end

% 4) Clean up
clear arduinoObj;
