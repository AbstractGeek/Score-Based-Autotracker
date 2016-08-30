function [gaussian] = gaussian2D(matrixSize,Mean,Std)
% function [gaussian] = gaussian2D(matrixSize,Mean,Std)
% Generates a 2D gaussian 
% 
% Dinesh Natesan, 1st May 2016

[X,Y] = ndgrid(1:matrixSize(1),1:matrixSize(2));
gaussian = exp(-1*((((X-Mean(1)).^2)./(2*Std(1)^2))+(((Y-Mean(2)).^2)./(2*Std(2)^2))));
end