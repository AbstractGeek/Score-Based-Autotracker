function [T,success] = get_track_template(previousImage,previousPoint,templateSize,frameInfo)
% function [T,success] = get_track_template(previousImage,previousPoint,templateSize,frameInfo)
% Obtains templates for the template tracker
% 
% Dinesh Natesan, 1st May 2016

width = templateSize(1);
height = templateSize(2);
frameWidth = frameInfo(1);
frameHeight = frameInfo(2);
x = previousPoint(1);
y = previousPoint(2);

ymin = iff(round(y)-round(height/2)<1,NaN,round(y)-round(height/2));
ymax = iff(round(y)+round(height/2)>frameHeight,NaN,round(y)+round(height/2));
xmin = iff(round(x)-round(width/2)<1,NaN,round(x)-round(width/2));
xmax = iff(round(x)+round(width/2)>frameWidth,NaN,round(x)+round(width/2));

if sum(isnan([ymin ymax xmin xmax]))~=0
    success = false;
    T = NaN;
else
    success = true;
    T = previousImage(ymin:ymax,xmin:xmax,:);
end


end