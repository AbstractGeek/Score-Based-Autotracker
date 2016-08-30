function [] = collatePointsAndCreateVideos(filelist,rewrite,templateSize)
% 
% 
% 
% 

% defaults
completion_suffix = '_Complete';
xy_file_suffix = '_xypts.csv';
xyz_file_suffix = '_xyzpts.csv';
res_file_suffix = '_xyzres.csv';
offset_file_suffix = '_offsets.csv';
max_score_file_suffix = '_maxScoreData.csv';
best_score_file_suffix = '_bestScoreData.csv';
min_score_file_suffix = '_minimizedScoreData.csv';
% Headers
offsetHeader = {'offset_cam1','offset_cam2'};

% 
prefixcell = {};
headercell = {};
foldercell = {};

for i=1:length(filelist)
    [folder,~,~] = fileparts(filelist{i});
    [header,~] = readCSV(filelist{i}); 
    prefix = header{4};
    if any(ismember(prefixcell,prefix))
        continue;
    else        
        prefixcell = [prefixcell;prefix];
        headercell = [headercell;{header}];
        foldercell = [foldercell;folder];
    end
end

parfor i=1:length(headercell)
    % Begin
    curr_folder = pwd;
    cd(foldercell{i});
    header = headercell{i};
    
    % Video folder if absent
    if ~isdir('DigitizedVideos')
        mkdir('DigitizedVideos');
    end
    
    % Pull out necessary data
    calibfile = GetFullPath(fullfile('..',header{1}));    
    videos = cell(2,1);
    videos{1} = mediaOpen(GetFullPath(fullfile('..',header{2})));
    videos{2} = mediaOpen(GetFullPath(fullfile('..',header{3})));    
    prefix = header{4};
    adjustValues = cell(1,2);
    adjustValues{1} = str2num(header{5});  %#ok<*ST2NM>
    adjustValues{2} = str2num(header{6});
        
    % get number of points    
    info1 = rmfield(videos{1}, {'handle', 'name'});
    numofpoints = info1.NumFrames;
    
    % Check if exists    
    outFile = sprintf('%s%s%s',prefix,completion_suffix,xy_file_suffix);
    if (exist(outFile,'file')==2) && (rewrite==1||rewrite==2)
        fprintf('XY FILE PRESENT:%s\n',outFile);
        if (rewrite==1)||(rewrite==4)
            fprintf('Do you want to rewrite it with new matrixes?\n');
            confirm = input('(Y/N): ','s');
            if (~strcmp(confirm, 'Y') && ~strcmp(confirm,'y'))
                continue;
            end
        else
           fprintf('OVERWRITING XY FILE:%s\n',outFile);
        end        
    elseif (exist(outFile,'file')==2) && rewrite==0
        fprintf('SKIPPING: XY FILE PRESENT-%s\n',outFile);
        continue;
    elseif (exist(outFile,'file')==2) && (rewrite == 3)
        calib = csvread(calibfile);
        [~,xyData] = readCSV(sprintf('%s%s%s',prefix,completion_suffix,xy_file_suffix));
        [~,resData] = readCSV(sprintf('%s%s%s',prefix,completion_suffix,res_file_suffix));
        [~,bestScoreData] = readCSV(sprintf('%s%s%s',prefix,completion_suffix,best_score_file_suffix));
        [~,minScoreData] = readCSV(sprintf('%s%s%s',prefix,completion_suffix,min_score_file_suffix));
        createOverlayedVideos(videos,xyData,calib,resData,minScoreData,bestScoreData,templateSize,adjustValues,...
            fullfile('DigitizedVideos',sprintf('%s_Combined.avi',prefix)));
        continue;
    end 
    
    % Begin collating points
    % Get individually digitized points    
    xyFiles = dir(sprintf('%s*%s',prefix,xy_file_suffix));
    xyFiles = {xyFiles(:).name}';
    [points,~] = regexp(xyFiles,...
        sprintf('%s_point(\\d)%s',prefix,xy_file_suffix),'tokens','match');    
    points = points(~cellfun('isempty',points));
    % Generate matrixes
    N = length(points);
    xyHeader = cell(1,N*4);
    xyData = NaN(numofpoints,N*4);    
    xyzHeader = cell(1,N*3);
    xyzData = NaN(numofpoints,N*3);
    resHeader = cell(1,N);
    resData = NaN(numofpoints,N);
    maxScoreHeader = cell(1,N*2);
    maxScoreData = NaN(numofpoints,N*2);
    bestScoreHeader = cell(1,N*2);
    bestScoreData = NaN(numofpoints,N*2);
    minScoreHeader = cell(1,N);
    minScoreData = NaN(numofpoints,N);
    % Collate Points
    for j=1:N;
        curr = str2double(char(points{j}{1}));
        % Get xyData
        [H,M] = readCSV(sprintf('%s_point%d%s',prefix,curr,xy_file_suffix));
        xyHeader(1,4*(j-1)+1:4*j) = H;
        xyData(:,4*(j-1)+1:4*j) = M;
        % Get xyzData
        [H,M] = readCSV(sprintf('%s_point%d%s',prefix,curr,xyz_file_suffix));
        xyzHeader(1,3*(j-1)+1:3*j) = H;
        xyzData(:,3*(j-1)+1:3*j) = M;
        % Get xyData
        [H,M] = readCSV(sprintf('%s_point%d%s',prefix,curr,res_file_suffix));
        resHeader(1,j) = H;
        resData(:,j) = M;  
        % Get maxScore
        [H,M] = readCSV(sprintf('%s_point%d%s',prefix,curr,max_score_file_suffix));
        maxScoreHeader(1,2*(j-1)+1:2*j) = H;
        maxScoreData(:,2*(j-1)+1:2*j) = M;  
        % Get bestScore
        [H,M] = readCSV(sprintf('%s_point%d%s',prefix,curr,best_score_file_suffix));
        bestScoreHeader(1,2*(j-1)+1:2*j) = H;
        bestScoreData(:,2*(j-1)+1:2*j) = M;  
        % Get minScore
        [H,M] = readCSV(sprintf('%s_point%d%s',prefix,curr,min_score_file_suffix));
        minScoreHeader(1,j) = H;
        minScoreData(:,j) = M;  
    end  
    
    % Save 
    writeCSV(sprintf('%s%s%s',prefix,completion_suffix,xy_file_suffix),...
        xyHeader,xyData);
    writeCSV(sprintf('%s%s%s',prefix,completion_suffix,xyz_file_suffix),...
        xyzHeader,xyzData);
    writeCSV(sprintf('%s%s%s',prefix,completion_suffix,res_file_suffix),...
        resHeader,resData);    
    writeCSV(sprintf('%s%s%s',prefix,completion_suffix,offset_file_suffix),...
        offsetHeader,zeros(size(xyzData,1),length(offsetHeader)));    
    
    writeCSV(sprintf('%s%s%s',prefix,completion_suffix,max_score_file_suffix),...
        maxScoreHeader,maxScoreData);
    writeCSV(sprintf('%s%s%s',prefix,completion_suffix,best_score_file_suffix),...
        bestScoreHeader,bestScoreData);
    writeCSV(sprintf('%s%s%s',prefix,completion_suffix,min_score_file_suffix),...
        minScoreHeader,minScoreData);
    
    if (rewrite~=4)
        calib = csvread(calibfile);
        createOverlayedVideos(videos,xyData,calib,resData,minScoreData,bestScoreData,templateSize,adjustValues,...
            fullfile('DigitizedVideos',sprintf('%s_Combined.avi',prefix)));   
    end
    cd(curr_folder);        
end


end

