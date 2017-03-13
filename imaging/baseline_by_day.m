%baseline correction and transient detection across days

mice = string(['md229';'md230';'md231']);
dates = string(['02262017';'02272017';'02282017';'03012017';...
                '03022017';'03032017';'03042017']);
imdir = 'Z:\imaging\wheel_run_5\signals\';
rundir = 'Z:\imaging\wheel_run_5\rpm\';

nummice = size(mice,1);
numdays = size(dates,1);

for d = 1:numdays
    mcount = 0;
    for m = 1:nummice
        filestart = strcat(mice(m,:),'_',dates(d,:));
        %check for existence and load calcium data
        exists = 0;
        cd(imdir)
        imfiles = dir('*.mat');
        for f = 1:numel(imfiles)
            if ~isempty(regexp(imfiles(f).name,filestart))
               %load raw data
               load(imfiles(f).name)
               raw = double(squeeze(raw)');
               %do baseline correction and transient detection
               [dF,nF,zF] = deltaF(raw,4);
               [dT,nT,zT] = detect_trans(dF,nF,zF);
               %save all data to .csv tables
               dFtable = array2table(dF);
               dFname = char(strcat(filestart,'_dF.csv'));
               writetable(dFtable,dFname)
               nFtable = array2table(nF);
               nFname = char(strcat(filestart,'_nF.csv'));
               writetable(nFtable,nFname)
               zFtable = array2table(zF);
               zFname = char(strcat(filestart,'_zF.csv'));
               writetable(zFtable,zFname)
               dTtable = array2table(dT);
               dTname = char(strcat(filestart,'_dT.csv'));
               writetable(dTtable,dTname)
               nTtable = array2table(nT);
               nTname = char(strcat(filestart,'_nT.csv'));
               writetable(nTtable,nTname)
               zTtable = array2table(zT);
               zTname = char(strcat(filestart,'_zT.csv'));
               writetable(zTtable,zTname)
            end
        end                
    end
    disp(sprintf('%s%s','Completed ',num2str(d),' of ',num2str(numdays)))
end
