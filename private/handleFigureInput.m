function [u,v,success,change] = handleFigureInput(h,FrameSize,redrawfn)
% 
% 
% Needs Matlab after 2014b
% Dinesh Natesan
% 23 Mar 2016

u = NaN;
v = NaN;
run = true;
change = false;
figure(h);
while(run)
  
   if waitforbuttonpress
      % Key Press 
      cc = h.CurrentCharacter;
      if (cc=='=' || cc=='-' || cc=='r')
          zoomIntoImage(h,cc,FrameSize);      
      elseif (cc=='f')
          % Fix this later       
          run = false;
          success = 1;
      elseif (cc=='n')
          run = false;
          success = 0;
      elseif (cc == 'b')
          run = false;
          success = -1;
      end
       
   else
      % Button Press
      cp = h.CurrentAxes.CurrentPoint(1,1:2);      
      u = cp(1);
      v = cp(2);
      redrawfn([u,v]);
      change = true;
   end
    
end


end


function [] = zoomIntoImage(h,cc,FrameSize)
% Zoom operations
% Code from DLTdv5
% Modified by Dinesh Natesan
% 23 Mar 2016
pl=get(0,'PointerLocation'); % pointer location on the screen
pos=get(h,'Position'); % get the figure position
scrsz = get(groot,'ScreenSize');
pos = [iff(pos(1)>scrsz(3),pos(1)-scrsz(3),pos(1)),...
    iff(pos(2)>scrsz(4),pos(2)-scrsz(4),pos(2)),pos(3),pos(4)];
% calculate pointer location in normalized units
plocal=[(pl(1)-pos(1,1)+1)/pos(1,3), (pl(2)-pos(1,2)+1)/pos(1,4)];

axpos=h.CurrentAxes.Position; % axis position in figure
xl=xlim; yl=ylim; % x & y limits on axis
% calculate the normalized position within the axis
plocal2=[(plocal(1)-axpos(1,1))/axpos(1,3) (plocal(2) ...
    -axpos(1,2))/axpos(1,4)];

% check to make sure we're inside the figure!
if sum(plocal2>0.99 | plocal2<0)>0
    disp('The pointer must be over a video during zoom operations.')
    return
end

% calculate the actual pixel postion of the pointer
pixpos=round([(xl(2)-xl(1))*plocal2(1)+xl(1) ...
    (yl(2)-yl(1))*plocal2(2)+yl(1)]);

% axis location in pixels (idealized)
axpix(3)=pos(3)*axpos(3);
axpix(4)=pos(4)*axpos(4);

% adjust pixels for distortion due to normalized axes
xRatio=(axpix(3)/axpix(4))/(diff(xl)/diff(yl));
yRatio=(axpix(4)/axpix(3))/(diff(yl)/diff(xl));
if xRatio > 1
    xmp=xl(1)+(xl(2)-xl(1))/2;
    xmpd=pixpos(1)-xmp;
    pixpos(1)=pixpos(1)+xmpd*(xRatio-1);
elseif yRatio > 1
    ymp=yl(1)+(yl(2)-yl(1))/2;
    ympd=pixpos(2)-ymp;
    pixpos(2)=pixpos(2)+ympd*(yRatio-1);
end
         
% set the figure xlimit and ylimit
if cc=='=' % zoom in
    xlim([pixpos(1)-(xl(2)-xl(1))/3 pixpos(1)+(xl(2)-xl(1))/3]);
    ylim([pixpos(2)-(yl(2)-yl(1))/3 pixpos(2)+(yl(2)-yl(1))/3]);
elseif cc=='-' % zoom out
    xlim([pixpos(1)-(xl(2)-xl(1))/1.5 pixpos(1)+(xl(2)-xl(1))/1.5]);
    ylim([pixpos(2)-(yl(2)-yl(1))/1.5 pixpos(2)+(yl(2)-yl(1))/1.5]);
else % restore zoom
    xlim([0 FrameSize(1)]);
    ylim([0 FrameSize(2)]);
end

% Done, Return
end