function [] = writeCSV(fileName,header,M)
% Writes a complete CSV with first line as header and others as numeric
% data
% Note: Header column length and the M column length don't really have to
% match.
% 
% Dinesh Natesan, 16th July 2015
% 
writeCsvHeader(fileName,header);
dlmwrite(fileName,M,'-append');
% writeCsvMatrix(fileName,M);

end

function [] = writeCsvHeader(csvFile,header)
fid = fopen(csvFile,'w');
for i=1:length(header)-1
    fprintf(fid,'%s,',header{i});
end
fprintf(fid,'%s\n',header{end});
fclose(fid);
end

function [] = writeCsvMatrix(csvFile,M)
fid = fopen(csvFile,'a');
for i=1:size(M,1)
    str = sprintf('%0.6g,',M(i,:));    
    fprintf(fid,'%s\n',str(1:end-1));    
end
fclose(fid);
end