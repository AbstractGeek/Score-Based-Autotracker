function [] = customCollateCompletedPoints(folder1,folder2,outfolder,points1,points2)
% 
% 
% 
% 
% points input - first column: column number in the input file, second
% column: column number in output file
% Dinesh Natesan, 6th April 2016

% defaults
numofpoints = 7122;
completion_suffix = '_Complete';
xy_file_suffix = '_xypts.csv';
xyz_file_suffix = '_xyzpts.csv';
res_file_suffix = '_xyzres.csv';
offset_file_suffix = '_offsets.csv';
max_score_file_suffix = '_maxScoreData.csv';
best_score_file_suffix = '_bestScoreData.csv';
min_score_file_suffix = '_minimizedScoreData.csv';

% Log file
logfile = 'customCollateCompletedPoints.org';   % Save as an org file (easier to read with emacs/spacemacs)
if exist(fullfile(outfolder,logfile),'file')==2
   warning('logfile already present in the folder. It is best if custom collation is done into a new folder');
   confirm = input('Do you want to rewrite existing files in the outfolder? (Y/N): ','s');
   if (~strcmp(confirm, 'Y') && ~strcmp(confirm,'y'))
       return;
   end   
end

% Details of saved csv files (skip offset)
csv_file_suffixes = cell(6,2);
csv_file_suffixes(:,1) = {xy_file_suffix xyz_file_suffix res_file_suffix ...
    max_score_file_suffix best_score_file_suffix min_score_file_suffix}';
csv_file_suffixes(:,2) = {4,3,1,2,2,1}';

% Open logfile and enter default stuff
fid = fopen(fullfile(outfolder,logfile),'a');   % Disregard contents if any
fprintf(fid,'* [%s]\n',datestr(datetime('now')));
fprintf(fid,'** Collation Overview\n');
fprintf(fid,'Folder 1: %s\n',folder1);
pointsstr = num2str(points1');
fprintf(fid,'Points 1: [%s] -> [%s]\n',pointsstr(1,:),pointsstr(2,:));
fprintf(fid,'Folder 2: %s\n',folder2);
pointsstr = num2str(points2');
fprintf(fid,'Points 2: [%s] -> [%s]\n',pointsstr(1,:),pointsstr(2,:));
fprintf(fid,'Output Folder: %s\n',outfolder);
fprintf(fid,'** Transfer Log\n');

for i=1:size(csv_file_suffixes,1)
    % Find all completed csv files with ith suffix
    complete1 = dir(fullfile(folder1,strcat('*',completion_suffix,...
        csv_file_suffixes{i,1})));    
    if i==1
        % Select csv to collate
        [selection,ok] = listdlg('ListString',{complete1(:).name});
        if ~ok
            disp('Exiting');
            return;
        end
        complete1 = complete1(selection);
    else
        complete1 = complete1(selection);
    end
    pointcols = csv_file_suffixes{i,2};
    pointcalc = @(x) (1:pointcols)+(x-1)*pointcols;
    
    % Combine complete1 and complete2
    for j=1:size(complete1,1)        
        if exist(fullfile(folder2,complete1(j).name),'file')==2
            [header1,M1] = readCSV(fullfile(folder1,complete1(j).name));
            [header2,M2] = readCSV(fullfile(folder2,complete1(j).name));            
            % Get input columns
            inputcol1 = cell2mat(arrayfun(pointcalc,points1(:,1),'UniformOutput',false)');
            inputcol2 = cell2mat(arrayfun(pointcalc,points2(:,1),'UniformOutput',false)');
            % Get output columns
            outputcol1 = cell2mat(arrayfun(pointcalc,points1(:,2),'UniformOutput',false)');
            outputcol2 = cell2mat(arrayfun(pointcalc,points2(:,2),'UniformOutput',false)');
            % Create output structures
            outheader = cell(1,pointcols*max([points1(:);points2(:)]));
            outheader(:) = {'NaN'};
            M = NaN(numofpoints,pointcols*max([points1(:);points2(:)]));
            % Combine output structures
            outheader(outputcol1) = header1(inputcol1);
            outheader(outputcol2) = header2(inputcol2);
            M(:,outputcol1) = M1(:,inputcol1);
            M(:,outputcol2) = M2(:,inputcol2);            
            % Save the csv file
            writeCSV(fullfile(outfolder,complete1(j).name),outheader,M);
            % Write into log file
            fprintf(fid,'- Csv files found and collated: %s\n', fullfile(folder1,complete1(j).name));            
        else
            fprintf('- No corresponding csv file found for: %s\n', fullfile(folder1,complete1(j).name));
            fprintf(fid,'- No corresponding csv file found for: %s\n', fullfile(folder1,complete1(j).name));
            continue;
        end
    end    
end

% Copy offset files (for a complete transfer)
if ~strcmp(folder1,outfolder)
copyfile(fullfile(folder1,strcat('*',completion_suffix,offset_file_suffix)),...
    outfolder);
fprintf(fid,'- Offset Files copied\n\n');
end
fclose(fid);

end