function [] = makeVideosForCompletedDataset(folderlist)

% defaults
completion_suffix = '_Complete';
xy_file_suffix = '_xypts.csv';
res_file_suffix = '_xyzres.csv';
best_score_file_suffix = '_bestScoreData.csv';
min_score_file_suffix = '_minimizedScoreData.csv';
templateSize = [30,30];

init_file_suffix = '_tracker_init.csv';
init_file_folder = 'Init_Files';
relative_position = '../..';

outFolder = 'Digitized Videos';

init_files = [];
init_folders = {};
for i=1:length(folderlist)
    matched_files = dir(fullfile(folderlist{i},init_file_folder,strcat('*',init_file_suffix)));
    init_files = [init_files;matched_files];
    matched_folders = cell(length(matched_files),1);
    matched_folders(:) = folderlist(i);
    init_folders = [init_folders;matched_folders];
    
    if ~isdir(fullfile(folderlist{i},outFolder))
        mkdir(fullfile(folderlist{i},outFolder));
    end
    
end

parfor i=1:size(init_files,1)
    curr_folder = pwd;
    cd(init_folders{i});
    
    [header,~] = readCSV(fullfile(init_file_folder,init_files(i).name));
    
    calib = csvread(GetFullPath(fullfile(relative_position,header{1})));
    videos = cell(2,1);
    videos{1} = GetFullPath(fullfile(relative_position,header{2}));
    videos{2} = GetFullPath(fullfile(relative_position,header{3}));    
    prefix = header{4};
    
    adjustValues = cell(1,2);
    adjustValues{1} = str2num(header{5});  %#ok<*ST2NM>
    adjustValues{2} = str2num(header{6});
    
    % Check if exists
    inFile = sprintf('%s%s%s',prefix,completion_suffix,xy_file_suffix);
    if exist(inFile,'file')~=2
       continue; 
    end
    resFile = sprintf('%s%s%s',prefix,completion_suffix,res_file_suffix);
    besFile = sprintf('%s%s%s',prefix,completion_suffix,best_score_file_suffix);
    minFile = sprintf('%s%s%s',prefix,completion_suffix,min_score_file_suffix);
    outFile = fullfile(outFolder,strcat(prefix,'.avi'));
    
    % Get file and start making videos
    [~,xyData] = readCSV(inFile);
    [~,resData] = readCSV(resFile);
    [~,minScore] = readCSV(minFile);
    [~,bestScore] = readCSV(besFile);
    
    createOverlayedVideos(videos,xyData,calib,resData,minScore,bestScore,templateSize,adjustValues,outFile);
    cd(curr_folder);  
end
end