function [] = saveInitFrames(videos,calib,points,frames,...
    templateSize,outPrefix,adjustValues,low_high)
%
%
%

folder = fileparts(outPrefix);
if ~isdir(folder)
    mkdir(folder);
end

N = size(points,2)/4;
info1 = rmfield(videos{1}, {'handle', 'name'});
frameSize = [info1.Width info1.Height];
xborder = templateSize(1)/2 + 1;
yborder = templateSize(2)/2 + 1;
padBorder = templateSize(1)/2 + 1;
padFrameSize = frameSize+2*padBorder;
tempSize = templateSize+1;
T = zeros(tempSize(1)*N,tempSize(2),3);

% Run through videos
for i=1:2
    for j=1:length(frames)        
        filename = sprintf('%s_Camera-%d_Frame-%04d.png',outPrefix,i,frames(j));
        I = imsharpen(adjustImageData(mediaRead(videos{i},frames(j)),...
            adjustValues{i},low_high(i,:)));        
        I = insertShape(I,'Rectangle',...
            [xborder yborder info1.Width-2*xborder info1.Height-2*yborder],...
            'Color','yellow');
        paddedI = padarray(I,[padBorder padBorder],'replicate','both');
        
        for k=1:N
            T(tempSize(1)*(k-1)+1:tempSize(1)*k,:,:) = get_track_template(paddedI,...
                points(j,4*k+2*i-5:4*k+2*i-4)+padBorder,templateSize,padFrameSize);
            I = insertMarker(I,points(j,4*k+2*i-5:4*k+2*i-4),'Color','red');

            if i==2
               [m,b]=partialdlt(points(j,4*k-3),points(j,4*k-2),calib(:,1),calib(:,2));
                xpts = [iff(points(j,4*k-1)-50<1,1,points(j,4*k-1)-50),...
                    iff(points(j,4*k-1)+50>800,800,points(j,4*k-1)+50)];
                ypts = m.*xpts+b;
                I = insertShape(I,'Line',...
                    [xpts(1) ypts(1) xpts(2) ypts(2)],'Color','blue');
                [~,res] = dlt_reconstruct(calib,points(j,4*k-3:4*k));
                I = insertText(I,[xpts(1) points(j,4*k)],...
                    sprintf('Res:%0.2g',res),'AnchorPoint','RightBottom');                
            end
            
        end
        
        if size(T,1)<size(I,1)
            [m,n,~] = size(T);
            I(1:m,1:n,:) = uint16(T);            
        else
            disp('TODO:Too many templates-figure out a smart way of stacking');            
        end
        
        imwrite(I,filename);
        
    end
end


end