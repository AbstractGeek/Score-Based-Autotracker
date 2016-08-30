function [T,left_corner] = get_search_area(previousImage,previousPoint,templateSize,frameInfo)

width = templateSize(1);
height = templateSize(2);
frameWidth = frameInfo(1);
frameHeight = frameInfo(2);
x = previousPoint(1);
y = previousPoint(2);

ymin = iff(round(y)-round(height/2)<1,1,round(y)-round(height/2));
ymax = iff(round(y)+round(height/2)>frameHeight,frameHeight,round(y)+round(height/2));
xmin = iff(round(x)-round(width/2)<1,1,round(x)-round(width/2));
xmax = iff(round(x)+round(width/2)>frameWidth,frameWidth,round(x)+round(width/2));

T = previousImage(ymin:ymax,xmin:xmax);
left_corner = [xmin,ymin];

end