function hfigure = changeimcontrast(handle)
%IMCONTRAST Adjust Contrast tool.
%   IMCONTRAST creates an Adjust Contrast tool in a separate figure that is
%   associated with the grayscale image in the current figure, called the 
%   target image. The Adjust Contrast tool is an interactive contrast and 
%   brightness adjustment tool that you can use to adjust the
%   black-to-white mapping used to display the image. The tool works by
%   modifying the CLim property.
%
%   Note: The Adjust Contrast tool can handle grayscale images of class 
%   double and single with data ranges that extend beyond the default
%   display range, which is [0 1]. For these images, IMCONTRAST sets the
%   histogram limits to fit the image data range, with padding at the upper
%   and lower bounds.
%
%   IMCONTRAST(H) creates an Adjust Contrast tool associated with the image
%   specified by the handle H. H can be an image, axes, uipanel, or figure
%   handle. If H is an axes or figure handle, IMCONTRAST uses the first
%   image returned by FINDOBJ(H,'Type','image').
%
%   HFIGURE = IMCONTRAST(...) returns a handle to the Adjust Contrast tool
%   figure.
%
%   Remarks
%   -------
%   The Adjust Contrast tool presents a scaled histogram of pixel values
%   (overly represented pixel values are truncated for clarity). Dragging
%   on the left red bar in the histogram display changes the minimum value.
%   The minimum value (and any value less than the minimum) displays as
%   black. Dragging on the right red bar in the histogram changes the
%   maximum value. The maximum value (and any value greater than the
%   maximum) displays as white. Values in between the red bars display as
%   intermediate shades of gray.
%
%   Together the minimum and maximum values create a "window". Stretching
%   the window reduces contrast. Shrinking the window increases contrast.
%   Changing the center of the window changes the brightness of the image.
%   It is possible to manually enter the minimum, maximum, width, and
%   center values for the window. Changing one value automatically updates
%   the other values and the image.
%
%   Window/Level Interactivity
%   --------------------------
%   Clicking and dragging the mouse within the target image interactively
%   changes the image's window values. Dragging the mouse horizontally from
%   left to right changes the window width (i.e., contrast). Dragging the
%   mouse vertically up and down changes the window center (i.e.,
%   brightness). Holding down the CTRL key when clicking accelerates
%   changes. Holding down the SHIFT key slows the rate of change. Keys must
%   be pressed before clicking and dragging.
%
%   Example
%   -------
%
%       imshow('pout.tif')
%       imcontrast(gca)
%
%    See also IMADJUST, IMTOOL, STRETCHLIM.
% 
%   Copyright 1993-2014 The MathWorks, Inc.
% 
%  Modified by Dinesh Natesan
%  11th Aug 2016

% Do sanity checking on handles and take care of the zero-argument case.
if (nargin == 0)
    handle = get(0, 'CurrentFigure');
    if isempty(handle)
        error(message('images:common:notAFigureHandle', upper( mfilename )))
    end
end

iptcheckhandle(handle, {'figure', 'axes', 'image', 'uipanel'},...
    mfilename, 'H', 1);

[imageHandle, ~, figHandle] = imhandles(handle);

if (isempty(imageHandle))
    error(message('images:common:noImageInFigure'))
end

% Find and validate target image/axes.
imageHandle = imageHandle(1);
axHandle = ancestor(imageHandle,'axes');
imgModel = validateImage(imageHandle);

% Install pointer manager in the figure containing the target image.
iptPointerManager(figHandle);

% Display the original image.
figure(figHandle);

% Open a new figure or bring up an existing one
hFig = getappdata(axHandle, 'imcontrastFig');
if ~isempty(hFig)
    figure(hFig);
    if nargout > 0
        hfigure = hFig;
    end
    return
end

% The default display range for double images is [0 1].  This default
% setting does not work for double images that are really outside this
% range; users would not even see the draggable window on the histogram
% (g227671).  In these cases, we throw a warning and set the display range
% to include the image data range.
badDisplayRange = isDisplayRangeOutsideDataRange(imageHandle,axHandle);
if badDisplayRange
    cdata = get(imageHandle, 'CData');
    imageRange = [double(min(cdata(:))) double(max(cdata(:)))];
    response = displayWarningDialog(get(axHandle,'Clim'), imageRange);
    if strcmpi('OK',response)
        % User hit 'Ok' on adjust display range dialog.
        set(axHandle,'Clim', imageRange);
        hHistFig = createHistogramPalette(imageHandle, imgModel, handle);
    else
        % User hit 'Cancel' on adjust display range dialog.  Exit.
        hHistFig = [];
        if nargout > 0
            hfigure = hHistFig;
        end
        return
    end
else
    % Display range is valid.
    hHistFig = createHistogramPalette(imageHandle, imgModel, handle);
end

% Install pointer manager in the contrast tool figure.
iptPointerManager(hHistFig);

% Align window with target figure
iptwindowalign(figHandle, 'left', hHistFig, 'left');
iptwindowalign(figHandle, 'bottom', hHistFig, 'top');

% Display figure and return
set(hHistFig, 'visible', 'on');
if nargout > 0
    hfigure = hHistFig;
end

end % imcontrast


%============================================================
function hFig = createHistogramPalette(imageHandle, imgModel, figureHandle)

hImageAx = ancestor(imageHandle, 'axes');
hImageFig = ancestor(imageHandle, 'figure');

isCallerIMTOOL = strcmp(get(hImageFig,'tag'),'imtool');

% initializing variables for function scope
cbk_id_cell = {};
isDoubleOrSingleData = false;
[undoMenu,redoMenu,undoAllMenu,originalImagePointerBehavior,...
    hAdjustButton,editBoxAPI,scalePanelAPI,windowAPI,hStatusLabel,...
    origBtnDwnFcn,winLevelCbkStartId,winLevelCbkStopId,hFigFlow,...
    hPanelHist,histStruct,hHistAx,newClim,clipPanelAPI,editBoxAPI,...
    scalePanelAPI] = deal(gobjects(0));

% variables used for enabling keeping a history of changes
climHistory = [];
currentHistoryIndex = 0;

% boolean variable used to prevent recursing through the event handler
% and duplicate entries in the history
blockEventHandler = false;

% boolean variable used to indicate if window level operation has started
% so that we know when to save the clim.
startedWindowLevel = false;

hFig = figure('visible', 'off', ...
    'toolbar', 'none', ...
    'menubar', 'none', ...
    'IntegerHandle', 'off', ...
    'NumberTitle', 'off', ...
    'Name', createFigureName(getString(message('images:commonUIString:adjustContrast')),hImageFig), ...
    'HandleVisibility', 'callback', ...
    'units', 'pixels', ...
    'Tag','imcontrast');

suppressPlotTools(hFig);

fig_pos = get(hFig,'Position');
set(hFig,'Position',[fig_pos(1:2) 560 300]);

% keep the figure name up to date
linkToolName(hFig,hImageFig,getString(message('images:commonUIString:adjustContrast')));

setappdata(hImageAx, 'imcontrastFig', hFig);

createMenubar;

% create a blank uitoolbar to get docking arrow on the mac as a workaround
% to g222793.
if ismac
    h = uitoolbar(hFig);
end

margin = 5;
hFigFlow = uiflowcontainer('v0',...
    'Parent', hFig,...
    'FlowDirection', 'TopDown', ...
    'Margin', margin);

% Create panel that contains data range, window edit boxes, and auto
% scaling
[backgroundColor clipPanelAPI windowClipPanelWidth] = ...
    createWindowClipPanel(hFigFlow, imgModel);
editBoxAPI = clipPanelAPI.editBoxAPI;
scalePanelAPI = clipPanelAPI.scalePanelAPI;
figureWidth = windowClipPanelWidth;

% initialize tool contents
initializeContrastTool;

% adjust colors
set(hFig,'Color', backgroundColor);
iptui.internal.setChildColorToMatchParent(hPanelHist, hFig);
        
% Enable window/leveling through the mouse if not in imtool
origBtnDwnFcn = get(imageHandle, 'ButtonDownFcn');
[winLevelCbkStartId winLevelCbkStopId] = ...
    attachWindowLevelMouseActions;

% reset figure width
fig_pos = get(hFig,'Position');
set(hFig,'Position',[fig_pos(1:2) figureWidth 350]);
set(hFig, 'DeleteFcn', @closeHistFig);

% setup clim history with initial value
updateAllAndSaveInHistory(newClim);

% React to changes in target image cdata
reactToImageChangesInFig(imageHandle,hFig,@reactDeleteFcn,...
    @reactRefreshFcn);    
registerModularToolWithManager(hFig,imageHandle);


    %==============================
    function initializeContrastTool

        % set image property values
        isDoubleOrSingleData = any(strmatch(getClassType(imgModel),...
            {'double','single'}));

        % reset CLim if we are out of range
        badDisplayRange = isDisplayRangeOutsideDataRange(imageHandle,hImageAx);
        if badDisplayRange
            cdata = get(imageHandle, 'CData');
            imageRange = [double(min(cdata(:))) double(max(cdata(:)))];
            set(hImageAx,'Clim', imageRange);
        end
        newClim = getClim;
        
        % Create HistogramPanel.
        hPanelHist = imhistpanel(hFigFlow,imageHandle);
        set(hPanelHist, 'Tag','histogram panel');
        
        % Turn off HitTest of the histogram so it doesn't intercept button
        % down events - g330176,g412094
        hHistogram = findobj(hPanelHist, 'type', 'hggroup','-or',...
                                         'type','line');
        set(hHistogram, 'HitTest', 'off');
        
        % Create Draggable Clim Window on the histogram.
        hHistAx = findobj(hPanelHist,'type','axes');
        histStruct = getHistogramData(imageHandle);
        maxCounts = max(histStruct.counts);
        windowAPI = createClimWindowOnAxes(hHistAx,newClim,maxCounts);
        
        % Create Bottom Panel
        hStatusLabel = createBottomPanel(hFigFlow);
        
        setUpCallbacksOnDraggableWindow;
        setUpCallbacksOnWindowWidgets;
        setUpCallbacksOnAutoScaling;
        
        % react to changes in targe image axes clim
        setupCLimListener;
        % react to changes in targe image cdatamapping
        setupCDataMappingListener;
        
    end

    %===============================
    function reactDeleteFcn(obj,evt) %#ok<INUSD>
        if ishghandle(hFig)
            delete(hFig);
        end
    end


    %================================
    function reactRefreshFcn(~,~)
        
        % close tool if the target image cdata is empty
        if isempty(get(imageHandle,'CData'))
            reactDeleteFcn();
            return;
        end
        
        % remove old appdata
        if ~isempty(getappdata(imageHandle,'imagemodel'))
            rmappdata(imageHandle, 'imagemodel');
        end
        if ~isempty(getappdata(hFig,'ClimListener'))
            rmappdata(hFig,'ClimListener');
        end

        % refresh image model if it's valid, otherwise exit
        try
            imgModel = validateImage(imageHandle);
        catch ex %#ok<NASGU>
            reactDeleteFcn;
            return;
        end
        clipPanelAPI.updateImageModel(imgModel);
        
        % wipe old histogram data
        if ~isempty(getappdata(imageHandle,'HistogramData'))
            rmappdata(imageHandle, 'HistogramData');
        end
        
        % wipe old histogram panel and bottom panel
        delete(hPanelHist);
        hBottomPanel = findobj(hFig,'tag','bottom panel');
        delete(hBottomPanel);
        
        % create new panels and refresh tool
        initializeContrastTool;
        clearClimHistory;
        updateAllAndSaveInHistory(getClim);
        drawnow expose
    end


    %=========================
    function setupCLimListener

        % Update the window if the CLIM changes from outside the tool.
        ClimListener = iptui.iptaddlistener(hImageAx, 'CLim', ...
            'PostSet', @updateTool);
    
        %===========================
        function updateTool(~,evt)
            
            if blockEventHandler
                return
            end
            
            % Branch to account for changes to post set listener eventdata
            new_clim = get(evt.AffectedObject,'CLim');
            
            if startedWindowLevel
                updateAll(new_clim);
            else
                updateAllAndSaveInHistory(new_clim);
            end
        end
        
        setappdata(hFig, 'ClimListener', ClimListener);
        clear ClimListener;
    end


    %=================================
    function setupCDataMappingListener

        % Update the window if the CDataMapping changes.
        cdm_listener = iptui.iptaddlistener(imageHandle,'CDataMapping', ...
            'PostSet', @reactRefreshFcn);
        setappdata(hFig, 'CDataMappingListener', cdm_listener);
        clear cdm_listener;
    end


    %======================================================================
    function [winLevelCbkStartId,winLevelCbkStopId] = ...
            attachWindowLevelMouseActions

        % we want to use these flags to track the buttondown/up in all
        % contexts, including imtool so that window leveling gestures only
        % register as a single event in the imcontrast undo queue.
        winLevelCbkStartId = iptaddcallback(imageHandle,...
            'ButtonDownFcn',@winLevelStarted);
        
        winLevelCbkStopId = iptaddcallback(hImageFig,...
            'WindowButtonUpFcn',@winLevelStopped);

        if ~isCallerIMTOOL

            % Attach window/level mouse actions.
            iptaddcallback(imageHandle,...
                'ButtonDownFcn', @(hobj,evt)(windowlevel(imageHandle, hFig)));
            
            % Change the pointer to window/level when over the image.
            % Remember the original pointer behavior so we can restore it
            % later in closeHistFig.
            originalImagePointerBehavior = iptGetPointerBehavior(imageHandle);
            enterFcn = @(f,cp) set(f, 'Pointer', 'custom', ...
                'PointerShapeCData', getWLPointer,...
                'PointerShapeHotSpot',[8 8]);
            iptSetPointerBehavior(imageHandle, enterFcn);
        end
        
        %========================================
        function PointerShapeCData = getWLPointer
            iconRoot = ipticondir;
            cdata = makeToolbarIconFromPNG(fullfile(iconRoot, ...
                                                    'cursor_contrast.png'));
            PointerShapeCData = cdata(:,:,1) + 1;

        end

        %================================
        function winLevelStarted(~,~)
            startedWindowLevel = true;
        end

        %================================
        function winLevelStopped(~,~)
            startedWindowLevel = false;
        end
    end

    %===================================
    function closeHistFig(~,~)
        
        if blockEventHandler
            return;
        end
        if isappdata(hImageAx, 'imcontrastFig')
            rmappdata(hImageAx, 'imcontrastFig');
        end
        targetListeners = getappdata(hFig, 'TargetListener');
        delete(targetListeners);
        
        iptremovecallback(imageHandle, ...
            'ButtonDownFcn', winLevelCbkStartId);
        iptremovecallback(hImageFig,...
            'WindowButtonDownFcn', winLevelCbkStopId);
        
        if ~isCallerIMTOOL
            % Restore original image pointer behavior.
            iptSetPointerBehavior(imageHandle, originalImagePointerBehavior);
            % Restore original image button down function
            set(imageHandle, 'ButtonDownFcn', origBtnDwnFcn);
        end
        
        deleteCursorChangeOverDraggableObjs(cbk_id_cell);
    end

    %=====================
    function createMenubar

        filemenu = uimenu(hFig, ...
            'Label', getString(message('images:commonUIString:fileMenubarLabel')), ...
            'Tag', 'file menu');
        editmenu = uimenu(hFig, ...
            'Label', getString(message('images:commonUIString:editMenubarLabel')), ...
            'Tag', 'edit menu');

        matlab.ui.internal.createWinMenu(hFig);

        % File menu
        uimenu(filemenu, ...
            'Label', getString(message('images:commonUIString:closeMenubarLabel')), ...
            'Tag','close menu item',...
            'Accelerator', 'W', ...
            'Callback', @(varargin) close(hFig));

        % Edit menu
        undoMenu = uimenu(editmenu, ...
            'Label', getString(message('images:imcontrastUIString:undoMenubarLabel')), ...
            'Accelerator', 'Z', ...
            'Tag', 'undo menu item', ...
            'Callback', @undoLastChange);
        redoMenu = uimenu(editmenu, ...
            'Label', getString(message('images:imcontrastUIString:redoMenubarLabel')), ...
            'Accelerator', 'Y', ...
            'Tag', 'redo menu item', ...
            'Callback',@redoLastUndo);
        undoAllMenu = uimenu(editmenu, ...
            'Label', getString(message('images:imcontrastUIString:undoAllMenubarLabel')), ...
            'Separator', 'on', ...
            'Tag', 'undo all menu item', ...
            'Callback', @undoAllChanges);

        % Help menu
        if ~isdeployed
            helpmenu = uimenu(hFig, ...
                'Label', getString(message('images:commonUIString:helpMenubarLabel')), ...
                'Tag', 'help menu');
            
            invokeHelp = @(varargin) ...
                helpview([docroot '/toolbox/images/images.map'],'imtool_imagecontrast_help');
            
            uimenu(helpmenu, ...
                'Label', getString(message('images:imcontrastUIString:adjustContrastHelpMenubarLabel')), ...
                'Tag', 'help menu item', ...
                'Callback', invokeHelp);
            iptstandardhelp(helpmenu);
        end
    end % createMenubar

    %=======================================
    function setUpCallbacksOnDraggableWindow

        buttonDownTable = {
            windowAPI.centerLine.handle  @centerPatchDown;
            windowAPI.centerPatch.handle @centerPatchDown;
            windowAPI.maxLine.handle     @minMaxLineDown;
            windowAPI.minLine.handle     @minMaxLineDown;
            windowAPI.minPatch.handle    @minMaxPatchDown;
            windowAPI.maxPatch.handle    @minMaxPatchDown;
            windowAPI.bigPatch.handle    @bigPatchDown
            };

        for k = 1 : size(buttonDownTable,1)
            h = buttonDownTable{k,1};
            callback = buttonDownTable{k,2};
            set(h, 'ButtonDownFcn', callback);
        end

        draggableObjList = [buttonDownTable{1:end-1,1}];
        cbk_id_cell = initCursorChangeOverDraggableObjs(hFig, draggableObjList);

        %====================================
        function minMaxLineDown(src,varargin)

            if src == windowAPI.maxLine.handle
                isMaxLine = true;
            else
                isMaxLine = false;
            end
            
            idButtonMotion = iptaddcallback(hFig, 'WindowButtonMotionFcn', ...
                                            @minMaxLineMove);
            idButtonUp = iptaddcallback(hFig, 'WindowButtonUpFcn', ...
                @minMaxLineUp);
            
            % Disable pointer manager.
            iptPointerManager(hFig, 'disable');

            %==============================
            function minMaxLineUp(varargin)

                acceptChanges(idButtonMotion, idButtonUp);
            end

            %====================================
            function minMaxLineMove(~,varargin)

                xpos = getCurrentPoint(hHistAx);
                if isMaxLine
                    newMax = xpos;
                    newMin = windowAPI.minLine.get();
                else
                    newMin = xpos;
                    newMax = windowAPI.maxLine.get();
                end
                newClim = validateClim([newMin newMax]);
                if isequal(newClim(1), xpos) || isequal(newClim(2), xpos)
                    updateAll(newClim);
                end
            end
        end %lineButtonDown

        %=================================
        function centerPatchDown(varargin)

            idButtonMotion = iptaddcallback(hFig, 'WindowButtonMotionFcn', ...
                                            @centerPatchMove);
            idButtonUp = iptaddcallback(hFig, 'WindowButtonUpFcn', @centerPatchUp);

            % Disable pointer manager.
            iptPointerManager(hFig, 'disable');

            startX = getCurrentPoint(hHistAx);
            oldCenterX = windowAPI.centerLine.get();

            %===============================
            function centerPatchUp(varargin)
                
                acceptChanges(idButtonMotion, idButtonUp);
            end

            %=================================
            function centerPatchMove(varargin)

                newX = getCurrentPoint(hHistAx);
                delta = newX - startX;

                % Set the window endpoints.
                centerX = oldCenterX + delta;
                minX = windowAPI.minLine.get();
                maxX = windowAPI.maxLine.get();
                width = maxX - minX;
                [newMin, newMax] = computeClim(width, centerX);
                newClim = validateClim([newMin newMax]);
                updateAll(newClim);
            end
        end %centerPatchDown

        %======================================
        function minMaxPatchDown(src, varargin)

            if isequal(src, windowAPI.minPatch.handle)
                srcLine = windowAPI.minLine;
                minPatchMoved = true;
            else
                srcLine = windowAPI.maxLine;
                minPatchMoved = false;
            end

            startX = getCurrentPoint(hHistAx);
            oldX = srcLine.get();
            
            idButtonMotion = iptaddcallback(hFig, 'WindowButtonMotionFcn', ...
                                            @minMaxPatchMove);
            idButtonUp = iptaddcallback(hFig, 'WindowButtonUpFcn', ...
                @minMaxPatchUp);

            % Disable pointer manager.
            iptPointerManager(hFig, 'disable');

            %===============================
            function minMaxPatchUp(varargin)

                acceptChanges(idButtonMotion, idButtonUp);
            end

            %======================================
            function minMaxPatchMove(~, varargin)

                newX = getCurrentPoint(hHistAx);
                delta = newX - startX;

                % Set the window endpoints.
                if minPatchMoved
                    minX = oldX + delta;
                    maxX = windowAPI.maxLine.get();
                else
                    maxX = oldX + delta;
                    minX = windowAPI.minLine.get();
                end
                newClim = validateClim([minX maxX]);
                updateAll(newClim);
            end
        end %minMaxPatchDown

        %==============================
        function bigPatchDown(varargin)

            idButtonMotion = iptaddcallback(hFig, 'windowButtonMotionFcn', ...
                                            @bigPatchMove);
            idButtonUp = iptaddcallback(hFig, 'WindowButtonUpFcn', @bigPatchUp);

            % Disable pointer manager.
            iptPointerManager(hFig, 'disable');

            startX = get(hHistAx, 'CurrentPoint');
            oldMinX = windowAPI.minLine.get();
            oldMaxX = windowAPI.maxLine.get();

            %============================
            function bigPatchUp(varargin)
                
                acceptChanges(idButtonMotion, idButtonUp);
            end

            %===========================
            function bigPatchMove(varargin)

                newX = getCurrentPoint(hHistAx);
                delta = newX(1) - startX(1);

                % Set the window endpoints.
                newMin = oldMinX + delta;
                newMax = oldMaxX + delta;

                % Don't let window shrink when dragging the window patch.
                origWidth = getWidthOfWindow;
                histRange = histStruct.histRange;
                
                if newMin < histRange(1)
                    newMin = histRange(1);
                    newMax = newMin + origWidth;
                end

                if newMax > histRange(2)
                    newMax = histRange(2);
                    newMin = newMax - origWidth;
                end
                newClim = validateClim([newMin newMax]);
                updateAll(newClim);
            end
        end %bigPatchDown
    
        %=================================================
        function acceptChanges(idButtonMotion, idButtonUp)
            
           iptremovecallback(hFig, 'WindowButtonMotionFcn', idButtonMotion);
           iptremovecallback(hFig, 'WindowButtonUpFcn', idButtonUp);
           
           % Enable the figure's pointer manager.
           iptPointerManager(hFig, 'enable');
           
           updateAllAndSaveInHistory(getClim);
           
        end
        
        %================================
        function width = getWidthOfWindow
            width = editBoxAPI.widthEdit.get();
        end

    end % setUpCallbacksOnDraggableWindow

    %=====================================
    function setUpCallbacksOnWindowWidgets

        callbackTable = {
            editBoxAPI.centerEdit  @actOnCenterChange;
            editBoxAPI.widthEdit   @actOnWidthChange;
            editBoxAPI.maxEdit     @actOnMinMaxChange;
            editBoxAPI.minEdit     @actOnMinMaxChange;
            };
        
        for m = 1 : size(callbackTable,1)
            h = callbackTable{m,1}.handle;
            callback = callbackTable{m,2};
            set(h, 'Callback', callback);
        end

        eyedropperAPI = clipPanelAPI.eyedropperAPI;
        droppers = [eyedropperAPI.minDropper.handle ...
                    eyedropperAPI.maxDropper.handle]; 
        set(droppers, 'callback', @eyedropper);

        %===================================
        function actOnMinMaxChange(varargin)

            areEditBoxStringsValid = checkEditBoxStrings;
            if areEditBoxStringsValid
                newMax = editBoxAPI.maxEdit.get();
                newMin = editBoxAPI.minEdit.get();
                [newClim] = validateClim([newMin newMax]);
                updateAllAndSaveInHistory(newClim);
            else
                resetEditValues;
                return;
            end
        end

        %==================================
        function actOnWidthChange(varargin)

            areEditBoxStringsValid = checkEditBoxStrings;
            if areEditBoxStringsValid
                centerValue = editBoxAPI.centerEdit.get();
                widthValue = editBoxAPI.widthEdit.get();

                [newMin newMax] = computeClim(widthValue, centerValue);
                newClim = validateClim([newMin newMax]); 
                
                % do not allow the center to move on width changes
                newCenter = mean(newClim);
                newWidth = diff(newClim);
                diffCenter = newCenter - centerValue;
                if diffCenter ~= 0
                    widthValue = newWidth - 2 * abs(diffCenter);
                    [newMin newMax] = computeClim(widthValue, centerValue);
                    newClim = validateClim([newMin newMax]);
                end
                
                updateAllAndSaveInHistory(newClim);
            else
                resetEditValues;
                return
            end
        end

        %===================================
        function actOnCenterChange(varargin)

            areEditBoxStringsValid = checkEditBoxStrings;
            if areEditBoxStringsValid
                centerValue = editBoxAPI.centerEdit.get();
                widthValue = editBoxAPI.widthEdit.get();
                [newMin newMax] = computeClim(widthValue, centerValue);
                XLim = get(hHistAx,'XLim');

                % React to a center change that makes the newMin or 
                % newMax go outside of the XLim, but keep the center 
                % that the user requested.
                if ((newMin < XLim(1)) && (newMax > XLim(2)))
                    newMin = XLim(1);
                    newMax = XLim(2);
                elseif (newMin < XLim(1))
                    newMin = XLim(1);
                    newMax = newMin + 2 * (centerValue - newMin);
                elseif (newMax > XLim(2))
                    newMax = XLim(2);
                    newMin = newMax - 2 * (newMax - centerValue);
                end
                newClim = validateClim([newMin newMax]);
                
                % make sure our center value is not adjusted based on the
                % buffer in the axes xlim
                newCenter = mean(newClim);
                newWidth = diff(newClim);
                diffCenter = newCenter - centerValue;
                if diffCenter ~= 0
                    widthValue = newWidth - 2 * abs(diffCenter);
                    [newMin newMax] = computeClim(widthValue, centerValue);
                    newClim = validateClim([newMin newMax]);
                end
                
                updateAllAndSaveInHistory(newClim);
            else
                resetEditValues;
                return
            end
        end

        %=======================
        function resetEditValues

            Clim = getClim;
            for k = 1 : size(callbackTable,1)
                callbackTable{k,1}.set(Clim);
            end
        end

        %=================================
        function eyedropper(src, varargin)

            if isequal(src, eyedropperAPI.minDropper.handle)
                editBox = editBoxAPI.minEdit;
                dropper = eyedropperAPI.minDropper;
            else
                editBox = editBoxAPI.maxEdit;
                dropper = eyedropperAPI.maxDropper;
            end

            % Prevent uicontrols from issuing callbacks before dropper is done.
            parent = ancestor(editBox.handle, 'uiflowcontainer', 'toplevel');
            children = findall(parent, 'Type', 'uicontrol');
            origEnable = get(children, 'Enable');
            set(children, 'Enable', 'off');

            % W/L mouse action sometimes conflicts afterward.  Turn it off briefly.
            origBDF = get(imageHandle, 'ButtonDownFcn');
            set(imageHandle, 'ButtonDownFcn', '');

            % Change the pointer to an eyedropper over the image.
            origPointerBehavior = iptGetPointerBehavior(imageHandle);
            enterFcn = @(f,cp) set(f, 'Pointer', 'custom', ...
                                      'PointerShapeCData', ...
                                      getEyedropperPointer(dropper.get), ...
                                      'PointerShapeHotSpot', [16 1]);
            iptSetPointerBehavior(imageHandle, enterFcn);

            % Change the status text.
            origMsg = get(hStatusLabel, 'string');
            if(strcmp(dropper.get,'minimum'))
                set(hStatusLabel, 'string', getString(message('images:imcontrastUIString:minimalStatusText')));
            else
                % maximal
                set(hStatusLabel, 'string', getString(message('images:imcontrastUIString:maximalStatusText')));
            end
            set(hStatusLabel, 'Enable', 'on');
            % Take care to undo all of these actions if the 
            % adjustment tool closes.
            origCloseRequestFcn = get(hFig, 'CloseRequestFcn');
            set(hFig, 'CloseRequestFcn', @closeDuringEyedropper)

            value = graysampler(imageHandle);

            % Set the edit text box.
            if ~isempty(value)
                editBox.set([value value]);
                areValid = checkEditBoxStrings;

                if areValid
                    newClim = [editBoxAPI.minEdit.get(), ...
                               editBoxAPI.maxEdit.get()];
                    newClim = validateClim(newClim);
                    updateAllAndSaveInHistory(newClim);
                else
                    resetEditValues;
                end
            end

            undoEyedropperChanges;
            
            % we manually call the "climChanged" listener function here to
            % make sure our 'Adjust Data' button label is updated if the
            % undoEyedropperChanges function blew away a valid update
            if ~isempty(value)
                climChanged;
            end
            
            %=====================================================
            function PointerShapeCData = getEyedropperPointer(tag)

                iconRoot = ipticondir;
                if strcmp(tag,'minimum')
                    cursor_filename = fullfile(iconRoot, ...
                                               'cursor_eyedropper_black.png');
                else
                    cursor_filename = fullfile(iconRoot, ...
                                               'cursor_eyedropper_white.png');
                end

                cdata = makeToolbarIconFromPNG(cursor_filename);
                PointerShapeCData = cdata(:,:,1)+1;
            end

            %=============================
            function undoEyedropperChanges

                % Change the pointer back.
                if ishghandle(imageHandle)
                    iptSetPointerBehavior(imageHandle, origPointerBehavior);
                    
                    % Force pointer manager update.
                    iptPointerManager(ancestor(imageHandle, 'figure'));
                end

                % Change the message back.
                if ishghandle(hStatusLabel)
                    set(hStatusLabel, 'string', origMsg);
                end

                % Turn the W/L mouse action back on if necessary.
                if ishghandle(imageHandle)
                    set(imageHandle, 'ButtonDownFcn', origBDF);
                end

                % Reenable other uicontrols.
                for p = 1:numel(origEnable)
                    if ishghandle(children(p))
                        set(children(p), 'Enable', origEnable{p});
                    end
                end
            end

            %=======================================
            function closeDuringEyedropper(varargin)

                undoEyedropperChanges;
                if ((~isempty(origCloseRequestFcn)) && ...
                        (~isequal(origCloseRequestFcn, 'closereq')))
                    feval(origCloseRequestFcn);
                end

                if ishghandle(hFig)
                    delete(hFig)
                end
            end

        end %eyedropper
        
        %======================================
        function areValid = checkEditBoxStrings

            centerValue = editBoxAPI.centerEdit.get();
            maxValue    = editBoxAPI.maxEdit.get();
            minValue    = editBoxAPI.minEdit.get();
            widthValue  = editBoxAPI.widthEdit.get();

            areValid = true;

            % Validate data.
            % - If invalid: display dialog, reset to last good value, stop.
            % - If valid: go to other callback processor.
            isValueEmpty = any([isempty(minValue), isempty(maxValue),...
                isempty(widthValue), isempty(centerValue)]);

            isValueString = any([ischar(minValue), ischar(maxValue),...
                ischar(widthValue), ischar(centerValue)]);

            isValueNonScalar = (numel(minValue) + numel(maxValue) +...
                numel(widthValue) + numel(centerValue) ~= 4);

            if (isValueEmpty || isValueString || isValueNonScalar)

                areValid = false;
                errordlg({getString(message('images:imcontrastUIString:invalidWindowValueDlgText'))}, ...
                    getString(message('images:imcontrastUIString:invalidWindowValueDlgTitle')), ...
                    'modal')

            elseif (minValue >= maxValue)

                areValid = false;
                errordlg(getString(message('images:imcontrastUIString:minValueLessThanMaxDlgText')), ...
                    getString(message('images:imcontrastUIString:invalidWindowValueDlgTitle')), ...
                    'modal')

            elseif (((widthValue < 1) && (~isDoubleOrSingleData)) || ...
                    (widthValue <= 0))

                areValid = false;
                errordlg(getString(message('images:imcontrastUIString:windowWidthGreaterThanZeroDlgText')), ...
                    getString(message('images:imcontrastUIString:invalidWindowValueDlgTitle')), ...
                    'modal')

            elseif ((floor(centerValue * 2) ~= centerValue * 2) && (~isDoubleOrSingleData))

                areValid = false;
                errordlg(getString(message('images:imcontrastUIString:windowCenterIntegerDlgText')), ...
                    getString(message('images:imcontrastUIString:invalidWindowValueDlgTitle')), ...
                    'modal')
            end
        end % validateEditBoxStrings

    end % setUpCallbacksOnWindowWidgets

    %===================================
    function setUpCallbacksOnAutoScaling
    
        callbackTable = {
            scalePanelAPI.elimRadioBtn       @changeScaleDisplay;
            scalePanelAPI.matchDataRangeBtn  @changeScaleDisplay;
            scalePanelAPI.scaleDisplayBtn    @autoScaleApply
            scalePanelAPI.percentEdit        @autoScaleApply;
        };
        
        for k = 1 : size(callbackTable,1)
            h = callbackTable{k,1}.handle;
            callback = callbackTable{k,2};
            set(h,'Callback', callback);
        end
        
        set(scalePanelAPI.percentEdit.handle, ...
            'ButtonDownFcn', @changeScaleDisplay, ...
            'KeyPressFcn', @changeScaleDisplay);

        % make matchDataRangeBtn selected by default.
        scalePanelAPI.matchDataRangeBtn.set(true);
        scalePanelAPI.elimRadioBtn.set(false);
        
        %========================================
        function changeScaleDisplay(src, varargin)

            if isequal(src, scalePanelAPI.matchDataRangeBtn.handle)
                scalePanelAPI.matchDataRangeBtn.set(true);
                scalePanelAPI.elimRadioBtn.set(false);
            else
                scalePanelAPI.matchDataRangeBtn.set(false);
                scalePanelAPI.elimRadioBtn.set(true);
            end
        end

        %================================
        function autoScaleApply(varargin)

            % Verify the percent and use it if box is checked.
            outlierPct = scalePanelAPI.percentEdit.get();

            matchDataRange = ...
                isequal(scalePanelAPI.matchDataRangeBtn.get(), true);

            CData = get(imageHandle, 'CData');
            minCData = min(CData(:));
            maxCData = max(CData(:));

            if matchDataRange

                localNewClim = [double(minCData) double(maxCData)];
                
            else
                % eliminate Outliers. 
                if isempty(outlierPct) || outlierPct > 100 || outlierPct < 0
                    errordlg({getString(message('images:imcontrastUIString:percentageOutOfRangeText'))}, ...
                        getString(message('images:imcontrastUIString:percentageOutOfRangeTitle')), ...
                        'modal')
                    scalePanelAPI.percentEdit.set('2');
                    return;
                end

                outlierPct = outlierPct / 100;

                % Double image data not in default range must be scaled and
                % shifted to the range [0,1] for STRETCHLIM to do 
                % the right thing.
                doubleImageOutsideDefaultRange = isDoubleOrSingleData && ...
                    (minCData < 0 || maxCData > 1);

                if doubleImageOutsideDefaultRange
                    % Keep track of old CData range for reconversion.
                     CData = mat2gray(CData);
                end

                localNewClim = stretchlim(CData, outlierPct / 2);

                if isequal(localNewClim, [0;1])
                    if outlierPct > 0.02
                        errordlg({getString(message('images:imcontrastUIString:percentageTooGreatTextLine1')), ...
                            getString(message('images:imcontrastUIString:percentageTooGreatTextLine2'))}, ...
                            getString(message('images:imcontrastUIString:percentageTooGreatTitle')), ...
                            'modal')
                        return;
                    elseif outlierPct ~= 0
                        errordlg({getString(message('images:imcontrastUIString:cannotEliminateOutliersLine1')),...
                            getString(message('images:imcontrastUIString:cannotEliminateOutliersLine2'))},...
                            getString(message('images:imcontrastUIString:cannotEliminateOutliersTitle')),...
                            'modal')
                         return;
                    end
                end
                   
                % Scale the Clim from STRETCHLIM's [0,1] to match the range
                % of the data.
                if ~isDoubleOrSingleData
                    imgClass = class(CData);
                    localNewClim = double(intmax(imgClass)) * localNewClim;
                elseif doubleImageOutsideDefaultRange
                    localNewClim = localNewClim * (maxCData - minCData);
                    localNewClim = localNewClim + minCData;
                end
            end

            newClim = validateClim(localNewClim);
            updateAllAndSaveInHistory(newClim);

        end % autoScaleApply
    end % setUpCallbacksOnAutoScaling

    %====================================
    function newClim = validateClim(clim)

        % Prevent new endpoints from exceeding the min and max of the
        % histogram range, which is a little less than the xlim endpoints.
        % Don't want to get to the actual endpoints because there is a
        % problem with the painters renderer and patchs at the edge
        % (g298973).  histStruct is a variable calculated in the beginning
        % of createHistogramPalette.
        histRange = histStruct.histRange;
        newMin = max(clim(1), histRange(1));
        newMax = min(clim(2), histRange(2));
            
        if ~isDoubleOrSingleData
            % If the image has an integer datatype, don't allow the new endpoints
            % to exceed the min or max of that datatype.  For example, We don't
            % want to allow this because it wouldn't make sense to set the clim
            % of a uint8 image beyond 255 or less than 0.
            minOfDataType = double(intmin(getClassType(imgModel)));
            maxOfDataType = double(intmax(getClassType(imgModel)));
            newMin = max(newMin, minOfDataType);
            newMax = min(newMax, maxOfDataType);
        end
        
        % Keep min < max
        if ( ((newMax - 1) < newMin) && ~isDoubleOrSingleData )

            % Stop at limiting value.
            Clim = getClim;
            newMin = Clim(1);
            newMax = Clim(2);

            %Made this less than or equal to as a possible workaround to g226780
        elseif ( (newMax <= newMin) && isDoubleOrSingleData )

            % Stop at limiting value.
            Clim = getClim;
            newMin = Clim(1);
            newMax = Clim(2);
        end

        newClim = [newMin newMax];
    end


    %================================================
    function hStatusLabel = createBottomPanel(parent)

        hBottomPanel = uipanel('Parent', parent, ...
            'Units', 'pixels', ...
            'Tag', 'bottom panel',...
            'BorderType', 'none');
        
        buttonText = getString(message('images:imcontrastUIString:adjustDataButtonText'));
        
        % Status Label
        if isCallerIMTOOL
            defaultMessage = sprintf('%s\n%s', ...
                getString(message('images:imcontrastUIString:adjustTheHistogramAbove')),...
                getString(message('images:imcontrastUIString:clickToAdjust',buttonText)));
        else
            defaultMessage = sprintf('%s\n%s', ...
                getString(message('images:imcontrastUIString:adjustTheHistogramAboveNotImtool')),...
                getString(message('images:imcontrastUIString:clickToAdjust',buttonText)));
        end
        hStatusLabel = uicontrol('parent', hBottomPanel, ...
            'units', 'pixels', ...
            'tag', 'status text',...
            'style', 'text', ...
            'HorizontalAlignment', 'left', ...
            'string', defaultMessage);

        labelExtent = get(hStatusLabel, 'extent');
        labelWidth = labelExtent(3);
        labelHeight = labelExtent(4);
        set(hStatusLabel, 'Position', [1 1 labelWidth labelHeight]);
        set(hBottomPanel, 'HeightLimits', ...
                          [labelHeight labelHeight]);

        % Adjust Data Button
        hDummyText = uicontrol('Parent',hBottomPanel,...
            'units','pixels',...
            'style','text',...
            'visible','off',...
            'string',buttonText);

        textExtent = get(hDummyText, 'extent');
        buttonWidth = textExtent(3) + 30;
        buttonHeight = textExtent(4) + 10;
        
        delete(hDummyText);
        
        hAdjustButton = uicontrol('Style', 'pushbutton',...
            'String',buttonText,...
            'Tag','adjust data button',...
            'Parent',hBottomPanel,...
            'Enable','off',...
            'Callback',@adjustButtonCallback);
        
        % Call 'climChanged' listener function manually to update the 
        % state of the 'Adjust Data' button, when the axis clim value 
        % differs from the original data range.  
        histRange = histStruct.histRange;
        imageAxClim = get(hImageAx,'CLim');
        if ~isequal(histRange,imageAxClim)
            climChanged;
        end
                
        % enable the button on changes to axes clim
        setappdata(hAdjustButton,'climListener',...
            iptui.iptaddlistener(hImageAx, 'CLim',...
            'PostSet', @climChanged));
        
        % Keep the button on the right
        set(hBottomPanel,'ResizeFcn',@adjustButtonPosition);

        %=====================================
        function [adjustValues] = adjustButtonCallback(~,~)
            % get original image data
            origCData = get(imageHandle,'CData');
            defaultRange = getrangefromclass(origCData);

            % find new min and max
            clim = get(hImageAx,'Clim');

            % apply contrast adjustment
            newCData = localAdjustData(origCData, clim(1), clim(2), ...
                defaultRange);
            
            % restore image display range to default
            set(hImageAx,'CLim',defaultRange)
            
            % update image data
            set(imageHandle,'CData',newCData)
            
            
            % added by Dinesh
            % Save the adjusted values
            adjustValues.newmin = clim(1);
            adjustValues.newmax = clim(2);
            adjustValues.defaultRange = defaultRange;            
            setappdata(figureHandle, 'adjustValues', adjustValues);
            
            % Explicitly create an image model for the image.
            imgModel = getimagemodel(imageHandle);
       
            % Set original class type of imgmodel before image object is created.
            setImageOrigClassType(imgModel,class(newCData));
            
        end % adjustButtonCallback

        %=====================================
        function adjustButtonPosition(obj,~)
            current_position = getpixelposition(obj);
            adjustButtonLeft = current_position(3) - buttonWidth;
            adjustButtonLeft = fixLeftPosIfOnMac(adjustButtonLeft);
            set(hAdjustButton,'Position',[adjustButtonLeft 1 buttonWidth buttonHeight]);
            
            %======================================
            function left = fixLeftPosIfOnMac(left)
                % need to move the panel over a little on the mac so that the mac 
                % resize widget doesn't obstruct view.
                if ismac
                    left = left - 7;
                end
            end

        end % adjustButtonPosition
        
    end % createBottomPanel

    %============================
    function climChanged(~,~)
        histRange = histStruct.histRange;
        % the image could have been closed here
        if ishghandle(hImageAx)
            new_clim = get(hImageAx,'CLim');
            if ~isequal(histRange,new_clim)
                set(hAdjustButton,'Enable','on');
            else
                set(hAdjustButton,'Enable','off');
            end
        end
    end

    %======================
    function updateEditMenu
    
        % enable the undo menus when the clim gets its first change
        if currentHistoryIndex == 2
            set([undoMenu, undoAllMenu], 'Enable', 'on');
        elseif currentHistoryIndex == 1
            set([undoMenu, undoAllMenu], 'Enable', 'off');
        end

        % enable the redo menu when the length of the history is greater
        % than the current index
        historyLength = size(climHistory, 1);
        if historyLength > currentHistoryIndex
            set(redoMenu, 'Enable', 'on');
        elseif historyLength == currentHistoryIndex
            set(redoMenu, 'Enable', 'off');
        end
    end % updateEditMenu

    %===============================
    function undoLastChange(~,~)
        currentHistoryIndex = max(1,  currentHistoryIndex - 1);
        updateAll(climHistory(currentHistoryIndex,:));
        updateEditMenu
    end

    %=============================
    function redoLastUndo(~,~)
        historyLength = size(climHistory, 1);
        currentHistoryIndex = min(historyLength, currentHistoryIndex + 1);
        updateAll(climHistory(currentHistoryIndex,:));
        updateEditMenu
    end

    %===============================
    function undoAllChanges(~,~)
        currentHistoryIndex = 1;
        updateAll(climHistory(currentHistoryIndex,:));
        updateEditMenu
    end

    %==========================
    function clearClimHistory()
        climHistory = [];
        currentHistoryIndex = 0;
    end

    %==========================================
    function updateAllAndSaveInHistory(newClim)
        % get the length of entries in the history
        historyLength = size(climHistory,1);

        % increment current index by one to indicate the new entry's
        % position.
        currentHistoryIndex = currentHistoryIndex + 1;

        % if the length of entries in the history is longer that the
        % current index we discard all entries after the current index.
        if historyLength > currentHistoryIndex
            climHistory(currentHistoryIndex,:) = [];
        end
        climHistory(currentHistoryIndex,:) = [newClim(1), newClim(2)];

        updateAll(newClim);
        updateEditMenu;
    end

    %==========================
    function updateAll(newClim)

        % Update edit boxes with new values.
        updateEditBoxes(newClim);

        % Update patch display.
        updateHistogram(newClim);

        % we don't want the clim event handler executed to prevent
        % duplicate entries in the history.
        blockEventHandler = true;

        % Update image Clim.
        updateImage(hImageAx, newClim);

        blockEventHandler = false;
    end

    %===============================
    function updateEditBoxes(newClim)
    
        names = fieldnames(editBoxAPI);
        for k = 1 : length(names)
            editBoxAPI.(names{k}).set(newClim);
        end
    end 

    %================================
    function updateHistogram(newClim)

        names = fieldnames(windowAPI);
        for k = 1 : length(names)
            windowAPI.(names{k}).set(newClim);
        end
    end % updateHistogram

    %===================================
    function updateImage(hImageAx, clim)

        if clim(1) >= clim(2)
            error(message('images:imcontrast:internalError'))
        end
        set(hImageAx, 'clim', clim);
    end

    %======================
    function clim = getClim
        clim = get(hImageAx,'Clim');
    end

end % createHistogramPalette

%=========================================================
function [minPixel, maxPixel] = computeClim(width, center)
%FINDWINDOWENDPOINTS   Process window and level values.

minPixel = (center - width/2);
maxPixel = minPixel + width;

end

%=====================================
function imgModel = validateImage(hIm)

imgModel = getimagemodel(hIm);
if ~strcmp(getImageType(imgModel),'intensity')
  error(message('images:imcontrast:unsupportedImageType'))
end

cdata = get(hIm,'cdata');
if isempty(cdata)
    error(message('images:imcontrast:invalidImage'))
end

end

%==========================================================================
function cbk_id_cell = initCursorChangeOverDraggableObjs(client_fig, drag_objs)
% initCursorChangeOverDraggableObjs

% initialize variables for function scope
num_of_drag_objs    = numel(drag_objs);

enterFcn = @(f,cp) setptr(f, 'lrdrag');
iptSetPointerBehavior(drag_objs, enterFcn);

% Add callback to turn on flag indicating that dragging has stopped.
stop_drag_cbk_id = iptaddcallback(client_fig, ...
    'WindowButtonUpFcn', @stopDrag);

obj_btndwn_fcn_ids = zeros(1, num_of_drag_objs);

% Add callback to turn on flag indicating that dragging has started
for n = 1 : num_of_drag_objs
    obj_btndwn_fcn_ids(n) = iptaddcallback(drag_objs(n), ...
        'ButtonDownFcn', @startDrag);
end

cbk_id_cell = {client_fig, 'WindowButtonUpFcn', stop_drag_cbk_id;...
    drag_objs,  'ButtonDownFcn', obj_btndwn_fcn_ids};


    %==========================
    function startDrag(~,~)
        % Disable the pointer manager while dragging.
        iptPointerManager(client_fig, 'disable');
    end

    %========================
    function stopDrag(~,~)
        % Enable the pointer manager.
        iptPointerManager(client_fig, 'enable');
    end

end % initCursorChangeOverDraggableObjs


%==========================================================================
function deleteCursorChangeOverDraggableObjs(cbk_id)

rows = size(cbk_id);
for n = 1 : rows
    id_length = length(cbk_id{n,1});
    for m = 1 : id_length
        iptremovecallback(cbk_id{n,1}(m), cbk_id{n,2}, cbk_id{n,3}(m));
    end
end
end % deleteCursorChangeOverDraggableObjs


%===========================================================================
function wdlg = displayWarningDialog(curClim, imDataLim)

formatValue = @(v) sprintf('%0.0f', v);

str{1}= getString(message('images:imcontrastUIString:outOfRangeWarn',...
        formatValue(curClim(1)),...
        formatValue(curClim(2)),...
        formatValue(imDataLim(1)),...
        formatValue(imDataLim(2))));
    
lastLineStr = strcat('\n',getString(message('images:imcontrastUIString:outOfRangeLastLine')));
        
str{2} = sprintf(lastLineStr);
wdlg = questdlg(str, ...
    getString(message('images:imcontrastUIString:invalidDisplayRange')),...
    getString(message('images:commonUIString:ok')),...
    getString(message('images:commonUIString:cancel')),...
    getString(message('images:commonUIString:ok')));
end

%==========================================================
function badValue = isDisplayRangeOutsideDataRange(him,hax)

% Checking to see if the display range is outside the image's data range.
clim = get(hax,'Clim');
histStruct = getHistogramData(him);
histRange = histStruct.histRange;
badValue = false;

if clim(1) < histRange(1) || clim(2) > histRange(2)
    badValue = true;
end

end


%=======================================================================
function newCData = localAdjustData(cData, newMin, newMax, defaultRange)

% translate to the new min to "zero out" the data
newCData = cData - newMin;

% apply a linear stretch of the data such that the selected data range
% spans the entire default data range
scaleFactor = (defaultRange(2)-defaultRange(1)) / (newMax-newMin);
newCData = newCData .* scaleFactor;

% translate data to the appropriate lower bound of the default data range.
% this translation is here in anticipation of image datatypes in the future
% with signed data, such as int16
newCData = newCData + defaultRange(1);

% clip all data that falls outside the default range
newCData(newCData < defaultRange(1)) = defaultRange(1);
newCData(newCData > defaultRange(2)) = defaultRange(2);

end

%% Dependent functions
function histDataStruct = getHistogramData(hImage)
% GETHISTOGRAMDATA Returns data needed to create the image histogram.
%   The fields inside of HISTDATASTRUCT are:
%     histRange      Histogram Range
%     finalBins      Bin locations
%     counts         Histogram counts
%     nBins          Number of bins
%
%

%   Copyright 2005-2008 The MathWorks, Inc.


%  This function is called IMCONTRAST, WINDOWLEVEL, and IMHISTPANEL.


if isappdata(hImage, 'HistogramData')
    histDataStruct = getappdata(hImage, 'HistogramData');

else
    [hrange, fbins, cnts, numbins] = computeHistogramData(hImage);
    histDataStruct.histRange = hrange;
    histDataStruct.finalBins = fbins;
    histDataStruct.counts    = cnts;
    histDataStruct.nbins     = numbins;

    setappdata(hImage,'HistogramData', histDataStruct);

    % Attach listeners to remove the HISTOGRAM data when the following
    % image properties change:
    %  * CData
    %  * CDataMapping
    CdataListener = iptui.iptaddlistener(hImage, 'CData',...
        'PostSet', @removeHistogramData);

    CdataMappingListener = iptui.iptaddlistener(hImage, 'CDataMapping',...
        'PostSet', @removeHistogramData);

    % We are storing the listeners in the image handle object because the
    % caller of this function could be a tool in a separate figure or a
    % tool in the target figure.
    setappdata(hImage,...
        'ImagePropertyListener',[CdataListener, CdataMappingListener]);
    % clear unused references to listeners
    clear CdataListener CdataMappingListener;
end

    %====================================
    function removeHistogramData(varargin)
        rmappdata(hImage, 'HistogramData');
        rmappdata(hImage, 'ImagePropertyListener');
    end % removeHistogramData

end % getHistogramData

%==========================================================================
function [histRange, finalBins, counts, nbins] = computeHistogramData(hIm)
% This function does the actual computation

X = get(hIm,'CData');

xMin = min(X(:));
xMax = max(X(:));
origRange = xMax - xMin;

% Compute Histogram for the image.  The Xlim([minX maxX]) is based on either the
% range of the class or the data range of the image.  In addition, we have to
% consider that users may need "wiggle room" in the xlim.  For example, customers
% may be working on images that have data ranges that are smaller than the display
% range. They may use the tool on several images to come up with a clim range  
% that works for all cases.

cdataType = class(X);

switch (cdataType)
   case {'uint8','int8'}
        nbins = 256;
        [counts, bins]     = imhist(X, nbins);
        calculateFinalBins = @(bins,idx) bins;
        calculateNewCounts = @(counts,idx) counts;

        calculateMinX      = @(bins,fBins,idx) double(intmin(cdataType));
        calculateMaxX      = @(bins,fBins,idx) double(intmax(cdataType));

   case {'uint16', 'uint32', 'int16', 'int32'}
      % The values are set with respect to the first and last bin containing image
      % data instead of the min and max of the datatype. If we didn't do this,
      % then a uint16 or uint32 image with a small data range would have a very
      % squished and not meaningful histogram.
       
      % JM chose 4 after looking at a couple of 16-bit images and thought was more
      % useful representation of the data.
      
      nbins = 65536 / 4;
      minRange = double(intmin(cdataType));
      maxRange = double(intmax(cdataType));
      
      [counts,  bins]     = imhist(X, nbins);
      calculateFinalBins = @(bins,idx) bins(idx);
      calculateNewCounts = @(counts,idx) counts(idx);
      calculateMinX      = @(bins,fBins,idx) max(minRange, bins(idx(1)) - 100);
      calculateMaxX      = @(bins,fBins,idx) min(maxRange, bins(idx(end)) + 100);
  
  case {'double','single'}
        % Images with double CData often don't work well with IMHIST. Convert all
        % images to be in the range [0,1] and convert back later if necessary.
        if (xMin >= 0) && (xMax <= 1)
            nbins = 256;
            [counts, bins]     = imhist(X, nbins); %bins is in range [0,1]
            calculateFinalBins = @(bins,idx) bins;
            calculateNewCounts = @(counts,idx) counts;
            
            calculateMinX      = @(bins,fBins,idx) 0;
            calculateMaxX      = @(bins,fBins,idx) 1;

        else
            if (origRange > 1023) %JM doesn't remember why he chose 1023
                nbins = 1024;
                calculateFinalBins = @(bins,idx) bins(idx);
                calculateNewCounts = @(counts,idx) counts(idx);
                
                calculateMinX      = @(bins,fBins,idx) bins(idx(1)) - 100;
                calculateMaxX      = @(bins,fBins,idx) bins(idx(end)) + 100;


            elseif (origRange > 255)
                nbins = 256;
                calculateFinalBins = @(bins,idx) bins;
                calculateNewCounts = @(counts,idx) counts;
                
                calculateMinX      = @(bins,fBins,idx) bins(idx(1)) - 10;
                calculateMaxX      = @(bins,fBins,idx) bins(idx(end)) + 10;
            else
                nbins = round(origRange + 1);
                calculateFinalBins = @(bins,idx) bins(idx);
                calculateNewCounts = @(counts,idx) counts(idx);
                
                calculateMinX      = @(bins,fBins,idx) fBins(idx(1)) - 10;
                calculateMaxX      = @(bins,fBins,idx) fBins(idx(end)) + 10;

            end

            X = mat2gray(X);
            [counts, bins] = imhist(X, nbins); %bins is in range [0,1]
            bins = round(bins .* origRange + xMin); % bins in range of originalData
        end

    otherwise
        error(message('images:imcontrast:classNotSupported'))
end

[counts,idxOfBinsWithImageData] = saturateOverlyRepresentedCounts(counts);

counts = calculateNewCounts(counts,idxOfBinsWithImageData);
finalBins = calculateFinalBins(bins,idxOfBinsWithImageData);
minX = calculateMinX(bins,finalBins,idxOfBinsWithImageData);
maxX = calculateMaxX(bins,finalBins,idxOfBinsWithImageData);
histRange = [minX maxX];
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [counts,idxOfImage] = saturateOverlyRepresentedCounts(counts)

idx = find(counts ~= 0);
mu = mean(counts(idx));
sigma = std(counts(idx));

% ignore counts that are beyond 4 degrees of standard deviation.These are
% generally outliers.
countsWithoutOutliers = counts(counts <= (mu + 4 * sigma));
idx2 = countsWithoutOutliers ~= 0;
mu2 = mean(countsWithoutOutliers(idx2));

fudgeFactor = 5;
saturationValue = round(fudgeFactor * mu2); %should be an integer

counts(counts > saturationValue) = saturationValue;

%return idx of bins that contain Image Data
if isempty(idx)
    idxOfImage = 1 : nbins;
else
    idxOfImage = (idx(1) : idx(end))';
end

end

function figName = createFigureName(toolName,targetFigureHandle)
% CREATEFIGURENAME(TOOLNAME, TARGETFIGUREHANDLE) creates a name for the figure
% created by the tool, TOOLNAME.  The figure name, FIGNAME, will include
% TOOLNAME and the name of the figure on which the tool depends. TOOLNAME must
% be a string, and TARGETFIGUREHANDLE must be a valid handle to the figure on
% which TOOLNAME depends.
%
%   Example
%   -------
%       h = imshow('bag.png');
%       hFig = figure;
%       imhist(imread('bag.png'));
%       toolName = 'Histogram';
%       targetFigureHandle = ancestor(h,'Figure');
%       name = createFigureName(toolName,targetFigureHandle);
%       set(hFig,'Name',name);
%
%   See also IMAGEINFO, BASICIMAGEINFO, IMPIXELREGION.

%   Copyright 1993-2010 The MathWorks, Inc.
  
  
if ~ischar(toolName)
  error(message('images:createFigureName:invalidInput'))
end

if ishghandle(targetFigureHandle,'figure')

  targetFigureName = get(targetFigureHandle,'Name');
  
  if isempty(targetFigureName) && isequal(get(targetFigureHandle, ...
                                              'IntegerHandle'), 'on')
    targetFigureName = getString(message('images:commonUIString:createFigureNameEmptyName',...
                                         double(targetFigureHandle)));
  end

  if ~isempty(targetFigureName)
    figName = sprintf('%s (%s)', toolName, targetFigureName);
  else
    figName = toolName;
  end
  
else
  error(message('images:createFigureName:invalidFigureHandle'))
end

end  

function suppressPlotTools(h_fig)
%suppressPlotTools Prevents the plot tools from activating on figure.

%   Copyright 2008 The MathWorks, Inc.

% prevent figure from entering plot edit mode
hB = hggetbehavior(h_fig,'plottools');
set(hB,'ActivatePlotEditOnOpen',false);
end

function linkToolName(tool_fig,target_fig,tool_name)
% LINKTOOLNAME(TOOL_FIG, TARGET_FIG, TOOL_NAME) uses the function
% createFigureName to set the name of TOOL_FIG.  It then creates a listener
% that will update the TOOL_FIG name property to match changes that occur
% to the TARGET_FIG name property.

%   Copyright 2008-2010 The MathWorks, Inc.

% set the tool name to begin
set(tool_fig,'Name',createFigureName(tool_name,target_fig));

figure_name_listener = iptui.iptaddlistener(target_fig, ...
   'Name','PostSet',...
   getUpdateNameCallbackFun(tool_fig,target_fig,tool_name));

% store listener in tool figure appdata
setappdata(tool_fig,'figure_name_listener',figure_name_listener);
end

function cbFun = getUpdateNameCallbackFun(tool_fig,target_fig,tool_name)
 % We need to generate this function handle within a sub-function
 % workspace to prevent anonymous function workspace from storing a
 % copy of the iptui.iptaddlistener object. This was causing
 % lifecycle of listener to be tied to target_fig instead of
 % tool_fig. g648119
        
 cbFun = @(hobj,evt) set(tool_fig,'Name',createFigureName(tool_name,target_fig));
end

function iptstandardhelp(helpmenu)
%iptstandardhelp Add Toolbox, Demos, and About to help menu.
%   iptstandardhelp(HELPMENU) adds Image Processing Toolbox Help,
%   Demos, and About Image Processing Toolbox to HELPMENU, which is a
%   uimenu object.

%   Copyright 1993-2011 The MathWorks, Inc.

mapFileLocation = fullfile(docroot, 'toolbox', 'images', 'images.map');

toolboxItem = uimenu(helpmenu,...
    'Label', getString(message('images:commonUIString:imageProcessingToolboxHelpLabel')), ...
                     'Callback', ...
                     @(varargin) helpview(mapFileLocation, 'ipt_roadmap_page'));
                 
demosItem = uimenu(helpmenu,...
    'Label', getString(message('images:commonUIString:imageProcessingDemosLabel')), ...
                   'Callback', @(varargin) demo('toolbox','image processing'), ...
                   'Separator', 'on');
               
aboutItem = uimenu(helpmenu,...
    'Label', getString(message('images:commonUIString:aboutImageProcessingToolboxLabel')), ...
                   'Callback', @iptabout, ...
                   'Separator', 'on');
end

function [backgroundColor, API, windowClipPanelWidth] = ...
    createWindowClipPanel(hFlow, imgModel)
%createWindowClipPanel Create windowClipPanel in imcontrast tool
%   outputs =
%   createWindowClipPanel(hFig,imageRange,imgHasLessThan5Levels,imgModel)
%   creates the WindowClipPanel (top panel in contrast tool) in the contrast
%   tool. Outputs are used to set up display and callbacks in imcontrast.
%
%   This function is used by IMCONTRAST.

%   Copyright 2005-2013 The MathWorks, Inc.


% Global scope
[getEditBoxValue, formatEditBoxString] = getFormatFcns(imgModel);
[hImMinEdit, hImMaxEdit] = deal(gobjects(0));

% Create panel.
hWindowClipPanel = uipanel('parent', hFlow, ...
    'Units', 'pixels', ....
    'BorderType', 'none', ...
    'Tag', 'window clip panel');

backgroundColor = get(hWindowClipPanel,'BackgroundColor');

hWindowClipPanelMargin = 5;
hWindowClipPanelFlow = uiflowcontainer('v0',...
    'Parent', hWindowClipPanel,...
    'FlowDirection', 'LeftToRight', ...
    'Margin', hWindowClipPanelMargin);

fudge = 40;

imDataRangePanelWH = createImDataRangePanel;

[editBoxAPI, eyedropperAPI, windowPanelWH] = ...
    createWindowPanel;

[scalePanelAPI, scaleDisplayPanelWH] = createScaleDisplayPanel;

API.editBoxAPI = editBoxAPI;
API.scalePanelAPI = scalePanelAPI;
API.eyedropperAPI = eyedropperAPI;
API.updateImageModel = @updateImageModel;

windowClipPanelWidth = imDataRangePanelWH(1) + windowPanelWH(1) + ...
    scaleDisplayPanelWH(1) + fudge;
windowClipPanelHeight = max([imDataRangePanelWH(2) windowPanelWH(2) ...
    scaleDisplayPanelWH(2)]) + fudge;

set(hWindowClipPanel, ...
    'HeightLimits', [windowClipPanelHeight windowClipPanelHeight], ...
    'WidthLimits', [windowClipPanelWidth windowClipPanelWidth]);


    %==============================================================
    function updateImageModel(newImageModel)
        % update format functions
        [getEditBoxValue, formatEditBoxString] = ...
            getFormatFcns(newImageModel);
        
        % udpate min/max image intensities
        set(hImMinEdit,'String',...
            formatEditBoxString(getMinIntensity(imgModel)));
        set(hImMaxEdit,'String',...
            formatEditBoxString(getMaxIntensity(imgModel)));
    end

    %==============================================================
    function imDataRangePanelWH = createImDataRangePanel

        hImDataRangePanel = uipanel('Parent', hWindowClipPanelFlow,...
            'Tag', 'data range panel',...
            'Title', getString(message('images:privateUIString:dataRangePanelTitle')));

        horWeight = [1 1];
        hImIntGridMgr = uigridcontainer('v0',...
            'Parent', hImDataRangePanel,...
            'HorizontalWeight', horWeight,...
            'GridSize', [2 2]);
        hImMin = uicontrol('Parent', hImIntGridMgr,...
            'Style', 'Text',...
            'HorizontalAlignment', 'left',...
            'Tag','min data range label',...
            'String', getString(message('images:privateUIString:createWindowClipPanelMinimum')));
        hImMinEdit = uicontrol('Parent',hImIntGridMgr,...
            'Style', 'Edit',...
            'Tag', 'min data range edit',...
            'TooltipString', getString(message('images:privateUIString:createWindowClipPanelMinTooltip')), ...
            'HorizontalAlignment', 'right',...
            'String', formatEditBoxString(getMinIntensity(imgModel)),...
            'Enable', 'off');
        hImMax = uicontrol('Parent', hImIntGridMgr,...
            'Style', 'Text',...
            'Tag','max data range label',...
            'HorizontalAlignment', 'left',...
            'String', getString(message('images:privateUIString:createWindowClipPanelMaximum')));
        hImMaxEdit = uicontrol('Parent',hImIntGridMgr,...
            'Style', 'Edit',...
            'Tag', 'max data range edit',...
            'TooltipString', getString(message('images:privateUIString:createWindowClipPanelMaxTooltip')), ...
            'HorizontalAlignment', 'right',...
            'String', formatEditBoxString(getMaxIntensity(imgModel)),...
            'Enable', 'off');
        
        imDataRangePanelWH = calculateWHOfPanel;
        set(hImDataRangePanel,'WidthLimits', ...
                          [imDataRangePanelWH(1) imDataRangePanelWH(1)], ...
                          'HeightLimits', ...
                          [imDataRangePanelWH(2) imDataRangePanelWH(2)]);
        
                
        %======================================
        function panelWH = calculateWHOfPanel

            % Calculate width and height limits of the panel.
            [topRowWidth topRowHeight] = ...
                getTotalWHofControls([hImMin hImMinEdit]);
            [botRowWidth botRowHeight] = ...
                getTotalWHofControls([hImMax hImMaxEdit]);

            maxWidth = max([topRowWidth botRowWidth]) + 2 * fudge;
            maxHeight = topRowHeight + botRowHeight + fudge;
            panelWH = [maxWidth maxHeight];
        end

    end

    %======================================================================
    function [editBoxAPI, eyedropperAPI, windowPanelWH] = ...
            createWindowPanel

        hWindowPanel = uipanel('Parent', hWindowClipPanelFlow,...
            'Tag', 'window panel',...
            'BackgroundColor', backgroundColor,...
            'Title', getString(message('images:privateUIString:windowPanelTitle')));

        hWindowPanelFlow = uiflowcontainer('v0',...
            'Parent', hWindowPanel,...
            'FlowDirection', 'LeftToRight',...
            'Margin', 0.1);

        % Create min/max edit boxes and eyedroppers.
        windowPanelHorWeight1 = [1.2 1 0.5];
        hWinPanelGridMgr1 = uigridcontainer('v0',...
            'Parent', hWindowPanelFlow,...
            'GridSize', [2 3],...
            'HorizontalWeight', windowPanelHorWeight1);
        hMinLabel = uicontrol('parent', hWinPanelGridMgr1, ...
            'style', 'text', ...
            'Tag','window min label',...
            'string', getString(message('images:privateUIString:createWindowClipPanelMinimum')), ...
            'HorizontalAlignment', 'left', ...
            'BackgroundColor', backgroundColor);
        hMinEdit = uicontrol('parent', hWinPanelGridMgr1, ...
            'Style', 'Edit', ...
            'Tag', 'window min edit', ...
            'HorizontalAlignment', 'right', ...
            'BackgroundColor', [1 1 1], ...
            'TooltipString', getString(message('images:privateUIString:createWindowClipPanelWinMinTooltip')));
        iconRoot = ipticondir;
        iconCdata = makeToolbarIconFromPNG(fullfile(iconRoot, ...
            'tool_eyedropper_black.png'));
        hMinDropper = uicontrol('parent', hWinPanelGridMgr1, ...
            'style', 'pushbutton', ...
            'cdata', iconCdata, ...
            'TooltipString', getString(message('images:privateUIString:selectMinValTooltip')), ...
            'tag', 'min eye dropper button', ...
            'HorizontalAlignment', 'center');
        hMaxLabel = uicontrol('parent', hWinPanelGridMgr1, ...
            'style', 'text', ...
            'Tag','window max label',...
            'string', getString(message('images:privateUIString:createWindowClipPanelMaximum')), ...
            'HorizontalAlignment', 'left', ...
            'BackgroundColor', backgroundColor);
        hMaxEdit = uicontrol('parent', hWinPanelGridMgr1, ...
            'Style', 'Edit', ...
            'Tag', 'window max edit', ...
            'HorizontalAlignment', 'right', ...
            'BackgroundColor', [1 1 1], ...
            'TooltipString', getString(message('images:privateUIString:createWindowClipPanelWinMaxTooltip')));
        iconCdata = makeToolbarIconFromPNG(fullfile(iconRoot, ...
            'tool_eyedropper_white.png'));
        hMaxDropper = uicontrol('parent', hWinPanelGridMgr1, ...
            'style', 'pushbutton', ...
            'cdata', iconCdata, ...
            'TooltipString', getString(message('images:privateUIString:selectMaxValTooltip')), ...
            'tag', 'max eye dropper button', ...
            'HorizontalAlignment', 'center');

        % Create window/center edit boxes.
        windowPanelHorWeight2 = [0.1 0.6 1];
        hWinPanelGridMgr2 = uigridcontainer('v0',...
            'Parent', hWindowPanelFlow,...
            'GridSize', [2 3],...
            'Margin', 0.1,...
            'HorizontalWeight', windowPanelHorWeight2);
        spacing1 = uicontrol('Parent', hWinPanelGridMgr2, ...
            'Tag','spacing',...
            'Style','Text');
        hWidthLabel = uicontrol('parent', hWinPanelGridMgr2, ...
            'style', 'text', ...
            'Tag','window width label',...
            'string', getString(message('images:privateUIString:winPanelWidth')), ...
            'HorizontalAlignment', 'left', ...
            'BackgroundColor', backgroundColor);
        hWidthEdit = uicontrol('parent', hWinPanelGridMgr2, ...
            'Style', 'Edit', ...
            'Tag', 'window width edit', ...
            'HorizontalAlignment', 'right', ...
            'BackgroundColor', [1 1 1], ...
            'TooltipString', getString(message('images:privateUIString:windowWidthTooltip')));
        spacing2 = uicontrol('Parent', hWinPanelGridMgr2,...
            'Style', 'Text',...
            'tag', 'spacing');
        hCenterLabel = uicontrol('parent', hWinPanelGridMgr2, ...
            'style', 'text', ...
            'tag','window center label',...
            'string', getString(message('images:privateUIString:winPanelCenter')), ...
            'HorizontalAlignment', 'left', ...
            'BackgroundColor', backgroundColor);
        hCenterEdit = uicontrol('parent', hWinPanelGridMgr2, ...
            'Style', 'Edit', ...
            'Tag', 'window center edit', ...
            'HorizontalAlignment', 'right', ...
            'BackgroundColor', [1 1 1], ...
            'TooltipString', getString(message('images:privateUIString:windowCenterTooltip')));

        windowPanelWH = calculateWHOfPanel;
        set(hWindowPanel,...
            'HeightLimits', [windowPanelWH(2) windowPanelWH(2)],...
            'WidthLimits', [windowPanelWH(1) windowPanelWH(1)]);
        
        %============================================
        function windowPanelWH = calculateWHOfPanel
       
            topRow = [hMinLabel hMinEdit hMinDropper spacing1 hWidthLabel ...
                      hWidthEdit]; 
            [topRowWidth topRowHeight] = ...
                getTotalWHofControls(topRow);
            
            botRow = [hMaxLabel hMaxEdit hMaxDropper hCenterLabel ...
                      spacing2 hCenterEdit]; 
            [botRowWidth botRowHeight] = ...
                getTotalWHofControls(botRow);
            
            panelWidth = max([topRowWidth botRowWidth]) + 7 * fudge;
            panelHeight = sum([topRowHeight botRowHeight]) + fudge;
            windowPanelWH = [panelWidth panelHeight];
        end

        [editBoxAPI, eyedropperAPI] = createWindowWidgetAPI;
        
        %==========================================================
        function [editBoxAPI, eyedropperAPI] = createWindowWidgetAPI

            editBoxAPI.centerEdit.handle = hCenterEdit;
            editBoxAPI.centerEdit.set    = @setCenter;
            editBoxAPI.centerEdit.get    = @() getEditValue(hCenterEdit);

            editBoxAPI.maxEdit.handle = hMaxEdit;
            editBoxAPI.maxEdit.set    = @setMaxValue;
            editBoxAPI.maxEdit.get    = @() getEditValue(hMaxEdit);

            editBoxAPI.minEdit.handle = hMinEdit;
            editBoxAPI.minEdit.set    = @setMinValue;
            editBoxAPI.minEdit.get    = @() getEditValue(hMinEdit);

            editBoxAPI.widthEdit.handle  = hWidthEdit;
            editBoxAPI.widthEdit.set     = @setWidthEdit;
            editBoxAPI.widthEdit.get     = @() getEditValue(hWidthEdit);

            eyedropperAPI.minDropper.handle = hMinDropper;
            eyedropperAPI.minDropper.set    = '';
            eyedropperAPI.minDropper.get    = 'minimum';

            eyedropperAPI.maxDropper.handle = hMaxDropper;
            eyedropperAPI.maxDropper.set    = '';
            eyedropperAPI.maxDropper.get    = 'maximum';

            %=========================
            function setMinValue(clim)
                set(hMinEdit, 'String', formatEditBoxString(clim(1)));
            end

            %=========================
            function setMaxValue(clim)
                set(hMaxEdit, 'String', formatEditBoxString(clim(2)));
            end

            %=======================
            function setWidthEdit(clim)
                width = computeWindow(clim);
                set(hWidthEdit, 'String', formatEditBoxString(width));
            end

            %=======================
            function setCenter(clim)
                [tmp center] = computeWindow(clim);
                set(hCenterEdit,'String', formatEditBoxString(center));
            end
        end %createWindowWidgetAPI

        %=============================================
        function [width, center] = computeWindow(CLim)
            width = CLim(2) - CLim(1);
            center = CLim(1) + width ./ 2;
        end

    end %createWindowPanel

    %======================================================================
    function [scalePanelAPI,scaleDisplayPanelWH] = ...
            createScaleDisplayPanel

        enablePropValue = 'on';
        defaultOutlierValue = '2';

        hScaleDisplayPanel = uibuttongroup('Parent', hWindowClipPanelFlow,...
            'Tag', 'scale display range panel', ...
            'BackgroundColor', backgroundColor, ...
            'Title', getString(message('images:privateUIString:scaleDisplayPanelTitle')));
        hScaleDisplayFlow = uiflowcontainer('v0',...
            'Parent', hScaleDisplayPanel,...
            'FlowDirection', 'TopDown');

        hMatchDataRangeBtn = uicontrol('Parent', hScaleDisplayFlow,...
            'Style', 'Radiobutton', ...
            'Enable', enablePropValue, ...
            'Tag', 'match data range radio',...
            'String', getString(message('images:privateUIString:scaleDisplayMatchRange')));

        elimGridHorWeight = [1,0.25,0.1];
        hElimGridMgr = uigridcontainer('v0',...
            'Parent', hScaleDisplayFlow,...
            'HorizontalWeight', elimGridHorWeight, ...
            'Margin', 0.1, ...
            'GridSize', [1,3]);
        hElimRadioBtn = uicontrol('Parent', hElimGridMgr,...
            'Style', 'RadioButton', ...
            'Enable', enablePropValue, ...
            'Tag', 'eliminate outliers radio',...
            'String', getString(message('images:privateUIString:scaleDisplayEliminateOutliers')));
        hPercentEdit = uicontrol('Parent', hElimGridMgr,...
            'Style', 'Edit', ...
            'Enable', enablePropValue, ...
            'Background', 'w', ...
            'Tag', 'outlier percent edit',...
            'String', defaultOutlierValue);
        hPercentText = uicontrol('Parent', hElimGridMgr,...
            'Style', 'Text', ...
            'Enable', enablePropValue, ...
            'Tag','% string',...
            'String', '%');

        buttonFlow = uiflowcontainer('v0',...
            'Parent', hScaleDisplayFlow,...
            'Margin', 0.1, ...
            'FlowDirection', 'LeftToRight');
        hScaleDisplayBtn = uicontrol('Parent', buttonFlow,...
            'Style', 'Pushbutton',...
            'Tag', 'apply button',...
            'Tooltip', getString(message('images:privateUIString:scaleDisplayApplyTooltip')),...
            'Enable', enablePropValue,...
            'String',getString(message('images:privateUIString:scaleDisplayApply')));
        set(hScaleDisplayBtn, 'WidthLimits',[60 75]);

        scaleDisplayPanelWH = calculateWHOfPanel;

        set(hScaleDisplayPanel,...
            'HeightLimits', ...
            [scaleDisplayPanelHeight scaleDisplayPanelHeight],...
            'WidthLimits', ...
            [scaleDisplayPanelWidth scaleDisplayPanelWidth]);

        %==================================
        function pWH = calculateWHOfPanel

            [topRowWidth topRowHeight] = ...
                getTotalWHofControls(hMatchDataRangeBtn);

            midRow = [hElimRadioBtn hPercentEdit hPercentText];
            [midRowWidth midRowHeight] = ...
                getTotalWHofControls(midRow);
            
            [botRowWidth botRowHeight] = ...
                getTotalWHofControls(hScaleDisplayBtn);

            scaleDisplayPanelWidth = midRowWidth + 2 * fudge;
            scaleDisplayPanelHeight = topRowHeight + midRowHeight + ...
                botRowHeight + fudge;
            pWH = [scaleDisplayPanelWidth scaleDisplayPanelHeight];
       end

        scalePanelAPI = createScalePanelAPI;

        %=========================================
        function scalePanelAPI = createScalePanelAPI

            scalePanelAPI.elimRadioBtn.handle = hElimRadioBtn;
            scalePanelAPI.elimRadioBtn.set = ...
                @(v) set(hElimRadioBtn, 'Value', v);
            scalePanelAPI.elimRadioBtn.get = ...
                @() get(hElimRadioBtn, 'Value');

            scalePanelAPI.matchDataRangeBtn.handle = hMatchDataRangeBtn;
            scalePanelAPI.matchDataRangeBtn.set = ...
                @(v) set(hMatchDataRangeBtn, 'Value', v);
            scalePanelAPI.matchDataRangeBtn.get = ...
                @() get(hMatchDataRangeBtn, 'Value');

            scalePanelAPI.percentEdit.handle = hPercentEdit;
            scalePanelAPI.percentEdit.set = ...
                @(s) set(hPercentEdit, 'String', s);
            scalePanelAPI.percentEdit.get = ...
                @() getEditValue(hPercentEdit);

            scalePanelAPI.scaleDisplayBtn.handle = hScaleDisplayBtn;
            scalePanelAPI.scaleDisplayBtn.set = '';
            scalePanelAPI.scaleDisplayBtn.get = '';
        end

    end %createScaleDisplayPanel

    %===============================
    function value = getEditValue(h)
        value = getEditBoxValue(sscanf(get(h, 'string'), '%f'));
    end
                
    %==================================================================
    function [totalWidth totalHeight] = getTotalWHofControls(hControls)
        extents = get(hControls, 'Extent');
        if iscell(extents)
            extents = [extents{:}];
        end
        totalWidth = sum(extents(3:4:end));
        totalHeight = max(extents(4:4:end));
    end
end % createWindowClipPanel

%==========================================================================
function [getEditBoxValue, formatEditBoxString] = getFormatFcns(imgModel)

[tmp, imgContainsFloat, imgNeedsExponent] = getNumberFormatFcn(imgModel);

isIntegerData = ~strcmp(getClassType(imgModel),'double');

if isIntegerData
    getEditBoxValue = @round;
    formatEditBoxString = @(val) sprintf('%0.0f', val);

else
    getEditBoxValue = @(x) x;
    if imgNeedsExponent
        formatEditBoxString = @createStringForExponents;
    elseif imgContainsFloat
        formatEditBoxString = @(val) sprintf('%0.4f', val);
    else
        % this case handles double data that contains integers, e.g., eye(100), int16
        % data, etc.q
        formatEditBoxString = @(val) sprintf('%0.0f', val);
    end
end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function string = createStringForExponents(value)
  
        string = sprintf('%1.1E', value);
    end
end

function icon = makeToolbarIconFromPNG(filename)
% makeToolbarIconFromPNG  Creates an icon with transparent
%   background from a PNG image.

%   Copyright 2004 The MathWorks, Inc.  

  % Read image and alpha channel if there is one.
  [icon,map,alpha] = imread(filename);

  % If there's an alpha channel, the transparent values are 0.  For an RGB
  % image the transparent pixels are [0, 0, 0].  Otherwise the background is
  % cyan for indexed images.
  if (ndims(icon) == 3) % RGB

    idx = 0;
    if ~isempty(alpha)
      mask = alpha == idx;
    else
      mask = icon==idx; 
    end
    
  else % indexed
    
    % Look through the colormap for the background color.
    for i=1:size(map,1)
      if all(map(i,:) == [0 1 1])
        idx = i;
        break;
      end
    end
    
    mask = icon==(idx-1); % Zero based.
    icon = ind2rgb(icon,map);
    
  end
  
  % Apply the mask.
  icon = im2double(icon);
  
  for p = 1:3
    
    tmp = icon(:,:,p);
    tmp(mask) = NaN;
    icon(:,:,p) = tmp;
    
  end
end

function hout = imhistpanel(parent,himage)
%IMHISTPANEL histogram display panel
%   HOUT = IMHISTPANEL(PARENT,HIMAGE) creates a histogram display panel
%   associated with the image in specified by the handle HIMAGE, called the
%   target image. HPARENT is the handle to the figure or uipanel object that
%   will contain the histogram display panel. 
%
%   This is currently only used by IMCONTRAST.

%   Copyright 2005-2014 The MathWorks, Inc.

  histStruct = getHistogramData(himage);
  histRange = histStruct.histRange;
  finalBins = histStruct.finalBins;
  counts    = histStruct.counts;
  
  minX = double(histRange(1));
  maxX = double(histRange(2));
  maxY = max(counts);
  
  hout = uipanel('Parent', parent, ...
                 'Units', 'normalized');
  
  iptui.internal.setChildColorToMatchParent(hout,parent);
  
  hAx = axes('Parent', hout);
  
  hStem = stem(hAx, finalBins, counts);  
  set(hStem, 'Marker', 'none')

  set(hAx,'YTick', []);
  set(hAx, 'YLim', [0 maxY]);
  
  xTick = get(hAx, 'XTick');
  xTickSpacing = xTick(2) - xTick(1);

  % Add a little buffer to the Xlim so that you can see the counts at the min and
  % max of the data. Found 5 by experimenting with different images (see testing
  % section in tech ref).
  buffer = xTickSpacing / 5;  
  isFloatingPointData = isfloat(get(himage,'cdata'));
  if ~isFloatingPointData
     buffer = ceil(buffer);
  end
  Xlim1 = minX - buffer;
  Xlim2 = maxX + buffer;
  set(hAx, 'XLim', [Xlim1 Xlim2]);
end

function widgetAPI = createClimWindowOnAxes(hAx,clim,maxCounts)
%createClimWindowOnAxes Create draggable window in imcontrast tool
%   widgetAPI = createClimWindowOnAxes(hAx,clim,maxCounts) creates a draggable
%   window on the axes specified by the handle HAX.
%
%   This is used by IMCONTRAST.

%   Copyright 2005-2014 The MathWorks, Inc.

deep = 1;
middle = 1;
top = 1;


hPatch = patch([clim(1) clim(1) clim(2) clim(2)], ...
    [0 maxCounts maxCounts 0], [1 0.8 0.8], ...
    'parent', hAx, ...
    'zData', ones(1,4) * deep, ...
    'tag', 'window patch');

% There is a drawing stacking bug (g298614) with the painters renderer.
% Workaround this by using uistack to ensure patch window is below stem
% lines.
hPatch.FaceAlpha = 0.6;

hMinLine = line('parent', hAx, ...
    'tag', 'min line', ...
    'xdata', [clim(1) clim(1)], ...
    'ydata', [0 maxCounts], ...
    'ZData', ones(1,2) * middle, ...
    'color', [1 0 0], ...
    'LineWidth', 1);

hMaxLine = line('parent', hAx, ...
    'tag', 'max line', ...
    'xdata', [clim(2) clim(2)], ...
    'ydata', [0 maxCounts], ...
    'ZData', ones(1,2) * middle, ...
    'color', [1 0 0], ...
    'LineWidth', 1);

[width, center] = computeWindow(clim);
hCenterLine = line('parent', hAx, ...
    'tag', 'center line', ...
    'xdata', [center center], ...
    'ydata', [0 maxCounts], ...
    'zdata', ones(1,2) * deep, ...
    'color', [1 0 0], ...
    'LineWidth', 1, ...
    'LineStyle', '--');

% Add handles to make moving the endpoints easier for very small windows.
[XShape, YShape] = getSidePatchShape;
XLim = get(hAx, 'XLim');
YLim = get(hAx, 'YLim');

hMinPatch = patch('parent', hAx, ...
    'XData', clim(1) - (XShape * double(XLim(2) - XLim(1))), ...
    'YData', YShape * YLim(2), ...
    'ZData', ones(size(XShape)) * top, ...
    'FaceColor', [1 0 0], ...
    'EdgeColor', [1 0 0], ...
    'tag', 'min patch');

hMaxPatch = patch('parent', hAx, ...
    'XData', clim(2) + (XShape * double(XLim(2) - XLim(1))), ...
    'YData', YShape * YLim(2), ...
    'ZData', ones(size(XShape)) * top, ...
    'FaceColor', [1 0 0], ...
    'EdgeColor', [1 0 0], ...
    'tag', 'max patch');

[XShape, YShape] = getTopPatchShape;
hCenterPatch = patch('parent', hAx, ...
    'XData', center + XShape .* double(XLim(2) - XLim(1)), ...
    'YData', YShape * (YLim(2) - YLim(1)), ...
    'ZData', ones(size(XShape)) * top, ...
    'FaceColor', [1 0 0], ...
    'EdgeColor', [1 0 0], ...
    'tag', 'center patch');

createWidgetAPI;

    %=======================
    function createWidgetAPI

        widgetAPI.centerLine.handle = hCenterLine;
        widgetAPI.centerLine.get    = @() getXLocation(hCenterLine);
        widgetAPI.centerLine.set    = @setCenterLine;

        widgetAPI.centerPatch.handle = hCenterPatch;
        widgetAPI.centerPatch.get    = @() getXLocation(hCenterPatch);
        widgetAPI.centerPatch.set    = @setCenterPatch;

        widgetAPI.maxLine.handle = hMaxLine;
        widgetAPI.maxLine.get    = @() getXLocation(hMaxLine);
        widgetAPI.maxLine.set    = @(clim) setXLocation(hMaxLine,clim(2));

        widgetAPI.minLine.handle = hMinLine;
        widgetAPI.minLine.get    = @() getXLocation(hMinLine);
        widgetAPI.minLine.set    = @(clim) setXLocation(hMinLine,clim(1));

        widgetAPI.maxPatch.handle = hMaxPatch;
        widgetAPI.maxPatch.get    = @() getXLocation(hMaxPatch);
        widgetAPI.maxPatch.set    = @setMaxPatch;

        widgetAPI.minPatch.handle = hMinPatch;
        widgetAPI.minPatch.get    = @() getXLocation(hMinPatch);
        widgetAPI.minPatch.set    = @setMinPatch;

        widgetAPI.bigPatch.handle = hPatch;
        widgetAPI.bigPatch.get    = @() getXLocation(hPatch);
        widgetAPI.bigPatch.set    = @setPatch;

        %==========================
        function setCenterLine(clim)
            [width,center] = computeWindow(clim);
            setXLocation(hCenterLine,center);
        end

        %==========================
        function setCenterPatch(clim)
            [width,center] = computeWindow(clim);
            topPatchXData = getTopPatchShape * double(getPatchScale);
            set(hCenterPatch, 'XData', center + topPatchXData);
        end
        %==========================
        function setMaxPatch(clim)
            sidePatchXData = getSidePatchShape * double(getPatchScale);
            set(hMaxPatch, 'XData', clim(2) + sidePatchXData);
        end

        %==========================
        function setMinPatch(clim)
            sidePatchXData = getSidePatchShape * double(getPatchScale);
            set(hMinPatch, 'XData', clim(1) - sidePatchXData);
        end

        %==========================
        function setPatch(clim)
            set(hPatch, 'XData', [clim(1) clim(1) clim(2) clim(2)]);
        end

        %===========================
        function value = getXLocation(h)
            value = get(h,'xdata');
            value = value(1);
        end

        %========================
        function setXLocation(h,value)
        % these are the same because we are setting the location of a 
        % vertical line
            set(h,'XData',[value value]);
        end

        %==========================================
        function [xFactor, yFactor] = getPatchScale
            xFactor = XLim(2) - XLim(1);
            yFactor = YLim(2) - YLim(1);
        end
    end %createWidgetAPI
end %createClimWindowOnAxes

%==========================================================================
function [width, center] = computeWindow(CLim)
width = CLim(2) - CLim(1);
center = CLim(1) + width ./ 2;
end

%==========================================================================
function [XData, YData] = getSidePatchShape
XData = [0.00 -0.007 -0.007 0.00 0.01 0.02 0.02 0.01];
YData = [0.40  0.42   0.58  0.60 0.60 0.56 0.44 0.40];
end

%==========================================================================
function [XData, YData] = getTopPatchShape
XData = [-0.015 0.015 0];
YData = [1 1 0.95];
end

function reactToImageChangesInFig(target_images,h_caller,deleteFcn,refreshFcn)
%reactToImageChangesInFig sets up listeners to react to image changes.
%   reactToImageChangesInFig(TARGET_IMAGES,H_CALLER,DELETE_FCN,REFRESH_FCN)
%   calls DELETE_FCN if any of TARGET_IMAGES are deleted and calls the
%   REFRESH_FCN if the CData property of any of the TARGET_IMAGES is
%   modified.  DELETE_FCN and REFRESH_FCN are function handles specified by
%   the modular tool caller, H_CALLER, to update itself appropriately when
%   its associated image changes.  TARGET_IMAGES is array of handles to
%   graphics image objects.
%
%      DELETE_FCN is called when:
%      ==========================
%      * any of the TARGET_IMAGES are deleted
%
%      REFRESH_FCN is called when:
%      ===========================
%      * the CData property of any of the TARGET_IMAGES is modified
%
%   DELETE_FCN and REFRESH_FCN can optionally be empty, if no action should
%   be taken on these events.
%
%   See also IMPIXELINFO,IMPIXELINFOVAL.

%   Copyright 2004-2015 The MathWorks, Inc.

checkImageHandleArray(target_images,mfilename);

% call the deleteFcn if image is destroyed.
if ~isempty(deleteFcn)
    objectDestroyedListener = iptui.iptaddlistener(target_images,...
        'ObjectBeingDestroyed',deleteFcn);
    storeListener(h_caller,'ObjectDestroyedListeners',objectDestroyedListener);
end


% call appropriate function if image cdata changes
if ~isempty(refreshFcn)
    imageCDataChangedListener = iptui.iptaddlistener(target_images,...
        'CData','PostSet',refreshFcn);
    storeListener(h_caller,'CDataChangedListeners',imageCDataChangedListener);
end
end

%-----------------------------------------------------
function storeListener(h_caller,appdata_name,listener)
% this function stores the listeners in the appdata of the h_caller object
% using the makelist function.

% add to current list of listeners from the caller's appdata
listenerList = getappdata(h_caller,appdata_name);
if isempty(listenerList)
    listenerList = listener;
else
    listenerList(end+1) = listener;
end
setappdata(h_caller,appdata_name,unique(listenerList));
end

function checkImageHandleArray(hImage, ~)
%checkImageHandleArray checks an array of image handles.
%   checkImageHandleArray(hImage,mfilename) validates that HIMAGE contains a
%   valid array of image handles. If HIMAGE is not a valid array,
%   then checkImageHandles issues an error for MFILENAME.

%   Copyright 1993-2011 The MathWorks, Inc.

if ~all(ishghandle(hImage,'image'))
    error(message('images:checkImageHandleArray:invalidImageHandle'))
end
end

function registerModularToolWithManager(modular_tool,target_images)
%registerModularToolWithManager registers a modular tool with the modular tool manager of a target image.
%   registerModularToolWithManager(MODULAR_TOOL,TARGET_IMAGES) registers
%   MODULAR_TOOL with the modular tool manager of each of the
%   TARGET_IMAGES.  If a modular tool manager is not already present then
%   one will be created.
%
%   See also IMOVERVIEW.

%   Copyright 2008-2010 The MathWorks, Inc.

for i = 1:numel(target_images)

    % create a modular tool manager if  necessary
    current_image = target_images(i);
    modular_tool_manager = getappdata(current_image,'modularToolManager');
    if isempty(modular_tool_manager)
        modular_tool_manager = iptui.modularToolManager();
    end

    % register the tool with the manager
    modular_tool_manager.registerTool(modular_tool);

    % store manager in image appdata
    setappdata(current_image,'modularToolManager',modular_tool_manager);

end
end

function [x,y] = getCurrentPoint(h)
%getCurrentPoint Return current point.
%   [X,Y] = getCurrentPoint(H) returns the x and y coordinates of the current
%   point. H can be a handle to an axes or a figure.
%
%   This function performs no validation on H.

%   Copyright 2005-2009 The MathWorks, Inc.

p = get(h,'CurrentPoint');

isHandleFigure = ishghandle(h,'figure');

if isHandleFigure
  x = p(1);
  y = p(2);
else
  % handle is axes
  x = p(1,1);
  y = p(1,2);
end
end

