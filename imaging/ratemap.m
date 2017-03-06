function [maps, grid, mvl, bps, bpt] = ratemap(F,pos,it,pt,ngrid,tmethod,kmethod,FWHM)

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
%grid - vector of length ngrid specifying position of rate map
%bps - vector of length numcells specifying spatial information for each map in bits per second
%mvl - mean vector length of transient complex sum (only for vonMises)
%bpt - vector of length numcells specifying spatial information for each map in bits per transient
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Example - [maps,grid,bps,bpt] = ratemap(dF,lap_position,ct,ard_timestamp,100,'deconv','vonMises',30);
%ct and ard_timestamp are from 'plot_dF_on_pos.m'
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[numframes, numcells] = size(F);
w = [];
mvl = nan(numcells,1);

%detect transients
trans = zeros(size(F)); %transients
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
    end
elseif strcmp(tmethod,'none')
    trans = F;
else
   disp('tmethod must be nthresh, zthresh, deconv, or none') 
end

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
   maps = (trans'*vmk./repmat(occupancy,numcells,1))';
   %get mean vector length for each cell
   for c = 1:numcells
      if sum(trans(:,c))>3 %don't compute if less than 4 transients
          mvl(c) = abs(sum(cos(cpos(trans(:,c)==1))+1i*sin(cpos(trans(:,c)==1))))/sum(trans(:,c));
      end
   end
else    
    disp('kmethod must be gaussian or vonMises')    
end

%get spatial information for each map
dgrid = grid(2) - grid(1);
px = occupancy/sum(occupancy); %occupancies converted to probabilities 
trate = px*maps; %mean transient rate
bps = dgrid*sum(maps.*log2(maps./repmat(trate,ngrid,1)).*repmat(px',1,numcells)); %bits/sec
bpt = bps./trate; %bits/transient