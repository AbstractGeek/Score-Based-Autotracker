;% A simple script to create unit test videos for the autotracker
%% Defaults
width = 800;
height = 600;
max_side = min([width, height]);
offset = max([width, height]) - max_side;
radius = 10;

%% Generate DLT coefficients
% Generate fake calibration file and save it
[X, Y, Z] = meshgrid(-1:1:1, -1:1:1, -1:1:1);
points = [X(:), Y(:), Z(:)];
writeCSV('Unit-Test-PointSpecification.csv', {'X', 'Y', 'Z'}, points);
% Get the points from two views
view1 = [(points(:,1)+1)/2 * max_side + offset/2 , ...
    (points(:,2)+1)/2 * max_side] ;  % XY view
view2 = [(points(:,2)+1)/2 * max_side + offset/2 , ...
    (points(:,3)+1)/2 * max_side] ;  % YZ view
% Get the DLT coefficients from it
[view1_coeff, view1_rmse] = dlt_computeCoefficients(points, view1);
[view2_coeff, view2_rmse] = dlt_computeCoefficients(points, view2);
% Write the DLT coefficients file
csvwrite('calib_DLTcoefs.csv', [view1_coeff, view2_coeff]);

%% Compute a simple helical trajectory (in 3D and 2D)
% a simple helix for now
t = (0:0.01:5)';
x = 0.8 * exp(-t./2) .* sin(2*pi*1*t);
y = 0.8 * exp(-t./2) .* cos(2*pi*1*t);
z = linspace(0, 0.8, length(t))';
% plot and show the dataset
waitfor(plot3(x,y,z));

% Get views
view1 = dlt_inverse(view1_coeff, [x,y,z]);
view2 = dlt_inverse(view2_coeff, [x,y,z]);
% extra_offset = (max_side-amplitude)/2;
% view1 = [(x+1)/2 * max_side + offset,...
%     (y+1)/2 * max_side] ;  % XY view
% view2 = [(y+1)/2 * max_side + offset,...
%     (z+1)/2 * max_side] ;  % XY view

% Save true data
writeCSV('helical_original_xyzpts.csv', {'pt1_X', 'pt1_Y', 'pt1_Z'}, ...
    [x, y, z]);
writeCSV('helical_original_xypts.csv', {'pt1_cam1_X', 'pt1_cam1_Y', ...
    'pt1_cam2_X', 'pt1_cam2_Y'}, [view1, view2]);

%% Generate two views of the 3D helical motion
video1 = 'helical_7752.avi';
video2 = 'helical_7880.avi';
vid1 = VideoWriter(video1, 'Grayscale AVI');
open(vid1);
vid2 = VideoWriter(video2, 'Grayscale AVI');
open(vid2);

dispstat('','init');
for i=1:length(t)
    dispstat(sprintf('Adding frame %d of %d', i, length(t)));
    % view 1
    img = zeros(600, 800); % 600x800 matrix
    img = insertShape(img, 'FilledCircle', [view1(i,:), radius],...
        'Color', 'white');
    writeVideo(vid1, flipud(rgb2gray(img)));    
    
    % view 2
        % view 1
    img = zeros(600, 800); % 600x800 matrix
    img = insertShape(img, 'FilledCircle', [view2(i,:), radius],...
        'Color', 'white');
    writeVideo(vid2, flipud(rgb2gray(img)));        
end

close(vid1);
close(vid2);
