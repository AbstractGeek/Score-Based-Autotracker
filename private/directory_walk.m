function [filelist] = directory_walk(folder,pattern,ignore)
% 
% 
% Just a cell array output for now. Modify it into a structure array output
% when required.
% 

% Get file list
filelist = dir(fullfile(folder,pattern));
if size(filelist,1) ~= 0
    filelist = cellfun(@fullfile,cellstr(repmat(folder,size(filelist,1),1)),{filelist(:).name}','UniformOutput',false);
else
    filelist = {};
end
% Get folder list
folderlist = dir(folder);
folderlist = {folderlist([folderlist.isdir]).name}';
folderlist(ismember(folderlist,{'.','..','$RECYCLE.BIN','System Volume Information'})) = [];

for i=1:length(folderlist)
    if cell2mat(regexp(folderlist{i},ignore))
        continue;
    end
    filelist = [filelist;directory_walk(fullfile(folder,folderlist{i}),pattern,ignore)];        
end


end