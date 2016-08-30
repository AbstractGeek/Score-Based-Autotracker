function [] = initializeScoreBasedAutoTracker(varargin)
%
%
%
%

%% global defaults
template_file = 'basic_templates.mat';
templateSize = [50,50];
% Get defaults from user
answer = inputdlg({'extension filter (avi or cine)', ...
    'file name filter (true[1] or false[0])', ...
    'file name filter text'}, 'Video params', 1, ...
    {'*.avi', '1', 'lowfreq'});
% Save the user inputs
extfilter = answer{1};
filterflag = str2double(answer{2});
filefiltertext = answer{3};
% Display user inputs
fprintf('\nSelected Inputs are: \n extension filter: %s\n file name filter: %d\n file name filter text: %s\n\n',...
    extfilter, filterflag, filefiltertext);

% Get pointset
confirm = input('Point Set 1 (Left Antenna + Base) or 2 (Right Antenna + Base + Head) or 3 (Custom)?: ');
if (confirm == 1)
    % Left antenna    
    pointnum = [2 4];           
    fprintf('Left Antenna (tip and base) Digitization\n');
    fprintf('Ensure you set the frames after looking at the video\n');
    init_file_suffix = '_PointSet1_tracker_init.csv';
    image_folder = 'InitImages_PointSet1';
elseif (confirm == 2)
    % Right antenna and head
    pointnum = [1 3 5];        
    fprintf('Right Antenna (tip and base) and Head Digitization\n');    
    fprintf('Ensure you set the frames after looking at the video\n');
    init_file_suffix = '_PointSet2_tracker_init.csv';
    image_folder = 'InitImages_PointSet2';
elseif (confirm == 3)
    % Custom   
    ptstring = inputdlg({'Point numbers (Seperated by ",")'}, ...
        'Point Initialization', 1, {'1'});
    ptstring = strsplit(ptstring{1}, ',');
    ptstring(cellfun(@isempty, ptstring)) = [];
    pointnum = str2double(ptstring);
    % Get confirmation and start
    fprintf('\nSelected points are: %s\n', num2str(pointnum));
    confirm = input('Proceed with digization (y/n)?: ', 's');
    if ~strcmp(confirm, 'Y') && ~strcmp(confirm, 'y')
        fprintf('Skipping digitization (User input)\n\n');
        return;
    end        
    init_file_suffix = '_PointSet3_tracker_init.csv';
    image_folder = 'InitImages_PointSet3';
elseif (confirm == 4)
    % Secret entry
    pointnum = [2];
    % frames = [1];    
    fprintf('Custom PointSet\n');
    init_file_suffix = '_PointSet4_tracker_init.csv';
    image_folder = 'InitImages_PointSet4';
else 
    fprintf('Invalid Input: %d\n',confirm);
    return;
end

%% Get input folder
if isempty(varargin)
    inputDir = uigetdir();
else
    inputDir = varargin{1};
end
% Get List of directories
listOfContents = dir(inputDir);
isubDir = [listOfContents(:).isdir];
dirList = {listOfContents(isubDir).name}';
dirList(ismember(dirList,{'.','..','$RECYCLE.BIN','System Volume Information','ArchivedPlots','CurrentPlots'})) = [];

%% Get moth data inside directories
subDirList = {};
for i=1:length(dirList)
    listOfContents = dir(fullfile(inputDir,dirList{i}));
    isubDir = [listOfContents(:).isdir];
    tempSubDirList = {listOfContents(isubDir).name}';
    tempSubDirList(ismember(tempSubDirList,{'.','..','$RECYCLE.BIN','System Volume Information','ArchivedPlots','CurrentPlots'})) = [];
    tempSubDir = cellfun(@(file,folder) fullfile(folder,file),tempSubDirList,repmat({dirList{i}},size(tempSubDirList)),'UniformOutput',false);
    subDirList = [subDirList;[tempSubDir,repmat({dirList{i}},size(tempSubDir))]];
end


%% Get folders to be digitized
[selection,ok] = listdlg('ListString',subDirList(:,1));
if ~ok
    disp('Exiting');
    return;
end
selectedDirs = subDirList(selection,:);
[unique_folders,~,iuf] = unique(selectedDirs(:,2));
selectedDirs(:,3) = num2cell(iuf);
calibFiles = cell(length(unique_folders),1);
calibData = cell(length(unique_folders),1);
% Get calibration files
for i=1:length(unique_folders)
    calibFilesTemp = dir(fullfile(inputDir,unique_folders{i},'*DLTcoefs.csv'));
    calibFilesTemp = {calibFilesTemp(:).name}';
    if length(calibFilesTemp)>1
        fprintf('Folder:%s has multiple DLTcoef files!.\n.Picking the first one(alphabetically).\n',unique_folders{i});
        calibFiles{i,1} = fullfile(inputDir,unique_folders{i},calibFilesTemp{1});
        calibData{i,1} = dlmread(fullfile(inputDir,unique_folders{i},calibFilesTemp{1}));
    elseif isempty(calibFilesTemp)
        fprintf('Folder:%s has no DLTcoef files!.\n.Skipping Folder.\n',unique_folders{i});
        calibFiles{i,1} = NaN;
        calibData{i,1} = NaN;
        selectedDirs(cell2mat(selectedDirs(:,3))==i,:) = [];
    else
        calibFiles{i,1} = fullfile(inputDir,unique_folders{i},calibFilesTemp{1});
        calibData{i,1} = dlmread(fullfile(inputDir,unique_folders{i},calibFilesTemp{1}));
    end
    
end

%% List All files in the folders
videoFiles = cell(size(selectedDirs,1),2);
for i=1:size(selectedDirs,1)
    videoFilesTemp = dir(fullfile(fullfile(inputDir,selectedDirs{i}),extfilter));
    videoFilesTemp = {videoFilesTemp(:).name}';
    % filter_names
    if filterflag
        filtered_names = regexp(videoFilesTemp,filefiltertext,'match');
        videoFilesTemp(cellfun('isempty',filtered_names))=[];
    end
    
    % Get camera names
    cameras = regexp(videoFilesTemp,'\d\d\d\d','match');
    % Remove cineFiles which do not have camera names in their name
    videoFilesTemp(cellfun('isempty',cameras))=[];
    cameras = [cameras{:}];
    [cameras,~,ic] = unique(cameras);
    if length(cameras)~=2
        fprintf('Folder:%s has multiple cameras!.\nSkipping Folder.\n',selectedDirs{i});
        continue;
    end
    % Sanity check
    if length(videoFilesTemp(ic==1))~=length(videoFilesTemp(ic==2))
        fprintf('Folder:%s extra cine files for one camera!.\nSkipping Folder.\n',selectedDirs{i});
        continue;
    end
    % Classify cine_files;
    videoFiles{i,1} = videoFilesTemp(ic==1);
    videoFiles{i,2} = videoFilesTemp(ic==2);
end

%% Gather trackpoints and save it in a files
for i=1:size(selectedDirs,1)
    calib = calibData{selectedDirs{i,3}};
    if exist(fullfile(inputDir,selectedDirs{i,1},template_file),'file')==2
        load(fullfile(inputDir,selectedDirs{i,1},template_file));
        templates = templateRepo(pointnum);
    else
        templates = {};
        templateRepo = cell(1,5);
    end
    
    % Select videos to digitize
    [selection,ok] = listdlg('ListString',videoFiles{i,1});
    if ~ok
        fprintf('\nSkipping directory:\n%s\n', selectedDirs{i,1});
        continue;
    end
    selectedVideos{1,1} = videoFiles{i,1}(selection);
    selectedVideos{1,2} = videoFiles{i,2}(selection);
    
    fprintf('\nSelected %d videos from directory:\n%s\n',...
        length(selection), selectedDirs{i,1});

    % Get Image Adjustment Values
    [adjustValues,low_high] = getImageAdjustment(...
    fullfile(inputDir,selectedDirs{i,1},selectedVideos{1,1}{1}),...
    fullfile(inputDir,selectedDirs{i,1},selectedVideos{1,2}{1}));
    
    for j=1:size(selectedVideos{1,1})        
        % Print video names
        fprintf('\nInitializing digitization of videos:\n');            
        fprintf('%s\n%s\n\n', selectedVideos{1,1}{j}, selectedVideos{1,2}{j});        
        % Split names and check if an init file exists
        splitname1 = strsplit(selectedVideos{1,1}{j},'_');
        splitname2 = strsplit(selectedVideos{1,2}{j},'_');
        outFilePrefix = strjoin(splitname1(strcmp(splitname1,splitname2)),'_');
        outFile = fullfile(inputDir,selectedDirs{i,1},strcat(outFilePrefix,init_file_suffix));
        if exist(outFile,'file')==2
            fprintf('INIT FILE PRESENT:%s\n',outFile);            
            confirm = input('Do you want to rewrite it with new trackpoints? (Y/N): ','s');
            fprintf('\n');
            if (~strcmp(confirm, 'Y') && ~strcmp(confirm,'y'))
                continue;
            end
        end        
        % Get frames
        framestring = inputdlg({'Frame Nos (Seperate by ",")'}, ...
            'Initialization Frames', 1, {'1'});
        framestring = strsplit(framestring{1}, ',');
        framestring(cellfun(@isempty, framestring)) = [];
        frames = str2double(framestring);        
        % Get confirmation and start
        fprintf('Selected frames (%d) are:\n %s\n\n', length(frames), num2str(frames));
        confirm = input('Proceed with digization (y/n)?: ', 's');
        if ~strcmp(confirm, 'Y') && ~strcmp(confirm, 'y')             
            fprintf('Skipping digitization of this video set (User input)\n');            
            continue;
        end
        
        % Begin collecting trackpoints
        videos = mediaOpen({fullfile(inputDir,selectedDirs{i,1},selectedVideos{1,1}{j}),...
            fullfile(inputDir,selectedDirs{i,1},selectedVideos{1,2}{j})});
        [points,templates] = getTrackPoints(videos,calib,templates,...
            length(pointnum),frames,templateSize,adjustValues,low_high);
        
        % create relative path
        calibpath = relativepath(calibFiles{selectedDirs{i,3}},fullfile(inputDir,selectedDirs{i,1}));
        
        % Save obtained points
        header = {calibpath,selectedVideos{1,1}{j},selectedVideos{1,2}{j},outFilePrefix,...
            sprintf('[%s]',num2str(adjustValues{1})),...
            sprintf('[%s]',num2str(adjustValues{2})),...
            sprintf('[%s]',num2str(pointnum))};
        writeCSV(outFile,header,[points,frames']);

        % Save points, digitization error and templates
        templateRepo(pointnum) = templates;
        save(fullfile(inputDir,selectedDirs{i,1},template_file),'templateRepo');
        saveInitFrames(videos,calib,points,frames,templateSize,...
            fullfile(inputDir,selectedDirs{i,1},image_folder,outFilePrefix),...
            adjustValues,low_high);
        
        fprintf('Initialization done for this video set\n');            
        
    end
end
% Add the template respository generation code here.


end