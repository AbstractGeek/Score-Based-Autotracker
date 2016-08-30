    function [points,templateRepo] = getTrackPoints(videos,calib,templateRepo,...
    pointnum,frames,templateSize,adjustValues,low_high)
%
%
%
%
%

% global defaults
searchSize = [100 100];
threshold = 5;
weight = gaussian2D(templateSize+1,(templateSize+2)/2,round((templateSize)/(2*2.0)));

% sanity checks
if strcmp(videos{1}.mode, 'avi')
    info1 = rmfield(videos{1}, {'handle', 'name'});
    info2 = rmfield(videos{2}, {'handle', 'name'});
else
    info1 = rmfield(videos{1}, {'handle', 'name','cleanup'});
    info2 = rmfield(videos{2}, {'handle', 'name','cleanup'});
end

if ~isequaln(info1,info2)
    disp('Camera information do not match');
    fprintf('Camera 1: \n%s\n',struct2str(info1));
    fprintf('Camera 2: \n%s\n',struct2str(info2));
    error('Camera headers from the two cameras are not equal!');
end
% get filenames
filesplit1 = strsplit(videos{1}.name,filesep);
filesplit2 = strsplit(videos{2}.name,filesep);
file1 = strjoin(filesplit1(end-2:end),filesep);
file2 = strjoin(filesplit2(end-2:end),filesep);
frameSize = [info1.Width info1.Height];

xborder = templateSize(1)/2 + 1;
yborder = templateSize(2)/2 + 1;
padBorder = templateSize(1)/2 + 1;
padFrameSize = frameSize+2*padBorder;

points = NaN(length(frames),2*pointnum);
h{1} = figure('Name',file1,'pointer','cross');
h{2} = figure('Name',file2,'pointer','cross');

for i=1:length(frames)
    I{1} = imsharpen(adjustImageData(mediaRead(videos{1},frames(i)),...
        adjustValues{1},low_high(1,:)));
    I{2} = imsharpen(adjustImageData(mediaRead(videos{2},frames(i)),...
        adjustValues{2},low_high(2,:)));
    dispI{1} = insertShape(I{1},'Rectangle',...
        [xborder yborder info1.Width-2*xborder info1.Height-2*yborder],...
        'Color','yellow');
    dispI{1} = insertText(dispI{1},[1,1],sprintf('frame: %05d',i));
    dispI{2} = insertShape(I{2},'Rectangle',...
        [xborder yborder info1.Width-2*xborder info1.Height-2*yborder],...
        'Color','yellow');
    dispI{2} = insertText(dispI{2},[1 1],sprintf('frame: %05d',i));
    % pad images
    I{1} =  padarray(I{1},[padBorder padBorder],'replicate','both');
    I{2} =  padarray(I{2},[padBorder padBorder],'replicate','both');
    
    for j=1:pointnum
        % Loop through cameras.
%         for k=2:-1:1
        for k=1:1:2
            found = false;
            redrawfn = @(current) plotPointsOnImage(h{k},dispI{k},k,j,points(i,:),current,calib);
            % Use templates first if they are not empty
            if ~isempty(templateRepo) && length(templateRepo)>=j && length(templateRepo{j})>=k
                l = 1;
                while l<=size(templateRepo{j}{k},1)
                    [s,left_corner] = get_search_area(I{k},templateRepo{j}{k}{l,1},searchSize,padFrameSize);
                    left_corner = left_corner - padBorder;
                    [xpeak,ypeak,max_score,~] = simpleTemplateMatcher(s,templateRepo{j}{k}{l,2},weight);
                    if max_score>threshold
                        u = xpeak+left_corner(1)-1;
                        v = ypeak+left_corner(2)-1;
                        redrawfn([u,v]);
                        [uh,vh,success,change] = handleFigureInput(h{k},frameSize,redrawfn);                        
                        if (success==1)
                            if change
                                points(i,4*j+2*k-5:4*j+2*k-4) = [uh,vh];
                                found = true;
                                break;
                            else
                                points(i,4*j+2*k-5:4*j+2*k-4) = [u,v];
                                found = true;
                                break;
                            end
                        elseif (success == -1)
                            l = l-1;
                        else 
                            l = l+1;
                        end
                    else 
                        l = l+1;                        
                    end
                end
            end
            if ~found
                % Get the point manually
                redrawfn([NaN,NaN]);
%                 plotPointsOnImage(h{k},dispI{k},k,j,points(i,:),[NaN,NaN],calib);
                % add a while loop here to circumvent the track problem
%                 confirm = 'n';
%                 while ~(strcmp(confirm, 'Y') || strcmp(confirm,'y'))
                    success = false;
                    while ~success
                        % [u,v] = ginput(1);
                        [uh,vh,~,~] = handleFigureInput(h{k},frameSize,redrawfn);
                        [~,success] = get_track_template(I{k},[uh,vh]+padBorder,templateSize,padFrameSize);
                    end
%                     hold on,plot(u,v,'or');
%                     confirm = input('Does the point look good(Y/N)?: ','s');
%                 end
                
                points(i,4*j+2*k-5:4*j+2*k-4) = [uh,vh];
                change = true;
            end
            
            if (change)
                change = false;
                [T,success] = get_track_template(I{k},[uh,vh]+padBorder,templateSize,padFrameSize);
                if success
                    % Save the templates
                    temp = {[uh,vh],T};
                    if isempty(templateRepo) || length(templateRepo)<j || length(templateRepo{j})<k
                        templateRepo{j}{k} = temp;
                    else
                        templateRepo{j}{k} = [temp;templateRepo{j}{k}];
                    end
                else
                    warning('getTrackPoints: Template cannot be added as it was very close to the border');
                end
                % Clean templates (keep only 2)
                templateRepo{j}{k}(3:end,:) = [];
            end

            
        end
        
        
        
    end
    
    
end
close(h{1});
close(h{2});

end

