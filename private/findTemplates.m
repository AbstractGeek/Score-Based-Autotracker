function [track_point,templates,final_max_score,final_scores,corner]...
    = findTemplates(images,templates,search,previous,threshold,frameSize)
% 
% 
% 

N = length(images);
NT = length(templates);
NS = size(search,1);
track_flag = false;
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
weight = gaussian2D(templateSize,(templateSize+1)/2,round((templateSize-1)/(2*2.0)));
% initialize
xpeak = NaN(NT,NS,N);
ypeak = NaN(NT,NS,N);
max_score = NaN(NT,NS,N);
corners = NaN(N,2,NS);
scores = cell(NT,NS,N);
selected = [NaN NaN];
search_area = cell(N,2);

% Start searching

for i=1:NS
    for k=1:N
        [search_area{k},left_corner] = get_search_area(images{k},paddedPrevious(k,:),search(i,:),newFrameSize);
        corners(k,:,i) = left_corner - border;
    end
    
    for j=1:NT
        for k=1:N
            [xpeak(j,i,k),ypeak(j,i,k),max_score(j,i,k),scores{j,i,k}] = simpleTemplateMatcher(search_area{k},templates{j,k},weight);                
        end
        
        if sum(max_score(j,i,:)>threshold) == N
            if j==1
                track_flag = true;
                selected = [i,j];
                break;
            else
                % Rotate templates for speedy performance
                templates = circshift(templates,1-j,1);
                track_flag = true;
                selected = [i,j];
                break;
            end
        end
        
    end
    
end

if track_flag
    i = selected(1);
    j = selected(2);
    track_point = reshape([reshape(xpeak(j,i,:),[1 N]);reshape(ypeak(j,i,:),[1 N])],...
        [1,2*N])+reshape(corners(:,:,i)',[1 2*N]);
    final_max_score = reshape(max_score(j,i,:),[1 N]);
    final_scores = reshape(scores(j,i,:),[1 N]);
    corner = corners(:,:,i);
else
    track_point = NaN(1,2*N);
    % Get the best score and send that row back.     
    % Ignore search template specific differences for now (take the largest
    % search area for now.
    i = NS;
    [M,ind] = max(max_score(:,i,:),[],1);
    if all(ind == ind(1))
        j = ind(1);
        final_max_score = reshape(M,[1 N]);
        final_scores = reshape(scores(j,i,:),[1 N]);
        corner = corners(:,:,i);        
    else
        % find the best sum of scores.
        [~,j] = max(sum(max_score(:,i,:),3));
        final_max_score = reshape(max_score(j,i,:),[1 N]);
        final_scores = reshape(scores(j,i,:),[1 N]);
        corner = corners(:,:,i);                
    end
    
    if sum(final_max_score>threshold)>0        
        cameras = 1:N;
        cam = cameras(final_max_score>threshold);
        for k=1:length(cam)
            track_point(1,2*cam(k)-1:2*cam(k)) = [xpeak(j,i,cam(k)),ypeak(j,i,cam(k))]...
                +corners(cam(k),:,i);
        end
    end
    
    
    % Rotate templates for speedy performance
    if j~=1    
    templates = circshift(templates,1-j,1);    
    end
end


end