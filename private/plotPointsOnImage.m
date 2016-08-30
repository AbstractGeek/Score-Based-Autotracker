function [] = plotPointsOnImage(h,img,cam,currentnum,points,current,calib)
figure(h),clf;
imshow(img);
axis xy;
hold on;
% plot points
for j=1:currentnum-1
    plot(points(1,4*j+2*cam-5),points(1,4*j+2*cam-4),'og');
end
% plot the current one
% if cam==2
if cam==1
    plot(current(:,1),current(:,2),'or');
else
    plot(current(:,1),current(:,2),'or');
    j=currentnum;
    [m,b]=partialdlt(points(1,4*j-3),points(1,4*j-2),calib(:,1),calib(:,2));
%     [m,b]=partialdlt(points(1,4*j-1),points(1,4*j),calib(:,2),calib(:,1));
    xpts = [1,800];
    ypts = m.*xpts+b;
    hold on,plot(xpts,ypts,'-b');
end
drawnow;
end