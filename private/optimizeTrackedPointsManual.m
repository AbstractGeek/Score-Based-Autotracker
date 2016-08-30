function [xy,best_score,min_score] = ...
    optimizeTrackedPointsManual(scores1,scores2,left_corners,calib,...
    templateSize,minGrid,previous,frame_diff)
% [xy] = optimizeTrackedPoints(scores1,scores2,calib,templateSize)
% The true template size not the input template size (must be odd).
% Scores should be a matrix
% 
raw1 = scores1;
raw2 = scores2;
% Remove infs
if sum(isinf(scores1(:)))
    scores1(isinf(scores1)) = 10*max(scores1(~isinf(scores1(:))));
end
if sum(isinf(scores2(:)))
    scores2(isinf(scores2)) = 10*max(scores2(~isinf(scores2(:))));
end

% Calculate scores (with bias)
max1 = max(scores1(:));
max2 = max(scores2(:));
scores1 = (-2.*normalizeMatrix(scores1)+1).*(2*max1/(max1+max2));
scores2 = (-2.*normalizeMatrix(scores2)+1).*(2*max2/(max1+max2));
% Filter
[n1,m1] = size(scores1);
[n2,m2] = size(scores2);
[~,ind1] = sort(scores1(:));
[~,ind2] = sort(scores2(:));
[Y1,X1] = ind2sub([n1,m1],ind1(1:minGrid(1)));
[Y2,X2] = ind2sub([n2,m2],ind2(1:minGrid(2)));

% adjust position matrixes
adjust = [left_corners(1,1) + (templateSize(2)+1)/2 - 2,...
    left_corners(1,2) + (templateSize(1)+1)/2 - 2,...
    left_corners(2,1) + (templateSize(2)+1)/2 - 2,...
    left_corners(2,2) + (templateSize(1)+1)/2 - 2];

view1 = repmat([X1,Y1],length(X2),1);
view2 = repelem([X2,Y2],length(X1),1);
views = [view1,view2]+repmat(adjust,size(view1,1),1);
% find residuals
[xyz,res] = dlt_reconstruct(calib,views);
res_score = log10(res);
res_score(res<=0.1) = -1;
res_score(res>10) = 1;

% % get viewscore1
% view_score1 = round(sqrt(sum((views(:,1:2)-repmat(previous(1,:),size(views,1),1)).^2,2))./frame_diff);
% view_score1(view_score1<1) = 1;
% view_score1(view_score1>100) = 100;
% view_score1 = (log10(view_score1) - 1);
% % get viewscore2
% view_score2 = round(sqrt(sum((views(:,3:4)-repmat(previous(2,:),size(views,1),1)).^2,2))./frame_diff);
% view_score2(view_score2<1) = 1;
% view_score2(view_score2>100) = 100;
% view_score2 = (log10(view_score2) - 1);

% % get xyz score
previousxyz = dlt_reconstruct(calib,[previous(1,:),previous(2,:)]);
xyz_dist = sqrt(sum((xyz-repmat(previousxyz,size(xyz,1),1)).^2,2))./frame_diff;
xyz_score = log10(xyz_dist);
xyz_score(xyz_dist<=0.01) = -2;
xyz_score(xyz_dist>100) = 2;
xyz_score = xyz_score.*0.5;

% get combined score
% combined_score = scores1(sub2ind(size(scores1),view1(:,2),view1(:,1)))+...
%     scores2(sub2ind(size(scores2),view2(:,2),view2(:,1)))+res_score+...
%     view_score1+view_score2;
combined_score = 3.*scores1(sub2ind(size(scores1),view1(:,2),view1(:,1)))+...
    3.*scores2(sub2ind(size(scores2),view2(:,2),view2(:,1)))+res_score+...
    3.*xyz_score;

[min_score,index] = min(combined_score);
xy = views(index,:);
best_score = [raw1(sub2ind(size(scores1),view1(index,2),view1(index,1))),...
    raw2(sub2ind(size(scores2),view2(index,2),view2(index,1)))];

end