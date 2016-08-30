function [] = deleteBaseAndHeadPoints(varargin)
%FIXDIGITIZEDXYPTS Summary of this function goes here
%   Detailed explanation goes here

% defaults
xy_file_suffix = '_xypts.csv';
xyz_file_suffix = '_xyzpts.csv';
res_file_suffix = '_xyzres.csv';

if isempty(varargin)
    inputDir = uigetdir();
end

logfile = 'deleteBaseAndHeadPoints.org';   % Save as an org file (easier to read with emacs/spacemacs)
if exist(fullfile(inputDir,logfile),'file')==2
   warning('logfile already present in the folder. Logs of new fixes will be appended to the folder');   
end

warning('This program will delete xypts, xyzpts and xyzres points of base and head points');
confirm = input('Do you want to rewrite existing files in the outfolder? (Y/N): ','s');
if (~strcmp(confirm, 'Y') && ~strcmp(confirm,'y'))
    return;
end

% Open logfile and enter default stuff
fid = fopen(fullfile(inputDir,logfile),'a');   % Disregard contents if any
fprintf(fid,'* [%s]\n',datestr(datetime('now')));

xyzFiles = dir(fullfile(inputDir, strcat('*',xyz_file_suffix)));

% Go through all xyzFiles
for i=1:length(xyzFiles)
    prefix = regexp(xyzFiles(i).name,xyz_file_suffix);    
    % Rewrite XYZ Data
    [xyzHeader,xyzData] = readCSV(fullfile(inputDir,xyzFiles(i).name));    
    xyzData(:,7:end) = NaN;
    writeCSV(...
        fullfile(inputDir,xyzFiles(i).name),...
        xyzHeader,xyzData);
    
    % Rewrite XY Data
    [xyHeader,xyData] = readCSV(fullfile(inputDir,...
        strcat(xyzFiles(i).name(1:prefix-1),xy_file_suffix)));
    xyData(:,9:end) = NaN;    
    writeCSV(...
        fullfile(inputDir,strcat(xyzFiles(i).name(1:prefix-1),xy_file_suffix)),...
        xyHeader,xyData);
    
    % Rewrite Res Data
    [resHeader,resData] = readCSV(fullfile(inputDir,...
        strcat(xyzFiles(i).name(1:prefix-1),res_file_suffix)));
    resData(:,3:end) = NaN;
    writeCSV(...
        fullfile(inputDir,strcat(xyzFiles(i).name(1:prefix-1),res_file_suffix)),...
        resHeader,resData);

    % Write into the log file
    fprintf(fid,'** %s\n',xyzFiles(i).name);
    fprintf(fid,'*** Files fixed:\n');
    fprintf(fid,'- %s\n', strcat(xyzFiles(i).name(1:prefix-1),xy_file_suffix));
    fprintf(fid,'- %s\n', xyzFiles(i).name);
    fprintf(fid,'- %s\n', strcat(xyzFiles(i).name(1:prefix-1),res_file_suffix));    
    
end

fclose(fid);
end

