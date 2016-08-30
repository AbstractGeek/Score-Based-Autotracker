function [xy,best_score] = optimizeTrackedPointsGA(scores1,scores2,center,left_corners,calib,templateSize)
% [xy] = optimizeTrackedPoints(scores1,scores2,calib,templateSize)
% The true template size not the input template size (must be odd).
% Scores should be a matrix
% 
raw1 = scores1;
raw2 = scores2;
% Remove infs
if sum(isinf(scores1(:)))
    scores1(isinf(scores1)) = 100*max(scores1(~isinf(scores1(:))));
end
if sum(isinf(scores2(:)))
    scores2(isinf(scores2)) = 100*max(scores2(~isinf(scores2(:))));
end
% Filter
bias = max(scores1(:))/max(scores2(:));
scores1 = (-2.*normalizeMatrix(scores1)+1).*bias;
scores2 = -2.*normalizeMatrix(scores2)+1;
[n1,m1] = size(scores1);
[n2,m2] = size(scores2);
[Y1,X1] = ndgrid(1:n1,1:m1);
[Y2,X2] = ndgrid(1:n2,1:m2);
frame_center = round([(m1+1)/2,(n1+1)/2,...
    (m2+1)/2,(n2+1)/2]);
lb = [1,1,1,1];
ub = [m1,n1,m2,n2];
% Adjust X and Y
adjust = [left_corners(1,1) + (templateSize(2)+1)/2 - 2,...
    left_corners(1,2) + (templateSize(1)+1)/2 - 2,...
    left_corners(2,1) + (templateSize(2)+1)/2 - 2,...
    left_corners(2,2) + (templateSize(1)+1)/2 - 2];
X1 = X1 + adjust(1);
Y1 = Y1 + adjust(2);
X2 = X2 + adjust(3);
Y2 = Y2 + adjust(4);
frame_center = frame_center + adjust;
lb = lb+adjust;
ub = ub+adjust;
center(isnan(center)) = frame_center(isnan(center));

% Optimize
% options = gaoptimset('PlotFcns',@gaplotbestf,'Vectorized','on');
options = gaoptimset('Vectorized','on','Display','off');
IntCon = [1,2,3,4];
xy = ga(@optimizePoints,4,[],[],[],[],lb,ub,[],IntCon,options);
% xy = fmincon(@optimizePoints,center,[],[],[],[],lb,ub,[],options);
best_score = [interp2(X1,Y1,raw1,xy(1),xy(2)),...
    interp2(X2,Y2,raw2,xy(3),xy(4))];

    function [out] = optimizePoints(x)
        score1 = interp2(X1,Y1,scores1,x(:,1),x(:,2));
        score2 = interp2(X2,Y2,scores2,x(:,3),x(:,4));
        [~,res] = dlt_reconstruct(calib,x);
        res_score = log10(res);
        res_score(res<=0.1) = -1;
        res_score(res>10) = 1;        
        out = score1+score2+2*res_score;
    end

end