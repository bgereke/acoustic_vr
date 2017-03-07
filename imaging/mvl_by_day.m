%mean vector length distributions across days

mice = string(['md229';'md230';'md231']);
dates = string(['0226';'0227';'0228';'0301';'0302';'0303';'0304']);
imdir = 'Z:\imaging\wheel_run_5\signals/';
rundir = 'Z:\imaging\wheel_run_5\rpm/';

nummice = length(mice);
numdays = length(dates);
numbins = 15;
hgrid = linspace(0,1,numbins);
MVL_d = zeros(numdays,numbins);

for d = 1:numdays
    for m = 1:nummice
        filestart = strcat(mice(m),'_',dates(d));
        %check for existence and load calcium data
        exists = 0;
        cd(imdir)
        imfiles = dir('*.mat');
        for f = 1:numel(imfiles)
            if ~isempty(regexp(imfiles(f).name,filestart))
               load(imfiles(f).name)
               exists = 1;
            end
        end
        if exists
            %load run data
            cd(rundir)
            runfiles = dir('*.txt');
            for f = 1:numel(runfiles)
                if ~isempty(regexp(runfiles(f).name,filestart))
                    runtable = readtable(runfiles(f).name,'Delimiter',',','ReadVariableNames',true);
                end
            end
            %get mvl for day mouse combo
            cdt=1/10.088781275221955;
            raw = double(squeeze(raw)');
            ct = cdt*ones(size(raw,1),1);
            ct = cumsum(ct);
            ard_timestamp = (runtable.ard_timestamp - min(runtable.ard_timestamp))/1000 + cdt;
            [dF,nF,zF] = deltaF(raw,2);
            [maps,grid,nmvl,bpsl,bptl] = ratemap(nF,runtable.lap_position,ct,ard_timestamp,100,'nthresh','vonMises',30);
            MVL_d(d,:) = MVL_d(d,:) + hist(nmvl,hgrid);
        end        
    end
end
%covert to probabilities
MVL_d = MVL_d./repmat(sum(MVL_d,2),1,size(MVL_d,2));
%make plot
c = colormap(copper(numdays));
for d = 1:numdays
 hold on
 plot(hgrid,MVL_d(d,:),'LineWidth',2,'Color',c(d,:)');
end
legend(string(1:numdays))
xlabel('mean vector length')
ylabel('probability')
xlim([0 1])
