function [optimized,corrR] = optimizeTrackingTemplates(templates,templateSimilarity)
%OPTIMIZETRACKINGTEMPLATES Summary of this function goes here
%   Detailed explanation goes here

% Using corr2 to find very correlated templates and deleting them
% Not using ssim (Structural Similarity Index) because it compares similar
% images for human perception. Might mislead the template tracker. Also it
% deletes a lot of templates because it thinks all of them are similar

[N,n]= size(templates);
if n>2
    error('optimizeTrackingTemplates: Currently only supports templates (cell arrays) with two columns');
end

ssimR = NaN(N,N,2);
corrR = NaN(N,N,2);
optimized = templates;
deleteMatrix = [];

for i=2:N    
    for j=1:i-1
        if ismember(j,deleteMatrix)
           continue; 
        end
        corrR(i,j,1) = corr2(templates{j,1},templates{i,1});
        ssimR(i,j,1) = ssim(templates{j,1},templates{i,1});
        ssimR(i,j,2) = ssim(templates{j,2},templates{i,2});
        if corrR(i,j,1) > templateSimilarity
            corrR(i,j,2) = corr2(templates{j,2},templates{i,2});                        
            if corrR(i,j,2) > templateSimilarity
               deleteMatrix = [deleteMatrix;i]; 
               break;
            end
        end
    end    
end

optimized(deleteMatrix,:) = [];
end

