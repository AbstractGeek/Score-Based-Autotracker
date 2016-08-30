function [videohandles] = mediaOpen(filenames)
% 
% 
% 
% 
%
% Last Modified On 3 August 2016
% Author: Dinesh Natesan

% Just write for cine files and avi files (for now)


if iscellstr(filenames)
    singleVideoFlag = 0;    
elseif ischar(filenames)
    filenames = {filenames};
    singleVideoFlag = 1;
else
    error('mediaOpen: filenames - Incorrect input type');
end

filenum = length(filenames);    % str cell array
videohandles = cell(filenum, 1);

for i=1:filenum
    [~,~,ext] = fileparts(filenames{i});
    
    switch ext
        
        case '.cine'
            info = cineInfo(filenames{i});
            % Open the file and pass the file handle
            f = fopen(filenames{i});
            C = onCleanup(@() fclose(f));   % Create a cleanup object
            % Seek to the start of the frames
            offset = info.headerPad + 8*info.NumFrames;
            fseek(f,offset,-1);
            % Save as a structure
            videohandles{i}.mode = 'cine';
            videohandles{i}.handle = f;
            videohandles{i}.cleanup = C;            
            videohandles{i}.Width = info.Width;
            videohandles{i}.Height = info.Height;
            videohandles{i}.NumFrames = info.NumFrames;
            videohandles{i}.headerPad = info.headerPad;
            videohandles{i}.bitDepth = info.bitDepth;
            videohandles{i}.currframe = 0;
            videohandles{i}.name = filenames{i};
            
        case '.avi'            
            % Open the file and pass the file handle
            f = VideoReader(filenames{i}); %#ok<TNMLP>            
            % Save as a structure
            videohandles{i}.mode = 'avi';
            videohandles{i}.handle = f;            
            videohandles{i}.Width = f.Width;
            videohandles{i}.Height = f.Height;
            videohandles{i}.Duration = f.Duration;
            videohandles{i}.FrameRate = f.FrameRate;
            videohandles{i}.NumFrames = f.NumberOfFrames;
            videohandles{i}.currframe = 0;
            videohandles{i}.name = filenames{i};
            
        otherwise
            error('mediaOpen.m: Unrecognized media file input');
        
    end  
    
end

if singleVideoFlag
   videohandles = videohandles{1}; 
end

end