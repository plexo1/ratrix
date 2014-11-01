function [osicv osi tuningtheta amp tfpref minp R resp] = gratingAnalysis(fname, startTime, dF, dt, blank);

isi = 0; sf = 0;
fname
load(fname)

baseRange = (2:dt:3.5)/dt;
evokeRange = (0:dt:4)/dt;

nstim = length(xpos);

for s = 1:nstim;
 
   base(:,s) = mean(dF(:,startTime + (s-1)*(duration+isi)/dt +baseRange),2);
    evoked(:,s) = mean(dF(:,startTime + isi/dt +(s-1)*(duration+isi)/dt +evokeRange),2);
end

resp = evoked-base;

angles = unique(theta);
sf
sfs = unique(sf);

for th = 1:length(angles);
    for sp = 1:length(sfs);
        
        orientation(:,th,sp) = median(resp(:,theta ==angles(th) & sf==sfs(sp)),2);
        %     figure
        %     imagesc(squeeze(orientation(:,:,th)),[-0.5 0.5]);
        ori_std(:,th,sp) = std(resp(:,theta ==angles(th) & sf==sfs(sp)),[],2);
    end
end




npts = size(dF,1);

if npts<=225
    figure
nfigs = ceil(sqrt((npts)));
end
for i= 1:npts
    if i/1000 == round(i/1000);
        i
    end
    
    tftuning=squeeze(mean(orientation(i,:,:),2));
    tfpref(i) =(tftuning(2)-tftuning(1))/(tftuning(2) + tftuning(1));
    if tfpref(i)>0
        tf_use=2;
    else
        tf_use=1;
    end
    if ~blank
tuning = squeeze(orientation(i,:,tf_use));
tuning_std = squeeze(ori_std(i,:,tf_use));
spont(i)=0; spont_std(i)=0;
    else
      tuning = squeeze(orientation(i,1:end-1,tf_use)) ; tuning_std = squeeze(ori_std(i,1:end-1,tf_use));
      spont(i) = orientation(i,end,tf_use); spont_std(i)=ori_std(i,end,tf_use);
    end
    ntrials = length(find(theta==angles(1) & sf==sfs(1)));
    
 
   R(i) = max(tuning);
 
    [osicv(i) tuningtheta(i)] = calcOSI(tuning',0);
   if npts<100*100
       [thetafit(i) osi(i) A1(i) A2(i) w(i) B(i)] = fit_tuningcurve(tuning,angles(1:length(tuning)));
     [osi(i) width(i) amp(i)] = calculate_tuning(A1(i),A2(i),B(i),w(i));
   else
       osi=[];
       width=[];
       amp=[];
   end

    
    if npts<100*100
    for ori=1:length(tuning);
        t(ori)=(tuning(ori)-spont(i))/(tuning_std(ori) /sqrt(ntrials));
        p(ori) = tcdf(t(ori),ntrials-1);
        p(ori) = 2*min(p(ori),1-p(ori));
    end
    minp(i) = min(p);
    else
        minp(i)=NaN;
    end
    
      if npts<=225
       subplot(nfigs,nfigs,i)
   errorbar(1:length(tuning),tuning,tuning_std/sqrt(ntrials)); 
   hold on; plot([1 8],[spont(i) spont(i)],'g');
    ylim([-0.4 1]); xlim([0 9])
 
    %title(sprintf('%0.2f %0.2f',minp(i)*length(angles),osi(i)));
   end
    
end

resp = evoked-base;


