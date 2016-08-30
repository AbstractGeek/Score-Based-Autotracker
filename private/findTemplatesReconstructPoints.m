function [xy,xyz,res,previous,frame_diff,best_score,min_score]...
    = findTemplatesReconstructPoints(images,calib,templates,search,...
    trackThreshold,dltThreshold,frameSize,minGrid,previous,frame_diff)
%
%
%

N = length(images);
NT = size(templates, 1);
if size(search,1) ~= 1
   fprintf('Search Areas provided: %0.2g\n',size(search,1));
   fprintf('Selecting the largest one: %s\n',num2str(search(size(search,1),:),'%0.2g '));    
   search = search(size(search,1),:);
end
templateSize = size(templates{1});
% Pad images
border = (templateSize(1)-1)/2+1;
newFrameSize = frameSize+2*border;
paddedPrevious = previous;
for i=1:N
    images{i} = padarray(images{i},[border border],'replicate','both');
    paddedPrevious(i,:) = previous(i,:)+border;
end
% create weight array
weight = gaussian2D(templateSize,(templateSize+1)/2,round((templateSize-1)/(2*1.5)));
% initialize
xypeaks = NaN(NT,2*N);
xys = NaN(NT,2*N);
xyzs = NaN(NT,3);
ress = NaN(NT,1);
best_scores = NaN(NT,N); 
min_scores = NaN(NT,1);
max_score = NaN(NT,N);
corners = NaN(N,2);
scores = cell(NT,N);
search_area = cell(N,1);

% Start searching
for k=1:N
    [search_area{k},left_corner] = get_search_area(images{k},paddedPrevious(k,:),search,newFrameSize);
    corners(k,:) = left_corner - border;
end

for j=1:NT
    for k=1:N
        [xypeaks(j,2*k-1),xypeaks(j,2*k-1),max_score(j,k),scores{j,k}]...
        = simpleTemplateMatcher(search_area{k},templates{j,k},weight);
    end    
    [xys(j,:),best_scores(j,:),min_scores(j)]...
        = optimizeTrackedPointsManual(scores{j,1},scores{j,2},corners,calib,...
    templateSize,minGrid,previous,frame_diff);    
    [xyzs(j,:),ress(j)] = dlt_reconstruct(calib,xys(j,:));
end

% Find the most appropriate point
[~,min_index] = sort(min_scores);
% [~,best_index] = sort(-1*sum(best_scores,2));

if (ress(min_index(1)) < dltThreshold) && all(best_scores(min_index(1),:)>trackThreshold) ...
        && sqrt(sum((xys(min_index(1),1:2)-previous(1,:)).^2))<40 ...
        && sqrt(sum((xys(min_index(1),3:4)-previous(2,:)).^2))<40
    % the easy part
    xy = xys(min_index(1),:);
    xyz = xyzs(min_index(1),:);
    res = ress(min_index(1));
    best_score = best_scores(min_index(1),:);
    min_score = min_scores(min_index(1));
    previous = reshape(xy,size(previous))';
    frame_diff = 1;
else
    % no thoughtful sorting for now. Let's see how the basic works.
    xyz = [NaN,NaN,NaN];
    xy = xys(min_index(1),:);
    res = ress(min_index(1));
    best_score = best_scores(min_index(1),:);
    min_score = min_scores(min_index(1));
    frame_diff = frame_diff+1;    
end




end