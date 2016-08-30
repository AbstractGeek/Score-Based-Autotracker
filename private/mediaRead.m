function [img, videohandle] = mediaRead(videohandle,framenum)
%
%
%
%
%
% Last Modified On 3 August 2016
% Author: Dinesh Natesan

switch videohandle.mode
    
    case 'cine'
        
        f = videohandle.handle;
        % Seek to the start of the frame
        offset = videohandle.headerPad + 8 * videohandle.NumFrames + ...
            8 * framenum + (framenum-1)* (videohandle.Height * ...
            videohandle.Width *videohandle.bitDepth/8);
        fseek(f, offset, -1);
        
        % Get image data
        if videohandle.bitDepth == 8 % 8bit gray
            idata = fread(f, videohandle.Height * videohandle.Width,...
                '*uint8');
            nDim = 1;
        elseif videohandle.bitDepth == 16 % 16bit gray
            idata = fread(f, videohandle.Height * videohandle.Width,...
                '*uint16');
            nDim = 1;
        elseif videohandle.bitDepth == 24 % 24bit color
            idata = double(fread(f,...
                videohandle.Height * videohandle.Width * 3,...
                '*uint8'))/255;
            nDim = 3;
        else
            disp('error: unknown bitdepth')
            return
        end
        
        img = zeros(videohandle.Height, videohandle.Width, nDim);
        for i = 1:nDim
            tdata = reshape(idata(i:nDim:end),...
                videohandle.Width, videohandle.Height);
            img(:,:,i) = fliplr(rot90(tdata, -1));
        end
        
        % Bring it back to the required format
        if (videohandle.bitDepth == 8) || (videohandle.bitDepth == 24)
            img = uint8(img);
        else
            img = uint16(img);
        end
        
    case 'avi'
        
        img = flipud(read(videohandle.handle, framenum));
        
    otherwise
        
        error('MediaRead: Invalid (Unsupported) format %s', ext);
        
end

videohandle.currframe = framenum;

end