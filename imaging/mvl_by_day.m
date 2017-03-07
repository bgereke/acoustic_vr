%mean vector length distributions across days

mice = string(['md229';'md230';'md231']);
dates = string(['0226';'0227';'0228';'0301';'0302';'0303';'0304']);
imdir = 'Z:\imaging\wheel_run_5\signals\';
rundir = 'Z:\imaging\wheel_run_5\rpm\';

nummice = size(mice,1);
numdays = size(dates,1);
numbins = 25;
hgrid = linspace(-1,1,numbins);
MVL_d = zeros(numdays,numbins);
frac_pos = zeros(numdays,3); %fraction of positive dbmvl for each day with bootstrapped confidence intervals
numboots = 10000; %numbootstraps

for d = 1:numdays
    DBMVL = cell(1,1); %store all the dbmvl's for bootstrapping 
    mcount = 0;
    for m = 1:nummice
        filestart = strcat(mice(m,:),'_',dates(d,:));
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
            mcount = mcount + 1;
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
            [maps,grid,mvl,dbmvl,bpsl,bptl] = ratemap(nF,runtable.lap_position,ct,ard_timestamp,100,'nthresh','vonMises',30);
            MVL_d(d,:) = MVL_d(d,:) + hist(dbmvl,hgrid);
            DBMVL{mcount} = dbmvl;
        end             
        %do multilevel bootstrap
        nummice_d = numel(DBMVL);
        numpos = 0;numtot = 0;
        for nm = 1:nummice_d
            numpos = numpos + sum(DBMVL{nm}>0);
            numtot = numtot + length(DBMVL{nm});
        end
        frac_pos(d,1) = numpos/numtot;
        bootfracpos = zeros(numboots,1);
        for b = 1:numboots
            samp = [];
            mboot = randsample(nummice_d,nummice_d,true); %random draw from this day's mice
            %random draw from mouse's dbmvl's
            for bm = 1:nummice_d
               samp = [samp; randsample(DBMVL{mboot(bm)},length(DBMVL{mboot(bm)}),true)]; 
            end
            bootfracpos(b) = sum(samp>0)/length(samp);
        end
        frac_pos(d,2:3) = quantile(bootfracpos,[0.025 0.975]);
    end
    disp(sprintf('%s%s','Completed ',num2str(d),' of ',num2str(numdays)))
end
%covert to probabilities
MVL_d = MVL_d./repmat(sum(MVL_d,2),1,size(MVL_d,2));
%make plot
c = colormap(copper(numdays));
for d = 1:numdays
 hold on
 plot(hgrid,MVL_d(d,:),'LineWidth',2,'Color',c(d,:)');
end
legend(strread(num2str(1:numdays),'%s'))
xlabel('mean vector length')
ylabel('probability')
xlim([-1 1])

figure
for d = 1:numdays
   hold on
   plot([d d],frac_pos(d,2:3),'-k');
   plot(d,frac_pos(d,1),'ok');
end
plot([0 numdays+1],[0.5 0.5],'--k');
xlabel('day')
ylabel('fraction of positive debiased mean vector lengths')
xlim([0 numdays+1])
ylim([0 1])