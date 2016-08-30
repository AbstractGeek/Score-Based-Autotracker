function [adjustValues,low_high] = getImageAdjustment(video1,video2)
% function [adjustValues] = getImageAdjustment(cine1,cine2)
% This function will work only if the changeimcontrast function 
% (modified built in imcontrast gui) is used to give out adjustvalues. 
% Quite a simple hack. 
% 
% Dinesh Natesan
% 3rd March 2016
adjustValues = cell(2,1);
low_high = NaN(2,2);

f1 = mediaOpen(video1);
I = mediaRead(f1,1);
low_high(1,:) = stretchlim(I);
h1 = imshow(imadjust(I,low_high(1,:)));
h2 = changeimcontrast(h1);
waitfor(h2);
adjustVals = getappdata(h1,'adjustValues');
adjustValues{1} = [adjustVals.newmin adjustVals.newmax adjustVals.defaultRange];
close(h1.Parent.Parent)

f2 = mediaOpen(video2);
I = mediaRead(f2,1);
low_high(2,:) = stretchlim(I);
h1 = imshow(imadjust(I,low_high(2,:)));
h2 = changeimcontrast(h1);
waitfor(h2);
adjustVals = getappdata(h1,'adjustValues');
adjustValues{2} = [adjustVals.newmin adjustVals.newmax adjustVals.defaultRange];
close(h1.Parent.Parent)
end