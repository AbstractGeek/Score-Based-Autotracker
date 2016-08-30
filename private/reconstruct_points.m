function [xy,xyz,res,previous,frame_diff,best_score,min_score] = reconstruct_points(calib,xyData,...
    scores,corners,dltThreshold,templateSize,minGrid,previous,frame_diff)
% 
% 
% 

if sum(isnan(xyData))<3
    [xy,best_score,min_score] = optimizeTrackedPointsManual(scores{1},scores{2},...
        corners,calib,templateSize,minGrid,previous,frame_diff);  
    [xyz,res] = dlt_reconstruct(calib,xy);
    if res>dltThreshold
        xyz = [NaN,NaN,NaN];  
        xy = xyData;
        best_score = [NaN NaN];
        frame_diff = frame_diff+1;
    else
        previous = reshape(xy,size(previous))';
        frame_diff = 1;
    end    
else
    xyz = [NaN,NaN,NaN];
    xy = xyData;
    res = NaN;
    best_score = [NaN NaN];
    min_score = NaN;
    frame_diff = frame_diff+1;
end

end