function [] = createTemplateRepository(varargin)
%CREATETEMPLATEREPOSITORY Summary of this function goes here
%   Detailed explanation goes here

% global defaults
% Filenames
init_file_suffix = '_tracker_init.csv';
init_template_suffix = '_tracker_templates.mat';
% defaults for template saving
templateSize = [100,100];       % Use a big template - just in case

% Get directory and begin
if isempty(varargin)
   % Get input Directory
    inputDir = uigetdir(); 
    filefilter = false;
elseif length(varargin)==1
    inputDir = varargin{1};
    filefilter = false;
else
    inputDir = varargin{1};
    filefiltertext = varargin{2};
    filefilter = true;
end
% Get initfiles
filelist = directory_walk(inputDir,strcat('*',init_file_suffix),{'Digitiz','.Trash'});
if filefilter
    filtered_names = regexp(filelist,filefiltertext,'match');
    filelist(cellfun('isempty',filtered_names))=[];
end
[~,namelist,~] = cellfun(@fileparts,filelist,'UniformOutput',false);

% Get initfiles inputs for template extraction
[inputs,ok] = listdlg('Name','INPUT',...
    'PromptString','Initfile INPUT for template extraction',...
    'ListString',namelist','ListSize',[400 300]);
if ~ok
    disp('Exiting');
    return;
end

% Get initfile output for template saving
[output,ok] = listdlg('Name','OUTPUT',...
    'PromptString','Initfile OUTPUT for saving template',...
    'ListString',namelist,'ListSize',[300 300]);
if ~ok
    disp('Exiting');
    return;
end

for m=1:length(output)
% Get output file names
[path,name,~] = fileparts(filelist{output(m)});  
[header,~] = readCSV(filelist{output(m)});
[~,endind] = regexp(name,header{4});
pointset_suffix = name(endind+1:regexp(strcat(name,'.csv'),init_file_suffix)-1);
prefix = fullfile(path,header{4});
outfilename = strcat(prefix,pointset_suffix,init_template_suffix);
pointset = str2num(header{7}); %#ok<*ST2NM>

% Begin extracting templates
templates = {};
for i=1:length(inputs)
   [path,~,~] = fileparts(filelist{inputs(i)});  
   [header,M] = readCSV(filelist{inputs(i)});
   videos{1} = fullfile(path,header{2});
   videos{2} = fullfile(path,header{3});   
   points = M(:,1:end-1);
   frames = M(:,size(M,2));
   framenum = size(M,1);
   pointnum = str2num(header{7}); %#ok<*ST2NM>
   selected = find(ismember(pointset,pointnum));
   n = length(selected);   
   if n==0
       continue;
   end
   
   templateRepo = cell(framenum,length(pointset)*2);
   
   info1 = cineInfo(videos{1});
   frameSize = [info1.Width,info1.Height];
   
   % Save the true image - no filtering or anything
   for j=1:2       
       for k=1:framenum
           % Obtain image
           I = uint16(cineRead(videos{j},frames(k)));
           % pad image
           border = templateSize./2+1;
           I = padarray(I,border,'replicate','both');           
           for l=1:n
               curr = find(ismember(pointnum,pointset(selected(l))));
               curr_point = points(k,(2*j-1:2*j)+(4*(curr-1)));
               templateRepo{k,j+2*(selected(l)-1)} = ...
                   get_track_template(I,curr_point+border,...
                   templateSize,frameSize+2.*border);               
           end                      
       end       
   end
   
   templates = [templates;templateRepo];
end

save(outfilename,'templates');
end

end

