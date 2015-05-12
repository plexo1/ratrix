
dfAll = dF;

figure
plot(dfAll')


clear dfAvg
for i = 1:cycLength
    dfAvg(:,i) = mean(dfAll(:,i:cycLength:end),2);
end

figure
plot(circshift(dfAvg',0));
figure
plot(mean(dfAvg,1))

figure
for i = 1:10:size(dfAvg,1)
    hold on
    plot(circshift(dfAvg(i,:)',0));
end


dfRaw=dfAll
%dfAll = celldf;
for i  =1:size(dfAll,1)
   dfAll(i,:) = dfAll(i,:)/std(dfAll(i,:));
end
dfAll(isnan(dfAll))=0;

[icasig A W]= fastica(dfAll,'NumofIC',3,'LastEig',3,'stabilization','on','approach','symm');
figure
plot(icasig(:,1:1200)')
col = 'bgr';
for i = 1:size(icasig,1)
    figure
plot(icasig(i,1:1200),col(i))
end

figure
plot(A(:,1),A(:,2),'o')

for r = 1:3
    figure
hold on
for i = 1:size(A,1)
    plot(pts(i,2),pts(i,1),'o','Color',cmapVar(A(i,r),min(A(:,r)),max(A(:,r))));
end
axis ij
end


figure
plot(W(1,:),W(2,:),'o')

score = icasig';
figure
plot(score(:,1),score(:,2)); hold on; plot(score(:,1),score(:,2),'.','Color',[0.75 0  0]); 
figure
plot(score(:,1),score(:,3)); hold on; plot(score(:,1),score(:,3),'.','Color',[0.75 0  0]); 
figure
plot(score(:,2),score(:,3)); hold on; plot(score(:,2),score(:,3),'.','Color',[0.75 0  0]);
figure
plot3(score(:,1),score(:,2),score(:,3))

[coeff score latent] = pca(dfAll');
%[coeff score latent] = pcacov(corrcoef(dfAll'));
figure
plot(latent(1:10))
col = 'bgr';
for i = 1:3
    figure
plot(score(:,i),col(i))
end
figure
imagesc(coeff,[-1 1])
figure
plot(score(1:1200,1:3))


figure
plot(score(:,1),score(:,2)); hold on; plot(score(:,1),score(:,2),'.','Color',[0.75 0  0]); 
figure
plot(score(:,1),score(:,3)); hold on; plot(score(:,1),score(:,3),'.','Color',[0.75 0  0]); 
figure
plot(score(:,2),score(:,3)); hold on; plot(score(:,2),score(:,3),'.','Color',[0.75 0  0]); 
figure
plot3(score(:,1),score(:,2),score(:,3))

figure
plot(coeff(:,1),coeff(:,2),'o')

m = mean(dfAll,2);
df = dfAll(m~=0,:);
figure
imagesc(corrcoef(df'),[-1 1])
dist = 1-corrcoef(df');
imagesc(dist)

[Y e] = mdscale(dist,2,'Start','random');
figure
imagesc(Y)
figure
plot(e)
figure
for i = 1:size(coeff,1)
    hold on
    plot(Y(i,1),Y(i,2),'o')
end
title('mds coeff')


figure
for i = 1:size(coeff,1)
    hold on
    plot(coeff(i,1),coeff(i,2),'o')
end
title('pca coeff')

figure
for i = 1:size(coeff,1)
    hold on
    plot(coeff(i,1),coeff(i,2),'o','Color',phaseColor(i,:))
end
title('pca coeff')

figure
for i = 1:size(coeff,1)
    hold on
    plot(coeff(i,1),coeff(i,3),'o')
end
title('pca coeff')



figure
for i = 1:size(coeff,1)
    hold on
    plot3(coeff(i,1),coeff(i,2),coeff(i,3),'o')
end
title('pca coeff 3')
