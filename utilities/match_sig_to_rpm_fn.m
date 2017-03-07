function [ rpm_fn ] = match_sig_to_rpm_fn( sig_path )
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here




% make matching string ('animal_day')
[fp,sig_fn]=fileparts(sig_path);
ss=strsplit(sig_fn,'_');
animal=ss{1};
day=ss{2};
matching_ss=strcat(animal,'_',day);

% get list of rpm files
sf=fp; % sig folder
strfind(sf,'signals');
sf(24:end)='';
rf=strcat(sf,'rpm\');

files = dir(fullfile(rf, '*.txt')); 
fns={files.name}; % put fns in cell array
rpm_files=strcat(rf,fns); % add dir name 


% find match
index_cell = strfind(rpm_files,matching_ss);
index_match = find(not(cellfun('isempty', index_cell)));

% report
if (length(index_match) > 1)
    display('Multiple matches found, check signals and rpm files');
    rpm_fn='';
elseif ~isempty(index_match)
    rpm_fn=rpm_files{index_match};
else
    rpm_fn='';
    display('No Rpm file found for');
end
end

