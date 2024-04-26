        function app = setupFigure(app)

            % set up figure for export

            dpi = 300;
            a4WidthInches = 8.27; % A4 width in inches
            a4HeightInches = 11.69; % A4 height in inches
            a4WidthPixels = a4WidthInches * dpi; % Convert inches to pixels
            a4HeightPixels = a4HeightInches * dpi; % Convert inches to pixels

            app.fig = figure;
            % Set figure units to pixels for on-screen size control
            set(app.fig, 'Units', 'pixels', ...
                'Position', [100, 100, a4WidthPixels, a4HeightPixels], ...
                'Visible', 'off');

            set(app.fig, 'PaperUnits', 'inches', ...
                'PaperSize', [a4WidthInches, a4HeightInches], ...
                'PaperPositionMode', 'manual','PaperPosition', [0 0 a4WidthInches a4HeightInches]);
        end