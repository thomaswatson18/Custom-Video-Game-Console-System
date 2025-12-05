function action = gameOverMenu(arduinoObj)
% gameOverMenu presents a post-game menu using Arduino joystick input
% action: 1 = Play Again, 2 = Main Menu, 3 = Back to MATLAB Command Window

    % Create figure window
    hFig = figure( ...
        'Name', 'Game Over', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Color', [0.1 0.1 0.1], ...
        'NumberTitle', 'off');
    axis off; xlim([0 1]); ylim([0 1]);

    % Display title
    text(0.5, 0.8, 'Game Over', ...
        'FontSize', 24, ...
        'FontWeight', 'bold', ...
        'Color', [1 0 0], ...
        'HorizontalAlignment', 'center');

    % Define options
    optionLabels = {'Play Again', 'Main Menu', 'Back to MATLAB'};
    numOpts = numel(optionLabels);

    % Draw options in white
    for k = 1:numOpts
        text( ...
            0.5, 0.6 - 0.2*(k-1), ...               % position
            ['  ' optionLabels{k}], ...           % leading spaces
            'FontSize', 20, ...
            'Tag', sprintf('opt%d', k), ...
            'Color', [1 1 1], ...                 % white text
            'HorizontalAlignment', 'center' ...
        );
    end

    % Initial selection
    sel = 1;
    updateHighlight(sel);
    drawnow; pause(0.2);

    % Poll joystick until selection made
    while true
        % Request joystick reading
        writeline(arduinoObj, '0');
        while arduinoObj.NumBytesAvailable == 0, end
        data = split(readline(arduinoObj), ',');
        vals = str2double(data);
        rawX = vals(2);
        btn  = vals(4);

        % Navigate left/right as up/down
        if rawX < 400 && sel > 1
            sel = sel - 1;
            updateHighlight(sel);
            pause(0.2);
        elseif rawX > 600 && sel < numOpts
            sel = sel + 1;
            updateHighlight(sel);
            pause(0.2);
        end

        % On button press: return action
        if btn == 1
            action = sel;
            close(hFig);
            return;
        end
    end

    % Nested function to update highlighting
    function updateHighlight(idx)
        % Reset all options to white and no arrow
        for ii = 1:numOpts
            h = findobj(hFig, 'Tag', sprintf('opt%d', ii));
            set(h, 'Color', [1 1 1]);                   % white
            set(h, 'String', ['  ' optionLabels{ii}]);  % no arrow
        end
        % Highlight current option in yellow with arrow
        hCur = findobj(hFig, 'Tag', sprintf('opt%d', idx));
        set(hCur, 'Color', [1 1 0]);                     % yellow
        set(hCur, 'String', ['> ' optionLabels{idx}]);  % arrow prefix
    end
end
