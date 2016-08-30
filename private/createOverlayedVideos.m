function [] = createOverlayedVideos(videos,xyData,calib,resData,minScore,bestScore,templateSize,adjustValues,outFile)
%
% Video inputs are handles generated from mediaOpen
%
%
%

% default thresholds
dlt_threshold = 3;

videonum = numel(videos);
sav = VideoWriter(outFile);
sav.FrameRate = 15;
open(sav);

info1 = rmfield(videos{1}, {'handle', 'name'});
I = cell(2,1);
if strcmp(info1.mode, 'cine')
    Icomb = uint16(zeros(info1.Height,info1.Width*videonum,3));
else
    Icomb = uint8(zeros(info1.Height,info1.Width*videonum,3));
end
framenum = info1.NumFrames;
pointnum = size(xyData,2)/4;
xborder = templateSize(1)/2 + 1;
yborder = templateSize(2)/2 + 1;

low_high = NaN(videonum,2);
for j=1:videonum
    low_high(j,:) = stretchlim(mediaRead(videos{j},1));
end

% dispstat('','init');
for i=1:framenum
%     dispstat(sprintf('Tracking frame-%d(/%d)',i,framenum),'timestamp');
    for j=1:videonum
        I{j} = imsharpen(adjustImageData(mediaRead(videos{j},i),adjustValues{j},low_high(j,:)));
        I{j} = insertShape(I{j},'Rectangle',...
            [xborder yborder info1.Width-2*xborder info1.Height-2*yborder],...
            'Color','yellow');       
        
        for k=1:pointnum
            if sum(isnan(xyData(i,4*k+2*j-5:4*k+2*j-4)))==0
                if isnan(resData(i,k)) || resData(i,k)>dlt_threshold
                    I{j} = insertMarker(I{j},xyData(i,4*k+2*j-5:4*k+2*j-4),'size',6,'Color','red');
                    I{j} = insertMarker(I{j},xyData(i,4*k+2*j-5:4*k+2*j-4),'o','size',6,'Color','red');
                    I{j} = insertMarker(I{j},xyData(i,4*k+2*j-5:4*k+2*j-4),'o','size',9,'Color','red');
                    I{j} = insertMarker(I{j},xyData(i,4*k+2*j-5:4*k+2*j-4),'o','size',12,'Color','red');
                    I{j} = insertMarker(I{j},xyData(i,4*k+2*j-5:4*k+2*j-4),'o','size',15,'Color','red');
                else
                    I{j} = insertMarker(I{j},xyData(i,4*k+2*j-5:4*k+2*j-4),'size',6,'Color','green');
                    I{j} = insertMarker(I{j},xyData(i,4*k+2*j-5:4*k+2*j-4),'o','size',6,'Color','green');
                end
            end
                
                if j==1 && sum(isnan(xyData(i,4*k+2*j-3:4*k+2*j-2)))==0
                    [m,b]=partialdlt(xyData(i,4*k+2*j-3),xyData(i,4*k+2*j-2),calib(:,j+1),calib(:,j));
                    xpts = [iff(xyData(i,4*k+2*j-5)<1,1,xyData(i,4*k+2*j-5)-50),...
                        iff(xyData(i,4*k+2*j-5)>info1.Width,info1.Width,xyData(i,4*k+2*j-5)+50)];
                    if sum(isnan(xpts))
                        xpts = [1 info1.Width];
                    end
                    ypts = m.*xpts+b;
                    I{j} = insertShape(I{j},'Line',...
                        [xpts(1) ypts(1) xpts(2) ypts(2)],'Color','blue');
                elseif j>1 && sum(isnan(xyData(i,4*k+2*j-7:4*k+2*j-6)))==0
                    [m,b]=partialdlt(xyData(i,4*k+2*j-7),xyData(i,4*k+2*j-6),calib(:,j-1),calib(:,j));
                    xpts = [iff(xyData(i,4*k+2*j-5)<1,1,xyData(i,4*k+2*j-5)-50),...
                        iff(xyData(i,4*k+2*j-5)>info1.Width,info1.Width,xyData(i,4*k+2*j-5)+50)];
                    if sum(isnan(xpts))
                        xpts = [1 info1.Width];
                    end
                    ypts = m.*xpts+b;
                    I{j} = insertShape(I{j},'Line',...
                        [xpts(1) ypts(1) xpts(2) ypts(2)],'Color','blue');
                end
            
        end
        
        Icomb(:,info1.Width*(j-1)+1:info1.Width*j,:) = I{j};
    end    
    Icomb = flipud(Icomb);
    Icomb = insertText(Icomb,[1,1],sprintf('Frame: %05d',i),'AnchorPoint','LeftTop','FontSize',24);
    Icomb = insertText(Icomb,[1,info1.Height],...
            sprintf('DLT Residuals: %s\n MinScore: %s\n BestScore: %s\n',...
            num2str(resData(i,:),'%0.2f, '),num2str(minScore(i,:),'%0.2f, '),...
            strjoin(cellstr(num2str(reshape(bestScore(i,:),2,pointnum)','%0.2f, ')),';')),...
            'AnchorPoint','LeftBottom');
        
    writeVideo(sav,im2double(Icomb));
end
open(sav);

end