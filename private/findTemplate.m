function [track_point,templates,final_max_score,final_scores,corner]...
    = findTemplate(image,templates,search,previous,threshold,frameSize)
%
%
%
%

NT = length(templates);
NS = size(search,1);
track_flag = false;
templateSize = size(templates{1});
% initialize
xpeak = NaN(NT,NS);
ypeak = NaN(NT,NS);
max_score = NaN(NT,NS);
corners = NaN(NS,2);
scores = cell(NT,NS);
selected = [NaN NaN];
% pad image
border = (templateSize(1)-1)/2+1;
image = padarray(image,[border border],'replicate','both');
newFrameSize = frameSize+2*border;
paddedPrevious = previous+border;
% create weight array
weight = gaussian2D(templateSize,(templateSize+1)/2,round((templateSize-1)/(2*2.0)));

% Starting with the smallest search area
for i=1:NS
    [search_area,left_corner] = get_search_area(image,paddedPrevious,search(i,:),newFrameSize);
    corners(i,:) = left_corner - border;
    
    for j=1:NT
        [xpeak(j,i),ypeak(j,i),max_score(j,i),scores{j,i}] = simpleTemplateMatcher(search_area,templates{j},weight);
        if max_score(j,i)>threshold
            if j==1
                track_flag = true;
                selected = [i,j];
                break;
            else
                % Rearrange template for speedy performance
                templates = circshift(templates,1-j,1);
                track_flag = true;
                selected = [i,j];
                break;
            end
        end
        
    end
    
end

if track_flag
    track_point = [xpeak(selected(2),selected(1))+corners(selected(1),1)-1,...
        ypeak(selected(2),selected(1))+corners(selected(1),2)-1];
    final_max_score = max_score(selected(2),selected(1));
    final_scores = scores{selected(2),selected(1)};
    corner = corners(selected(1),:);
else
    track_point = [NaN,NaN];
    % Get the best score and send that back.
    [~,ind] = max(max_score(:));
    [selected(2),selected(1)] = ind2sub(size(max_score),ind);
    final_max_score = max_score(selected(2),selected(1));
    final_scores = scores{selected(2),selected(1)};
    corner = corners(selected(1),:);
end

if selected(2)~=1
    templates = circshift(templates,1-selected(2),1);
end
    
end