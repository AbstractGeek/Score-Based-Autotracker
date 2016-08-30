function [output] = normalizeMatrix(input,varargin)

% Check if input is a vector
[m,n,k] = size(input);

if k~=1
    error(strcat('Only takes in 2D Matrix inputs. Inputted matrix size ', m,'x',n,'x',k));
end

% if Image, convert to double first
if (~isempty(varargin) && varargin{1})
    input = im2double(input);
end

% Bring input to zero
input = input - min(min(input));
output = input./iff(min(min(input))==max(max(input)),1,max(max(input)));

% Check if normalization is correct
if min(min(output)) ~=0 && max(max(output))~=1
   warning('Normalization failed!'); 
end

end