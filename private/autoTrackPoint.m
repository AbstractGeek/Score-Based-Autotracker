function [xyData,xyzData,xyzRes,max_score,best_score,min_score] = ...
    autoTrackPoint(videos,xyData,templates,calib,default)
% function [] = autoTrackPoint()
% This function tracks the initialized point over the inputted videos,
% checks the digitized point over the calibration and then saves the
% digitized data as outfiles (using the out_prefix). The defaults control
% the search and track behavior of this function.
%
% defaults should be a struct with the following fields:
% defaults.start
% defaults.end
% defaults.evolution
% defaults.template - an array with rows containing the template size
% defaults.frameInfo
%
% Dinesh Natesan
% Modified: 16th Feb 2016
% Modified: 11th March 2016


% Extract default parameters
start_frame = default.start;
end_frame = default.end;

% evolution = default.evolution;
low_high = default.low_high;
frameSize = default.frameSize;
search = default.searchAreas;
trackThreshold = default.trackThreshold;
dltThreshold = default.dltThreshold;
adjustValues = default.adjustValues;
minGrid = default.minGrid;

% Assume videos have already been double checked! Initialize necessary
% information
N = numel(videos);
numofframes = size(xyData,1);
% Initialize data matrixes
xyzData = NaN(numofframes,3);
xyzRes = NaN(numofframes,1);
previous = reshape(xyData(start_frame,:),[2,2])';
frame_diff = 1;
max_score = NaN(numofframes,N);
best_score = NaN(numofframes,N);
min_score = NaN(numofframes,1);
I = cell(N,1);
% Intialize Adaptive templates?

% dispstat('','init');
for i=start_frame:end_frame
%     dispstat(sprintf('Tracking frame-%d(/%d)',i,end_frame),'timestamp');
      
    if ~all(isnan(xyData(i,:)))
        [xyzData(i,:),xyzRes(i)] = dlt_reconstruct(calib,xyData(i,:));
        best_score(i,:) = inf;
        min_score(i,:) = -10;
        previous = reshape(xyData(i,:),[2,2])';
        frame_diff = 1;
    else
        for j=1:N
            I{j} = imsharpen(adjustImageData(mediaRead(videos{j},i),adjustValues{j},low_high(j,:)));
        end
        
        [xyData(i,:),xyzData(i,:),xyzRes(i),previous,frame_diff,best_score(i,:),min_score(i)]...
            = findTemplatesReconstructPoints(I,calib,templates,search,...
            trackThreshold,dltThreshold,frameSize,minGrid,previous,frame_diff);
    end
    
%     % Save images
%     Icomb = [];
%     for j=1:N
%         if ~isnan(xyData(i,2*j-1:2*j))
%             I{j} = insertMarker(I{j},xyData(i,2*j-1:2*j),'o','Color','Green');
%         else
%             I{j} = insertMarker(I{j},previous(j,:),'o','Color','Red','size',6);
%         end       
%        
%         Icomb = [Icomb,I{j}];
%     end
%     if isempty(Icomb)
%        continue; 
%     end
%     Icomb = flipud(Icomb);
%     text = sprintf('DLT Residual0: %0.2g, BestScore0: %s, MinScore0: %s',...
%         xyzRes(i),...
%         num2str(best_score(i,:),'%0.2g '),num2str(min_score(i,:),'%0.2g '));    
%     Icomb = insertText(Icomb, [1 600],...
%         sprintf('Autotracked (Frame %05d)\n%s',...
%         i,text),'AnchorPoint','LeftBottom');
%     imwrite(Icomb,fullfile(pwd,'Test',sprintf('%05d.png',i)));    
    
end

end