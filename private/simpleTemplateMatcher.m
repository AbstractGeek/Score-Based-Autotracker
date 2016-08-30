function [x,y,max_score,score_mat] = simpleTemplateMatcher(image,template,weight)
% function [x,y,max_score,scores] = simpleTemplateMatcher(image,template)
% It slides the template over the image and finds the Euclidean distance
% between them. It does not pad zeros over the image in order to reduce
% computation time (and weird errors).
% 
% Breaks down for high image sizes (Use colfilt instead).
% 
% Dinesh Natesan
% Last Modified: 15th Feb 2016

if isinteger(image)
   image = double(image); 
end

if isinteger(template)
    template = double(template);
end

[m,n] = size(template);
[mm,nn] = size(image);
count = (mm-m+1)*(nn-n+1);
if length(weight)==1
    weight = weight.* ones(m*n,1);
else
    weight = weight(:);
end

scores = 1./(sqrt(sum(((im2col(image,[m n],'sliding') - repmat(template(:),1,count)).*repmat(weight,1,count)).^2)));
scores = scores./min(scores);  % Normalizing
[max_score,ind] = max(scores);
[y,x] = ind2sub([mm-m+1 nn-n+1],ind);
score_mat = col2im(scores,[1 1],[mm-m+1 nn-n+1],'sliding');
% surf(score_mat);
x = x + (m+1)/2-1;
y = y + (n+1)/2-1;

end