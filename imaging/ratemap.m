function [maps, pmap, grid, mvl, dbmvl, mvlp, bps, bpt, ftrans] = ratemap(F,pos,it,pt,ngrid,tmethod,kmethod,FWHM)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Compute spatial rate maps for calcium flourescence imaging data
%Input:
%F - [numframes x numcells] matrix of calcium flourescence
%pos - column vector of position samples
%it - column vector of length numframes specifying the time of each imaging frame
%pt - column vector specifying the time of each position sample
%ngrid - number of points at which to evaluate rate map
%tmethod - method for transient detection
%          can be: 'nthresh', 'zthresh','deconv', or 'none'
%          must supply 'nF'/'zF'/'dF' when using 'nthresh'/'zthresh'/'deconv' respectively
%kmethod - method for kernel density estimation
%          can be: 'gaussian' or 'vonMises' for 'linear' or 'circular' positions respectively
%FWHM - kernel full width at half max in position units
%Output:
%maps - [ngrid x numcells] matrix of rate maps
%pmap - ngrid length vector specifying ratemap for transients from entire population
%grid - vector of length ngrid specifying position of rate map
%bps - vector of length numcells specifying spatial information for each map in bits per second
%mvl - mean vector length of transient complex sum (only for vonMises)
%dbmvl - a debiased version of mvl
%mvlp - approximate p-value for each mvl
%bpt - vector of length numcells specifying spatial information for each map in bits per transient
%ftrans - [numframes x numcells] matrix specifying full binarized transients for each cell
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Example - [maps,grid,bps,bpt] = ratemap(dF,lap_position,ct,ard_timestamp,100,'deconv','vonMises',30);
%ct and ard_timestamp are from 'plot_dF_on_pos.m'
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[numframes, numcells] = size(F);
mvl = nan(numcells,1);
dbmvl = nan(numcells,1);
mvlp = nan(numcells,1);

%detect transients
trans = zeros(size(F)); %transients
ftrans = trans; %full binarized transients for output
if strcmp(tmethod,'nthresh')
    trans = zeros(size(F));
    hthresh = F>1; %upper threshold
    lthresh = F>0.5; %lower threshold
    dhthresh = [zeros(1,numcells);diff(hthresh)];
    dlthresh = [zeros(1,numcells);diff(lthresh)];
    for c = 1:numcells
       hidx = find(dhthresh(:,c)==1); %high threshold crossings
       lup = find(dlthresh(:,c)==1); %low threshold upward crossings
       ldown = find(dlthresh(:,c)==-1); %low threshold downward crossings
       for h = 1:length(hidx)
           sidx = lup(find(lup<hidx(h),1,'last'));
           eidx = ldown(find(ldown>hidx(h),1,'first'));
           if ~isempty(sidx)>0 && ~isempty(eidx)>0
               w = eidx-sidx;
               if w >= 4 %delete transients that aren't wide enough
                  trans(sidx,c) = 1; 
                  ftrans(sidx:eidx,c) = 1;
               end
           end
       end
    end
elseif strcmp(tmethod,'zthresh')
    trans = zeros(size(F));
    hthresh = F>3; %upper threshold
    lthresh = F>1.5; %lower threshold
    dhthresh = [zeros(1,numcells);diff(hthresh)];
    dlthresh = [zeros(1,numcells);diff(lthresh)];
    for c = 1:numcells
       hidx = find(dhthresh(:,c)==1); %high threshold crossings
       lup = find(dlthresh(:,c)==1); %low threshold upward crossings
       ldown = find(dlthresh(:,c)==-1); %low threshold downward crossings
       for h = 1:length(hidx)
           sidx = lup(find(lup<hidx(h),1,'last'));
           eidx = ldown(find(ldown>hidx(h),1,'first'));
           if ~isempty(sidx)>0 && ~isempty(eidx)>0
               w = eidx-sidx;
               if w >= 4 %delete transients that aren't wide enough
                  trans(sidx,c) = 1; 
                  ftrans(sidx:eidx,c) = 1;
               end
           end
       end
    end
elseif strcmp(tmethod,'deconv')
    trans = zeros(size(F));
    expgrid = linspace(0,0.1*40,40);
    for c = 1:numcells
        sm = adsmo(F(:,c),1:numframes,1,50);
        sm = adsmo(sm,1:numframes,1,25); %smooth flourescence traces
        [~, locs] = findpeaks(-sm,'Threshold',0.5); %remove negative spikes
        for l=1:length(locs), sm(locs(l))=mean([sm(locs(l)-1) sm(locs(l)+1)]);end
        [dconv, ~] = deconv(sm,exp(-expgrid)); %exponential deconvolution
        s = abs(min(dconv));
        trans(dconv>s,c) = 1; %spike detection
        ftrans = trans;
    end
elseif strcmp(tmethod,'none')
    trans = F;
else
   disp('tmethod must be nthresh, zthresh, deconv, or none') 
end

%population activity
poptrans = sum(trans,2);

%compute rate maps using specified kernel method
if strcmp(kmethod,'gaussian')
   %set map evaluation grid
   grid = linspace(min(pos),max(pos),ngrid);
   %convert FWHM to gaussian standard deviation
   sd = FWHM/2.355;
   %get position for each imaging frame
   cpos = zeros(size(it));
   for t = 1:length(it)
       [~,midx] = min((pt-it(t)).^2);
       cpos(t) = pos(midx);
   end
   %get rate map for each cell 
   delta = repmat(cpos,1,ngrid)-repmat(grid,numframes,1);
   gk = exp(-0.5*delta.*delta/sd^2); %gaussian kernel
   dt = diff(it)';
   dt = [dt(1) dt];
   occupancy = dt*gk; 
   maps = (trans'*gk./repmat(occupancy,numcells,1))';
   pmap = (poptrans'*gk./occupancy)';
    
elseif strcmp(kmethod,'vonMises')
    %set map evaluation grid
    grid = linspace(-pi,pi,ngrid);
    %rescale position and FWHM to phase
    pos = (pos-(max(pos)-min(pos))/2);
    FWHM = FWHM/max(abs(pos))*pi; 
    %convert FWHM to von Mises concentration parameter
    kappa = log(2)/(1-cos(FWHM/2)); 
    %get position for each imaging frame
    pos = pos/max(abs(pos))*pi;
    cpos = zeros(size(it));
   for t = 1:length(it)
       [~,midx] = min((pt-it(t)).^2);
       cpos(t) = pos(midx);
   end   
   %get rate map for each cell
   delta = angle(exp(1i*repmat(cpos,1,ngrid)).*conj(exp(1i*repmat(grid,numframes,1))));
   vmk = exp(kappa*cos(delta)); %von Mises kernel
   dt = diff(it)';
   dt = [dt(1) dt];
   occupancy = dt*vmk;
   px = occupancy/sum(occupancy); %occupancies converted to probabilities 
   maps = (trans'*vmk./repmat(occupancy,numcells,1))';
   pmap = (poptrans'*vmk./occupancy)';
   %get mean vector length for each cell
   posrad = exp(1i*cpos);
   [~,midx] = min(abs(repmat(posrad,1,ngrid)-repmat(exp(1i*grid),numframes,1)),[],2);
   weights = 1./px(midx); %inverse occupancies
   for c = 1:numcells
      numt = sum(trans(:,c));
      if numt>3 %don't compute if less than 4 transients              
          mvl(c) = abs(weights(trans(:,c)==1)*posrad(trans(:,c)==1)/sum(weights(trans(:,c)==1))); %mean vector length
          %do permutation testing (num permutations = numframes)
          fmvl  = zeros(numframes,1);
          ftrans = toeplitz([trans(1,c) fliplr(trans(2:end,c)')], trans(:,c)')'; %all temporal shifts of transients           
          for f = 1:numframes     
             fmvl(f) = abs(weights(ftrans(:,f)==1)*posrad(ftrans(:,f)==1)/sum(weights(ftrans(:,f)==1)));
          end
          %debias + p-value
          dbmvl(c) = mvl(c) - median(fmvl); 
          mvlp(c) = sum(fmvl>=mvl(c))/numframes;
      end
   end
else    
    disp('kmethod must be gaussian or vonMises')    
end

%get spatial information for each map
dgrid = grid(2) - grid(1);
trate = px*maps; %mean transient rate
bps = dgrid*sum(maps.*log2(maps./repmat(trate,ngrid,1)).*repmat(px',1,numcells)); %bits/sec
bpt = bps./trate; %bits/transient

