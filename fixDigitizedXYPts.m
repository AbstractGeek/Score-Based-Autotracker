function [] = fixDigitizedXYPts(varargin)
%FIXDIGITIZEDXYPTS Summary of this function goes here
%   Detailed explanation goes here

% defaults
xy_file_suffix = '_xypts.csv';
xyz_file_suffix = '_xyzpts.csv';
res_file_suffix = '_xyzres.csv';

if isempty(varargin)
    inputDir = uigetdir();
end

logfile = 'fixDigitizedXYPts.org';   % Save as an org file (easier to read with emacs/spacemacs)
if exist(fullfile(inputDir,logfile),'file')==2
   warning('logfile already present in the folder. Logs of new fixes will be appended to the folder');   
end

warning('This program will rewrite xypts and xyzres file');
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
    [~,xyzData] = readCSV(fullfile(inputDir,xyzFiles(i).name));
    [xyHeader,xyData] = readCSV(fullfile(inputDir,...
        strcat(xyzFiles(i).name(1:prefix-1),xy_file_suffix)));
    [resHeader,resData] = readCSV(fullfile(inputDir,...
        strcat(xyzFiles(i).name(1:prefix-1),res_file_suffix)));

    % Write into the log file
    fprintf(fid,'** %s\n',xyzFiles(i).name);
    fprintf(fid,'*** Files fixed:\n');
    fprintf(fid,'- %s\n', strcat(xyzFiles(i).name(1:prefix-1),xy_file_suffix));
    fprintf(fid,'- %s\n', strcat(xyzFiles(i).name(1:prefix-1),res_file_suffix));
    fprintf(fid,'*** Points fixed:\n');
    
    N = size(xyzData,2)/3;
    for j=1:N
        tobenaned = any(isnan(xyzData(:,(1:3)+(j-1)*3)),2);
        xyData(tobenaned,(1:4)+(j-1)*4) = NaN;
        resData(tobenaned,j) = NaN;
        % Write into log file
        fprintf(fid,'**** Point %s\n',num2str(j));  
        fprintf(fid,'%s\n',num2str(find(tobenaned)','%d '));
    end
    % Rewrite
    writeCSV(...
        fullfile(inputDir,strcat(xyzFiles(i).name(1:prefix-1),xy_file_suffix)),...
        xyHeader,xyData);
    writeCSV(...
        fullfile(inputDir,strcat(xyzFiles(i).name(1:prefix-1),res_file_suffix)),...
        resHeader,resData);
    
end

fclose(fid);
end

