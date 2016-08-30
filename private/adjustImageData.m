function newI = adjustImageData(I, adjustValues, low_high)
% function newI = adjustImageData(I, adjustValues)
% 
% Borrowed and modified from the builtin imcontrast function
% 
% Dinesh Natesan
% 3rd March 2016

% Get necessary values
newMin = adjustValues(1);
newMax = adjustValues(2);
defaultRange = adjustValues(3:4);

% Scale I
I = imadjust(I,low_high);

% translate to the new min to "zero out" the data
newI = I - newMin;

% apply a linear stretch of the data such that the selected data range
% spans the entire default data range
scaleFactor = (defaultRange(2)-defaultRange(1)) / (newMax-newMin);
newI = newI .* scaleFactor;

% translate data to the appropriate lower bound of the default data range.
% this translation is here in anticipation of image datatypes in the future
% with signed data, such as int16
newI = newI + defaultRange(1);

% clip all data that falls outside the default range
newI(newI < defaultRange(1)) = defaultRange(1);
newI(newI > defaultRange(2)) = defaultRange(2);

end