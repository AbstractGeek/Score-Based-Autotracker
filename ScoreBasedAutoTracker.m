function [] = ScoreBasedAutoTracker(varargin)
% 
% 
% 
% 
% 
tic
% global defaults
% Filenames
init_file_suffix = '_tracker_init.csv';
init_template_suffix = '_tracker_templates.mat';
xy_file_suffix = '_xypts.csv';
xyz_file_suffix = '_xyzpts.csv';
res_file_suffix = '_xyzres.csv';
max_score_file_suffix = '_maxScoreData.csv';
best_score_file_suffix = '_bestScoreData.csv';
min_score_file_suffix = '_minimizedScoreData.csv';
results = sprintf('Digitized Points(%s)',datestr(datetime('now'),'dd-mmm-yyyy HH_MM'));
% Headers
xyHeaders = {'X%d_cam1','Y%d_cam1','X%d_cam2','Y%d_cam2'};
xyzHeaders = {'X%d','Y%d','Z%d'};
resHeaders = {'res%d'};
scoreHeaders = {'Score%dcam1','Score%dcam2'};
minScoreHeaders = {'min_score%d'};
seperator = strjoin(repmat({'='},100,1),'');
% get defaults for autotracking
answer = inputdlg({'Template Size (Seperate by ",")',...
    'Search Size (Seperate by ",")', 'Track Threshold', ...
    'DLT Threshold', 'Optimization Grid Size (Seperate by ",")', ...
    'Template Similarity'}, 'Video params', 1, ...
    {'30, 30', '60, 60', '1.1', '3', '20, 20', '0.95'});
% save defaults for autotracking
templateSize = str2double(strsplit(answer{1}, ','));
defaults.searchAreas = str2double(strsplit(answer{2}, ','));
defaults.trackThreshold = str2double(answer{3});
defaults.dltThreshold = str2double(answer{4});
defaults.minGrid = str2double(strsplit(answer{2}, ','));
templateSimilarity = str2double(answer{6});

% Get directory and begin
if isempty(varargin)
   % Get input Directory
    inputDir = uigetdir(); 
else
    inputDir = varargin{1};
end
% Get initfiles
filelist = directory_walk(inputDir,strcat('*',init_file_suffix),{'Digitiz','.Trash'});
outdirlist = {};
% Sort the data into a structure array
j=1;
for i=1:length(filelist)    
    [path,name,ext] = fileparts(filelist{i});    
    [header,M] = readCSV(filelist{i});
    temp_data.calib = csvread(fullfile(path,header{1}));
    temp_data.videos{1} = fullfile(path,header{2});
    temp_data.videos{2} = fullfile(path,header{3});   
    temp_data.prefix = fullfile(path,results,header{4});
    temp_data.adjustValues{1} = str2num(header{5}); %#ok<*ST2NM>
    temp_data.adjustValues{2} = str2num(header{6});
    temp_data.templates = {};
    temp_data.templatenum = 0;
    pointnum = str2num(header{7});
    
    % Get templateFile name
    [~,endind] = regexp(name,header{4});
    pointset_suffix = name(endind+1:regexp(strcat(name,'.csv'),init_file_suffix)-1);
    templateFileName = fullfile(path,strcat(header{4},pointset_suffix,init_template_suffix));
    
    % Check if template-init exist
    if exist(templateFileName,'file')==2
        % templates exist - initialize repo
        templates = {};
        load(templateFileName);
        templateFile = true;
    else
        % make the template repo empty
        templates = {};
        templateFile = false;        
    end
    
    num = (size(M,2)-1)/4;
    temp_data.frames = M(:,size(M,2));
    temp_data.points = [];
    temp_data.pointnum = [];
    init_data(j:j+num-1) = temp_data;
    for k=1:num
       init_data(j+k-1).points = M(:,4*(k-1)+1:4*k);
       init_data(j+k-1).pointnum = pointnum(k);
       % Add templates
       if templateFile
           % Remove empty templates
           current_templates = templates(:,(1:2) + 2*(k-1));
           emptyInds = any(cell2mat(cellfun(@isempty,current_templates,'UniformOutput',false)),2);
           current_templates(emptyInds,:) = [];
           % Save into init data structure
           if ~isempty(current_templates)
            init_data(j+k-1).templates = current_templates;
            init_data(j+k-1).templatenum = size(current_templates,1);
           end
       end       
    end
    j=j+num;
    % Create necessary directories and copy initfiles (for reference)
    temp_path = fullfile(path,results);
    if ~isdir(temp_path)
        mkdir(temp_path);
        if isempty(outdirlist)
            outdirlist{1} = temp_path;
        else
            outdirlist = [outdirlist;{temp_path}]; %#ok<AGROW>
        end
    end    
    copyfile(filelist{i},fullfile(temp_path,strcat(name,ext)));    
    % copy templates if exists
    if templateFile
        copyfile(templateFileName,...
            fullfile(temp_path,strcat(header{4},pointset_suffix,init_template_suffix)));    
    end
end

% Begin autotracking (in parallel)
N = length(init_data);
parfor i=1:N    
    % current initialization data
    curr_init = init_data(i);    
    default = defaults;
    videos = mediaOpen(curr_init.videos);
    % sanity checks
    if strcmp(videos{1}.mode, 'avi')
        info1 = rmfield(videos{1}, {'handle', 'name'});
        info2 = rmfield(videos{2}, {'handle', 'name'});
    else
        info1 = rmfield(videos{1}, {'handle', 'name','cleanup'});
        info2 = rmfield(videos{2}, {'handle', 'name','cleanup'});
    end
    
    % Perform sanity checks on videos    
    if ~isequaln(info1,info2)
        disp('Information not matching in the following pairs of videos:');
        fprintf('Video 1: %s\n%s\nVideo 2:%s\n%s',curr_init.videos{1},...
            struct2str(info1),curr_init.videos{2},struct2str(info1));
        fprintf('Skipping the above video pair (Point: %d)',curr_init.pointnum);
        continue;
    else
        % Give a startup message
        fprintf('%s\n',seperator);
        fprintf('START<%s>: Digitization of Point:%d in\nVideo 1:%s\nVideo 2:%s\n',...
            datestr(datetime('now')),curr_init.pointnum,...
            curr_init.videos{1},curr_init.videos{2});
        fprintf('%s\n',seperator);
    end 
    
    % Begin generating necessary information
    xyData = NaN(info1.NumFrames,4);
    frameSize = [info1.Width,info1.Height];
    num = length(curr_init.frames);
    templates = cell(num+curr_init.templatenum,2);
    for j=1:2
        I = mediaRead(videos{j},curr_init.frames(1));
        default.low_high(j,:) = stretchlim(I);        
        for k=1:num
            I = imsharpen(adjustImageData(mediaRead(videos{j},curr_init.frames(k)),...
                curr_init.adjustValues{j},default.low_high(j,:)));
            curr_point = curr_init.points(k,2*j-1:2*j);
            % pad image
            border = templateSize./2+1;
            I = padarray(I,border,'replicate','both');         
            % Get Template
            templates{k,j} = get_track_template(I,curr_point+border,templateSize,frameSize+2.*border);
            xyData(curr_init.frames(k),2*j-1:2*j) = curr_point;            
        end      
        
        % Now add templates from repo, if present
        for k=1:curr_init.templatenum
            I = imsharpen(adjustImageData(curr_init.templates{k,j},...
                    curr_init.adjustValues{j},default.low_high(j,:)));
            curr_point = (size(curr_init.templates{k,j})+1)./2;
            % Get Template
            templates{k+num,j} = get_track_template(I,curr_point,...
                templateSize,size(curr_init.templates{k,j})); 
        end
        
    end
    default.start = curr_init.frames(1);
    default.end = info1.NumFrames;
    default.frameSize = frameSize;
    default.adjustValues = curr_init.adjustValues;        
    
    % Optimize Template
    [templates,~] = optimizeTrackingTemplates(templates,templateSimilarity);
    
    % Write a status file
    fid = fopen(fullfile(sprintf('%s_status.txt',curr_init.prefix)),'a');
    fprintf(fid,'START<%s>: Digitization of Point:%d\n',datestr(datetime('now')),curr_init.pointnum);
    fclose(fid);
    % Autotrack
    [xyData,xyzData,xyzRes,maxScore,bestScore,minimizedScore] = autoTrackPoint(videos,...
        xyData,templates,curr_init.calib,default);
    % Write Status File
    fid = fopen(fullfile(sprintf('%s_status.txt',curr_init.prefix)),'a');
    fprintf(fid,'END<%s>: Digitization of Point:%d\n',datestr(datetime('now')),curr_init.pointnum);
    fclose(fid);
    
    % Save the data
    % xyDataSc
    curr_xyHeader = cellfun(@sprintf,xyHeaders,repmat({curr_init.pointnum},1,4),...
        'UniformOutput',false);    
    writeCSV(sprintf('%s_point%d%s',curr_init.prefix,curr_init.pointnum,xy_file_suffix),...
        curr_xyHeader,xyData);
    %xyzData
    curr_xyzHeader = cellfun(@sprintf,xyzHeaders,repmat({curr_init.pointnum},1,3),...
        'UniformOutput',false);    
    writeCSV(sprintf('%s_point%d%s',curr_init.prefix,curr_init.pointnum,xyz_file_suffix),...
        curr_xyzHeader,xyzData);
    %residuals
    curr_resHeader = cellfun(@sprintf,resHeaders,repmat({curr_init.pointnum},1,1),...
        'UniformOutput',false);
    writeCSV(sprintf('%s_point%d%s',curr_init.prefix,curr_init.pointnum,res_file_suffix),...
        curr_resHeader,xyzRes);
    %maxScores
    curr_scoreHeader = cellfun(@sprintf,scoreHeaders,repmat({curr_init.pointnum},1,2),...
        'UniformOutput',false);
    writeCSV(sprintf('%s_point%d%s',curr_init.prefix,curr_init.pointnum,max_score_file_suffix),...
        curr_scoreHeader,maxScore);
    %bestScores    
    curr_scoreHeader = cellfun(@sprintf,scoreHeaders,repmat({curr_init.pointnum},1,2),...
        'UniformOutput',false);
    writeCSV(sprintf('%s_point%d%s',curr_init.prefix,curr_init.pointnum,best_score_file_suffix),...
        curr_scoreHeader,bestScore);    
     %minimizedScores    
    curr_minScoreHeader = cellfun(@sprintf,minScoreHeaders,repmat({curr_init.pointnum},1,1),...
        'UniformOutput',false);
    writeCSV(sprintf('%s_point%d%s',curr_init.prefix,curr_init.pointnum,min_score_file_suffix),...
        curr_minScoreHeader,minimizedScore);
    
    % Done. End with a finish message
    fprintf('%s\n',seperator);
    fprintf('END<%s>: Digitization of Point:%d in\nVideo 1:%s\nVideo 2:%s\n',...
            datestr(datetime('now')),curr_init.pointnum,...
            curr_init.videos{1},curr_init.videos{2});
    fprintf('%s\n',seperator);
    
end

fprintf('%s\n',seperator);
fprintf('%s\n',seperator);
fprintf('%s\n',seperator);
fprintf('Generating Videos from digitized points\n');

initfilelist = {};
for i=1:length(outdirlist)
    initfiles = dir(fullfile(outdirlist{i},strcat('*',init_file_suffix)));
    initfiles = {initfiles(:).name}';
    initfiles = cellfun(@fullfile,repmat(outdirlist(i),length(initfiles),1),initfiles,'UniformOutput',false);
    initfilelist = [initfilelist;initfiles];
end
collatePointsAndCreateVideos(initfilelist,0,templateSize);

fprintf('%s\n',seperator);
fprintf('%s\n',seperator);
fprintf('END\n');
fprintf('END\n');
fprintf('END\n');
fprintf('%s\n',seperator);
fprintf('%s\n',seperator);
toc

end