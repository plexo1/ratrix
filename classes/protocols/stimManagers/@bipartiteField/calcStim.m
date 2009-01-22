function [stimulus,updateSM,resolutionIndex,out,LUT,scaleFactor,type,targetPorts,distractorPorts,details,interTrialLuminance,text] =...
    calcStim(stimulus,trialManagerClass,resolutions,displaySize,LUTbits,responsePorts,totalPorts,trialRecords)
% see ratrixPath\documentation\stimManager.calcStim.txt for argument specification (applies to calcStims of all stimManagers)
LUTbits
displaySize
[LUT stimulus updateSM]=getLUT(stimulus,LUTbits);
[resolutionIndex height width hz]=chooseLargestResForHzsDepthRatio(resolutions,[100 60],32,getMaxWidth(stimulus),getMaxHeight(stimulus));

if isnan(resolutionIndex)
    resolutionIndex=1;
end

type = 'phased';
scaleFactor = getScaleFactor(stimulus);
interTrialLuminance = getInterTrialLuminance(stimulus);

switch trialManagerClass
    case 'freeDrinks'
%         type='static';
        if ~isempty(trialRecords)
            lastResponse=find(trialRecords(end).response);
            if length(lastResponse)>1
                lastResponse=lastResponse(1);
            end
        else
            lastResponse=[];
        end

        targetPorts=setdiff(responsePorts,lastResponse);
        distractorPorts=[];

    case 'nAFC'
%         type='trigger';

        details.pctCorrectionTrials=.5; % need to change this to be passed in from trial manager
        if ~isempty(trialRecords)
            lastRec=trialRecords(end);
        else
            lastRec=[];
        end
        [targetPorts distractorPorts details]=assignPorts(details,lastRec,responsePorts);
    case 'autopilot'
        details.pctCorrectionTrials=0;
        targetPorts=[1];
        distractorPorts=[];
    otherwise
        error('unknown trial manager class')
end

% ================================================================================
% start calculating frames now

height = min(height,getMaxHeight(stimulus));
width = min(width,getMaxWidth(stimulus));
frequencies = stimulus.frequencies;
duration = stimulus.duration;
repetitions = stimulus.repetitions;

% error if requested frequency exceeds monitor refresh rate
% if any(frequencies>hz)
%     error('requested frequency exceeds monitor refresh rate');
% end

% calculate total number of monitor frames to spend in each frequency
numFramesPerFreq = hz * duration; % in frames
numFramesToMake = numFramesPerFreq * length(frequencies) * repetitions;

framesL=[];
framesR=[];
partition=stimulus.receptiveFieldLocation;
% calculate the number of pixels horizontally on each side (reduced using gcd)
leftlength=floor(partition(1)*width);
rightstart=ceil(partition(1)*width);
rightlength=width-rightstart;
sz=gcd(leftlength,rightlength);
numLeftPixels=leftlength/sz;
numRightPixels=rightlength/sz;

% now for each requested frequency, map to the monitor frame rate
for i=1:length(frequencies)
    numSampsAtThisFreq=numFramesPerFreq; % for each frequency, calculate the frames
    samps = [1:numSampsAtThisFreq]*2*pi; % linearly spaced with one extra samp, then throw away last one (2pi)
    % now "stretch" out samps to map to the monitor refresh rate (hz)
    msamps=samps ./ frequencies(i);
    
    framesL = [framesL 0.5*sin(msamps)+0.5];
    framesR = [framesR 0.5*sin(msamps+pi)+0.5];
end

% now repmat to number of reps
framesL = repmat(framesL, [1 repetitions]);
framesR = repmat(framesR, [1 repetitions]);

if length(framesL) ~= length(framesR)
    error('wtf');
end
if length(framesL) ~= numFramesToMake
    numFramesToMake
    length(framesL)
    numFramesPerFreq
    frequencies
    error('uh oh');
end

% stim.frames(1,:) = framesL(:);
% stim.frames(2,:) = framesR(:);

% 11/7/08 - dynamic mode stim is a struct of parameters
% stim = [];
% stim.height = height;
% stim.width = width;
% stim.floatprecision = 1;
% stim.frames(1,:) = framesL(:);
% stim.frames(2,:) = framesR(:);
% stim.numLeftPixels = numLeftPixels;
% stim.numRightPixels = numRightPixels;

stim=zeros(1,numLeftPixels+numRightPixels,length(framesL));
for i=1:length(framesL)
    stim(1,1:numLeftPixels,i) = framesL(i);
    stim(1,numLeftPixels+1:end,i) = framesR(i);
end

% now return the stimSpec
out.stimSpecs{1} = stimSpec(stim,{[] 2},'cache',[],1,numFramesToMake,[],0); % cache mode
out.scaleFactors{1} = scaleFactor;

% final phase
out.stimSpecs{2} = stimSpec(interTrialLuminance,{[] 1},'loop',[],1,1,[],1);
out.scaleFactors{2} = 0;

% return out.stimSpecs, out.scaleFactors for each phase (only one phase for now?)
details.big = stim; % store in 'big' so it gets written to file
details.stimManagerClass = class(stimulus);
details.trialManagerClass = trialManagerClass;

% ================================================================================
if strcmp(trialManagerClass,'nAFC') && details.correctionTrial
    text='correction trial!';
else
    text=sprintf('duration: %g',stimulus.duration);
end

end % end function