function [header,M] = readCSV(fileName)
% Reads a complete CSV with first line as header and others as numeric
% data
% Note: Header column length and the M column length don't really have to
% match.
% 
% Dinesh Natesan, 16th July 2015
% 
header = readCsvHeader(fileName);
M = dlmread(fileName,',',1,0);
end

function [header] = readCsvHeader(csvFile)
fid = fopen(csvFile,'r');
line = fgetl(fid);
fclose(fid);
header = strsplit(line,',');
end