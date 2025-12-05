function choice = mainMenu(arduinoObj)
    % Create figure for the menu
    hFig = figure('Name','Choose a Game','MenuBar','none', ...
                  'ToolBar','none','Color',[0.1 0.1 0.1]);
    axis off; xlim([0 1]); ylim([0 1]);
    
    % Display four menu options
    text(.5,.8,'> Game 1: Asteroid Evaders','FontSize',20,'Color','y','Tag','opt1','HorizontalAlignment','center');
    text(.5,.65,'  Game 2: TBD','FontSize',20,'Color','w','Tag','opt2','HorizontalAlignment','center');
    text(.5,.5,'  Game 3: Circle Shooter','FontSize',20,'Color','w','Tag','opt3','HorizontalAlignment','center');
    text(.5,.35,'  Test Stick Drift / Output Sensitivities','FontSize',20,'Color','w','Tag','opt4','HorizontalAlignment','center');
    text(.5,.2,'  Back to Matlab','FontSize',20,'Color','w','Tag','opt5','HorizontalAlignment','center');
    text(.5,.05,'Tilt stick up/down to move, press down to select','FontSize',12,'Color',[.8 .8 .8],'HorizontalAlignment','center');


    sel = 1;              % Initial selection (1-4)
    updateHighlight(sel); % Highlight the initial selection
    drawnow;              % Render the menu
    pause(0.1);           % Brief pause to display menu before input

    % Joystick polling loop
    while true
        % Read joystick data from Arduino
        writeline(arduinoObj,'0');
        while arduinoObj.NumBytesAvailable == 0, end
        data = split(readline(arduinoObj),',');
        v    = str2double(data);
        rawX = v(2); btn = v(4);

        % Move selection based on joystick tilt
        if rawX < 400 && sel > 1
            sel = sel - 1; updateHighlight(sel); pause(.2);
        elseif rawX > 600 && sel < 5
            sel = sel + 1; updateHighlight(sel); pause(.2);
        end

        % Return choice on button press
        if btn == 1
            choice = sel;
            close(hFig);
            return;
        end
    end

    % Nested function to update the highlighted option
    function updateHighlight(idx)
        % Reset all options to white and remove '>'
        for k = 1:5
            h = findobj(hFig,'Tag',sprintf('opt%d',k));
            set(h,'Color','w');
            txt = strrep(h.String,'> ','  ');
            set(h,'String',txt);
        end
        % Highlight the selected option in yellow with '>'
        hCur = findobj(hFig,'Tag',sprintf('opt%d',idx));
        set(hCur,'Color','y');
        set(hCur,'String',['> ' strtrim(hCur.String)]);
    end
end