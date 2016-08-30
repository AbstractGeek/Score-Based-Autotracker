function [out] = iff(cond,a,b)
% function iff(cond,a,b)
% A custom written function that mimic the traditional C+ conditional 
% expression: out = cond?true:false
% 
% Dinesh Natesam, 6th Mar 2014

if cond
    out = a;
else
    out = b;
end

end