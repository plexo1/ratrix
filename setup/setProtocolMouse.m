function r = setProtocolMouse(r,subjIDs)

if ~isa(r,'ratrix')
    error('need a ratrix')
end

if ~all(ismember(subjIDs,getSubjectIDs(r)))
    error('not all those subject IDs are in that ratrix')
end

sm=makeStandardSoundManager();

rewardSizeULorMS          =50;
requestRewardSizeULorMS   =10;
requestMode               ='first';
msPenalty                 =1000;
fractionOpenTimeSoundIsOn =1;
fractionPenaltySoundIsOn  =1;
scalar                    =1;
msAirpuff                 =msPenalty;

constantRewards=constantReinforcement(rewardSizeULorMS,requestRewardSizeULorMS,requestMode,msPenalty,fractionOpenTimeSoundIsOn,fractionPenaltySoundIsOn,scalar,msAirpuff);

allowRepeats=false;
freeDrinkLikelihood=0.008;
fd = freeDrinks(sm,freeDrinkLikelihood,allowRepeats,constantRewards);

freeDrinkLikelihood=0;
fd2 = freeDrinks(sm,freeDrinkLikelihood,allowRepeats,constantRewards);

percentCorrectionTrials=.5;

maxWidth               = 1920;
maxHeight              = 1080;

[w,h]=rat(maxWidth/maxHeight);

eyeController=[];

dropFrames=false;
nafcTM=nAFC(sm,percentCorrectionTrials,constantRewards,eyeController,{'off'},dropFrames,'ptb','center'); %this percentCorrectionTrials should currently do nothing (need to fix)

numDots=75;
coherence=.95;
speed=.75;
contrast=1;
dotSize=5;
duration=1;
textureSize=10*[w,h];
zoom=[maxWidth maxHeight]./textureSize;
dots=coherentDots(textureSize(1),textureSize(2),numDots,coherence,speed,contrast,dotSize,duration,zoom,maxWidth,maxHeight,percentCorrectionTrials);

svnRev={'svn://132.239.158.177/projects/ratrix/trunk'};
svnCheckMode='session';

ts1 = trainingStep(fd,     dots, repeatIndefinitely(), noTimeOff(), svnRev,svnCheckMode);  %stochastic free drinks
ts2 = trainingStep(fd2,    dots, repeatIndefinitely(), noTimeOff(), svnRev,svnCheckMode);  %free drinks
ts3 = trainingStep(nafcTM, dots, repeatIndefinitely(), noTimeOff(), svnRev,svnCheckMode);  %coherent dots

p=protocol('mouse dots',{ts1, ts2, ts3});
stepNum=uint8(3);

for i=1:length(subjIDs),
    subj=getSubjectFromID(r,subjIDs{i});
    [subj r]=setProtocolAndStep(subj,p,true,false,true,stepNum,r,'call to setProtocolMouse','edf');
end