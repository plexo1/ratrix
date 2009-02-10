function [quit response didManualInTrial manual actualReinforcementDurationMSorUL proposedReinforcementDurationMSorUL ...
    phaseRecords eyeData gaze frameDropCorner station] ...
    = runRealTimeLoop(tm, window, ifi, stimSpecs, phaseData, stimManager, ...
    targetOptions, distractorOptions, requestOptions, interTrialLuminance, interTrialPrecision, ...
    station, manual,allowQPM,timingCheckPct,noPulses,textLabel,rn,subID,stimID,protocolStr,ptbVersion,ratrixVersion,trialLabel,msAirpuff, ...
    originalPriority, verbose, eyeTracker, frameDropCorner,trialRecords)


% need actual versus proposed reward duration (save in phaseRecords per phase)
actualReinforcementDurationMSorUL = 0;
proposedReinforcementDurationMSorUL = 0;
didManualInTrial=false;
eyeData=[];
gaze=[];

% We will break this main function into smaller functions also in the trialManager class
% =====================================================================================================================
% =====================================================================================================================
% START pre-loop initialization

% Variables
filtMode = 0;               %How to compute the pixel color values when the texture is drawn scaled
%                           %0 = Nearest neighbour filtering, 1 = Bilinear filtering (default, and BAD)

framesPerUpdate = 1;        %set number of monitor refreshes for each one of your refreshes

labelFrames = 1;            %print a frame ID on each frame (makes frame calculation slow!)
dontclear= 0;
expertCache=[];
ports=logical(0*readPorts(station));
lastPorts=ports;
if ismac
    %also not good enough on beige computer w/8600
    %http://psychtoolbox.org/wikka.php?wakka=FaqPerformanceTuning1
    %Screen('DrawText'): This is fast and low-quality on MS-Windows and beautiful but slow on OS/X.
    
    %Screen('Preference', 'TextAntiAliasing', 0); %not good enough
    %DrawFormattedText() won't be any faster cuz it loops over calls to Screen('DrawText'), tho it would clean this code up a bit.
    labelFrames=0;
end

msRewardSound=0;
msPenaltySound=0;
quit=false;
responseOptions = union(targetOptions, distractorOptions);

%need to move this stuff into stimManager or trialManager
toggleStim=1;

%originalPriority=Priority; %done in stimOGL now

timestamps.loopStart=0;
timestamps.phaseUpdated=0;
timestamps.frameDrawn=0;
timestamps.frameDropCornerDrawn=0;
timestamps.textDrawn=0;
timestamps.drawingFinished=0;
timestamps.when=0;
timestamps.prePulses=0;
timestamps.postFlipPulse=0;
timestamps.missesRecorded=0;
timestamps.eyeTrackerDone=0;
timestamps.kbCheckDone=0;
timestamps.keyboardDone=0;
timestamps.enteringPhaseLogic=0;
timestamps.phaseLogicDone=0;
timestamps.rewardDone=0;
timestamps.serverCommDone=0;
timestamps.phaseRecordsDone=0;
timestamps.loopEnd=0;
timestamps.prevPostFlipPulse=0;
timestamps.vbl=0;
timestamps.ft=0;
timestamps.missed=0;
timestamps.lastFrameTime=0;

timestamps.logicGotSounds=0;
timestamps.logicSoundsDone=0;
timestamps.logicFramesDone=0;
timestamps.logicPortsDone=0;
timestamps.logicRequestingDone=0;

timestamps.kbOverhead=0;
timestamps.kbInit=0;
timestamps.kbKDown=0;

% preallocate phaseRecords

responseDetails.numMisses=0;
responseDetails.numApparentMisses=0;

responseDetails.numUnsavedMisses=0;
responseDetails.numUnsavedApparentMisses=0;

responseDetails.misses=[];
responseDetails.apparentMisses=[];

responseDetails.afterMissTimes=[];
responseDetails.afterApparentMissTimes=[];

responseDetails.missIFIs=[];
responseDetails.apparentMissIFIs=[];

responseDetails.missTimestamps=timestamps;
responseDetails.apparentMissTimestamps=timestamps;

responseDetails.numDetailedDrops=1000;

responseDetails.nominalIFI=ifi;
responseDetails.toggleStim=toggleStim;
responseDetails.tries={};
responseDetails.times={};
% responseDetails.requestRewardPorts=[];
responseDetails.durs={};
responseDetails.requestRewardStartTime=[];
responseDetails.requestRewardDurationActual=[];


[phaseRecords(1:length(stimSpecs)).responseDetails]= deal(responseDetails);
[phaseRecords(1:length(stimSpecs)).response]=deal('none');



% Initialize this phaseRecord
[phaseRecords(1:length(stimSpecs)).proposedReinforcementSizeULorMS] = deal([]);
[phaseRecords(1:length(stimSpecs)).proposedReinforcementType] = deal([]);
[phaseRecords(1:length(stimSpecs)).proposedSounds] = deal([]);

% added 8/18/08 - strategy (loop, static, trigger, cache, dynamic, expert, timeIndexed, or frameIndexed)
[phaseRecords(1:length(stimSpecs)).loop] = deal([]);
[phaseRecords(1:length(stimSpecs)).trigger] = deal([]);
[phaseRecords(1:length(stimSpecs)).strategy] = deal([]);
[phaseRecords(1:length(stimSpecs)).stochasticProbability] = deal([]);
[phaseRecords(1:length(stimSpecs)).timeoutLengthInFrames] = deal([]);

% pump stuff
[phaseRecords(1:length(stimSpecs)).valveErrorDetails]=deal([]);
[phaseRecords(1:length(stimSpecs)).latencyToOpenValves]= deal([]);
[phaseRecords(1:length(stimSpecs)).latencyToCloseValveRecd]= deal([]);
[phaseRecords(1:length(stimSpecs)).latencyToCloseValves]= deal([]);
[phaseRecords(1:length(stimSpecs)).latencyToRewardCompleted]= deal([]);
[phaseRecords(1:length(stimSpecs)).latencyToRewardCompletelyDone]= deal([]);
[phaseRecords(1:length(stimSpecs)).primingValveErrorDetails]= deal([]);
[phaseRecords(1:length(stimSpecs)).latencyToOpenPrimingValves]= deal([]);
[phaseRecords(1:length(stimSpecs)).latencyToClosePrimingValveRecd]= deal([]);
[phaseRecords(1:length(stimSpecs)).latencyToClosePrimingValves]= deal([]);
[phaseRecords(1:length(stimSpecs)).actualPrimingDuration]= deal([]);

% manual poking stuff
[phaseRecords(1:length(stimSpecs)).containedManualPokes]= deal([]);
[phaseRecords(1:length(stimSpecs)).leftWithManualPokingOn]= deal([]);

% =====================================================================================================================
% check for constands and rewardMethod
if ~isempty(rn)
    constants = getConstants(rn);
end

if strcmp(getRewardMethod(station),'serverPump')
    if isempty(rn) || ~isa(rn,'rnet')
        error('need an rnet for station with rewardMethod of serverPump')
    end
end

% =====================================================================================================================
% more variables
done=0;
rewardCurrentlyOn=false;
msRewardOwed=0;
lastRewardTime=[];
msAirpuffOwed=0;
airpuffOn=false;
lastAirpuffTime=[];
soundNames=getSoundNames(getSoundManager(tm));


% =====================================================================================================================
% Get ready with various stuff

% For the Windows version of Priority (and Rush), the priority levels set
% are  "process priority levels". There are 3 priority levels available,
% levels 0, 1, and 2. Level 0 is "normal priority level", level 1 is "high
% priority level", and level 2 is "real time priority level". Combined
% with

%Priority(9);
[keyIsDown,secs,keyCode]=KbCheck; %load mex files into ram + preallocate return vars
GetSecs;
Screen('Screens');

if window>0
    % set font size correctly
    standardFontSize=11; %big was 25
    oldFontSize = Screen('TextSize',window,standardFontSize);
    Screen('Preference', 'TextRenderer', 0);  % consider moving to PTB setup
    [normBoundsRect, offsetBoundsRect]= Screen('TextBounds', window, 'TEST');
end

%KbName('UnifyKeyNames'); %does not appear to choose keynamesosx on windows - KbName('KeyNamesOSX') comes back wrong
KbConstants.allKeys=KbName('KeyNames');
KbConstants.allKeys=lower(cellfun(@char,KbConstants.allKeys,'UniformOutput',false));
KbConstants.controlKeys=find(cellfun(@(x) ~isempty(x),strfind(KbConstants.allKeys,'control')));
KbConstants.shiftKeys=find(cellfun(@(x) ~isempty(x),strfind(KbConstants.allKeys,'shift')));
KbConstants.kKey=KbName('k');
KbConstants.pKey=KbName('p');
KbConstants.qKey=KbName('q');
KbConstants.mKey=KbName('m');
KbConstants.aKey=KbName('a');
KbConstants.rKey=KbName('r');
KbConstants.tKey=KbName('t');
KbConstants.fKey=KbName('f');
KbConstants.atKeys=find(cellfun(@(x) ~isempty(x),strfind(KbConstants.allKeys,'@')));
KbConstants.asciiOne=double('1');
KbConstants.portKeys={};
for i=1:length(ports)
    KbConstants.portKeys{i}=find(strncmp(char(KbConstants.asciiOne+i-1),KbConstants.allKeys,1));
end
KbConstants.numKeys={};
for i=1:10
    KbConstants.numKeys{i}=find(strncmp(char(KbConstants.asciiOne+i-1),KbConstants.allKeys,1));
end

priorityLevel=MaxPriority('GetSecs','KbCheck');

Priority(priorityLevel);
if verbose
    disp(sprintf('running at priority %d',priorityLevel));
end

% =====================================================================================================================
% 10/19/08 - initialize eyeTracker
if ~isempty(eyeTracker)
    perTrialSyncing=false; %could pass this in if we ever decide to use it; now we don't
    if perTrialSyncing && isa(eyeTracker,'eyeLinkTracker')
        status=Eyelink('message','SYNCTIME');
        if status~=0
            error('message error, status: ',status)
        end
    end
    
    framesPerAllocationChunk=getFramesPerAllocationChunk(eyeTracker);
    
    if isa(eyeTracker,'eyeLinkTracker')
        eyeData=nan(framesPerAllocationChunk,40);
        gaze=nan(framesPerAllocationChunk,2);
    else
        error('no other methods')
    end
end
% =====================================================================================================================

% END pre-loop initialization

% =====================================================================================================================
% =====================================================================================================================
% Pre-phase initialization (cont.)

specInd = 1; % which phase we are on (index for stimSpecs and phaseData)
updatePhase = 1; % are we starting a new phase?
audioStim = []; % this variable isn't used to play sounds - will be handled differently
lastI = 0; % variables to be generated by Flip command

framesSinceKbInput = 0;
lastSoundsPlayed={};
totalFrameNum=1;
doFramePulse=1;

audioStimPlaying = false;
startTime=0;
yNewTextPos=0;

doValves=0*ports;
newValveState=doValves;
doPuff=false;
mThisLoop=0;
pThisLoop=0;


shiftDown=false;
ctrlDown=false;
atDown=false;
kDown=false;
portsDown=false(1,length(ports));
pNum=0;

soundName='';
somethingElseOn=false;
keepGoingOn=false;

% phaseRecords = [];


% =====================================================================================================================
% Draw and flip last frame (finalScreenLuminance)
% function [vbl sos ft lastFrameTime lastI] = drawFirstFrame(tm, window, standardFontSize, texture, lengthOfStim, destRect, filtMode, dontclear)
% [vbl sos ft lastFrameTime lastI] = ...
%     drawFirstFrame(tm, window, standardFontSize, textures(size(stim,3)+1), size(stim,3), destRect, filtMode, dontclear);

% =====================================================================================================================
% ENTERING LOOP

%logwrite('about to enter stimOGL loop');


%any stimulus onset synched actions

startTime=GetSecs();
respStart = 0; % initialize respStart to zero - it won't get set until we get a response through trial logic
isRequesting=0;
        
audioStimPlaying = false;
response='none'; %initialize

analogOutput=[];

if window>0
    % draw interTrialLuminance first
%     interTrialLuminance
%     phaseData{end}.destRect % this is more likely to be the interTrial screen
%     class(interTrialLuminance)
%     interTrialPrecision
    interTrialTex=Screen('MakeTexture', window, interTrialLuminance,0,0,interTrialPrecision); %ned floatprecision=0 for remotedesktop
    % we dont know what floatprecision to use for the interTrial because all floatprecisions are specified per-phase, not per trial
    % should we have an interTrialFloatprecision, or just assume 0?
    Screen('DrawTexture', window, interTrialTex,phaseData{end}.destRect, [], filtMode);
    [timestamps.vbl sos startTime]=Screen('Flip',window);  %make sure everything after this point is preallocated
end

timestamps.lastFrameTime=GetSecs;
timestamps.missesRecorded       = timestamps.lastFrameTime;
timestamps.eyeTrackerDone       = timestamps.lastFrameTime;
timestamps.kbCheckDone          = timestamps.lastFrameTime;
timestamps.keyboardDone         = timestamps.lastFrameTime;
timestamps.enteringPhaseLogic   = timestamps.lastFrameTime;
timestamps.phaseLogicDone       = timestamps.lastFrameTime;
timestamps.rewardDone           = timestamps.lastFrameTime;
timestamps.serverCommDone       = timestamps.lastFrameTime;
timestamps.phaseRecordsDone     = timestamps.lastFrameTime;
timestamps.loopEnd              = timestamps.lastFrameTime;
timestamps.prevPostFlipPulse    = timestamps.lastFrameTime;

if ~isempty(tm.datanet)
    % 10/17/08 - start of a datanet trial - timestamp
    datanet_constants = getConstants(tm.datanet);
    commands = [];
    commands.cmd = datanet_constants.stimToDataCommands.S_TIMESTAMP_CMD;
    [trialData, gotAck] = sendCommandAndWaitForAck(tm.datanet, getCon(tm.datanet), commands);
end

%show stim -- be careful in this realtime loop!
while ~done && ~quit;
    %logwrite('top of stimOGL loop');
    timestamps.loopStart=GetSecs;
    % moved from inside if updatePhase to every time this loop runs (b/c we moved from function to inside runRealTimeLoop)
    xOrigTextPos = 10;
    xTextPos=xOrigTextPos;
    yTextPos = 20;
    yNewTextPos=yTextPos;
    
    % =====================================================================================================================
    % if we are entering a new phase, re-initialize variables
    if updatePhase == 1
        
        i=0;
        frameIndex=0;
        %         attempt=0;
        
        frameNum=1;
        phaseStartTime=GetSecs;
        firstVBLofPhase=timestamps.vbl;
        
        
        %         logIt=0;
        %         stopListening=0;
        %         lookForChange=0;
        %         player=[];
        %         currSound='';
        
        
        %         lastPorts=0*readPorts(station);
        pressingM=0;
        pressingP=0;
        didAPause=0;
        paused=0;
        didPulse=0;
        didValves=0;
        didManual=false; %initialize
        arrowKeyDown=false; %1/9/09 - for phil's stuff
        
        %         puffStarted=0;
        %         puffDone=false;
        
        %used for timed frames stimuli
        if isempty(requestOptions)
            requestFrame=1;
        else
            requestFrame=0;
        end
        
        currentValveState=getValves(station); % cant do verifyClosed here because it might be open from a reward from previous phase
        %         valveErrorDetails=[];
        requestRewardStarted=false;
        requestRewardStartLogged=false;
        requestRewardDone=false;
%         requestRewardPorts=0*readPorts(station);
        requestRewardDurLogged=false;
        requestRewardOpenCmdDone=false;
        serverValveChange=false;
        serverValveStates=false;
        %         potentialStochasticResponse=false;
        didStochasticResponse=false;
        didHumanResponse=false;
        
        %         stimToggledOn=0;
        
        % load phaseData
        phase = phaseData{specInd};
        floatprecision = phase.floatprecision;
        frameIndexed = phase.frameIndexed;
        loop = phase.loop;
        trigger = phase.trigger;
        timeIndexed = phase.timeIndexed;
        indexedFrames = phase.indexedFrames;
        timedFrames = phase.timedFrames;
        strategy = phase.strategy;
        % 11/9/08 - if dynamic strategy, then create a big field
        %         if strcmp(strategy, 'dynamic')
        %             numDynamicFrames = length(stim.seedValues);
        % %             phaseRecords(specInd).big=zeros(stim.height,stim.width,numDynamicFrames);
        %         end
        destRect = phase.destRect;
        textures = phase.textures;
        numDots = phase.numDots;
        dotX = phase.dotX;
        dotY = phase.dotY;
        dotLocs = phase.dotLocs;
        dotSize = phase.dotSize;
        dotCtr = phase.dotCtr;
        currentCLUT = phase.CLUT;
        
        % load stimSpec
        spec = stimSpecs{specInd};
        stim = getStim(spec);
        transitionCriterion = getCriterion(spec);
        framesUntilTransition = getFramesUntilTransition(spec);
        % TEST - call calcReinforcement see if this is fast enough
        phaseType = getPhaseType(spec);
        if isempty(phaseType)
            % not correct or error, do nothing
        elseif strcmp(phaseType,'correct')
            % correct phase - assign reward values from calcReinforcement 
            [rm rewardSizeULorMS msPenalty msPuff msRewardSound msPenaltySound updateRM] =...
                calcReinforcement(getReinforcementManager(tm),trialRecords, []);
            msRewardOwed=msRewardOwed+rewardSizeULorMS; % give reward duration
            % set timeout for reward phase

            
            if window>0
                if isempty(framesUntilTransition)
                    framesUntilTransition = ceil((rewardSizeULorMS/1000)/ifi);
                end
            elseif strcmp(tm.displayMethod,'LED')
                if isempty(framesUntilTransition)
                    framesUntilTransition=ceil(getHz(spec)*rewardSizeULorMS/1000);
                    if isscalar(squeeze(stim))
                        stim=stim*ones(framesUntilTransition,1); %need to lengthen the stim cuz rewards are currently timed based on frames
                    else
                        size(stim)
                        error('stim wasn''t scalar')
                    end
                else
                    framesUntilTransition
                    error('LED needs framesUntilTransition empty for reward')
                end
            else
                error('huh?')
            end


            proposedReinforcementDurationMSorUL = proposedReinforcementDurationMSorUL + rewardSizeULorMS;
        elseif strcmp(phaseType,'error')
            % error phase - assign error values from calcReinforcement
            [rm rewardSizeULorMS msPenalty msPuff msRewardSound msPenaltySound updateRM] =...
                calcReinforcement(getReinforcementManager(tm),trialRecords, []);

            % also need to call errorStim(stimManager,numErrorFrames) here...wtf how do we do this..
            % and assign to textures now
            if window>0
                numErrorFrames=ceil((msPenalty/1000)/ifi);
            elseif strcmp(tm.displayMethod,'LED')
                numErrorFrames=ceil(getHz(spec)*msPenalty/1000);                
            else
                error('huh?')
            end
            
            [stim errorScale] = errorStim(stimManager,numErrorFrames);

            if window>0
                [floatprecision stim garbage] = determineColorPrecision(tm, stim, false, strategy, interTrialLuminance);
                [textures, garbage, garbage, garbage, garbage, ...
                    garbage, garbage] ...
                    = cacheTextures(tm,strategy,stim,window,floatprecision,false);
                destRect=Screen('Rect',window);
            elseif strcmp(tm.displayMethod,'LED')
                floatprecision=[];
            else
                error('huh?')
            end
            
            % set timeout for error phase
            if isempty(framesUntilTransition)
                framesUntilTransition = numErrorFrames;
            elseif strcmp(tm.displayMethod,'LED')
                error('LED needs framesUntilTransition empty for error')
            end
        end

        % get startFrame if not empty
        if ~isempty(getStartFrame(spec))
            i=getStartFrame(spec);
        end

        stepsInPhase = 0;
        isFinalPhase = getIsFinalPhase(spec); % we set the isFinalPhase flag to true if we are on the last phase
        stochasticDistribution = getStochasticDistribution(spec);
        

        
        % Initialize this phaseRecord
        %         phaseRecords(specInd).response='none';
        %         phaseRecords(specInd).responseDetails.numMisses=0;
        %         phaseRecords(specInd).responseDetails.misses=[];
        %         phaseRecords(specInd).responseDetails.afterMissTimes=[];
        %
        %         phaseRecords(specInd).responseDetails.numApparentMisses=0;
        %         phaseRecords(specInd).responseDetails.apparentMisses=[];
        %         phaseRecords(specInd).responseDetails.afterApparentMissTimes=[];
        %         phaseRecords(specInd).responseDetails.apparentMissIFIs=[];
        %         phaseRecords(specInd).responseDetails.numFramesUntilStopSavingMisses=numFramesUntilStopSavingMisses;
        %         phaseRecords(specInd).responseDetails.numUnsavedMisses=0;
        %         phaseRecords(specInd).responseDetails.nominalIFI=ifi;
        %
        phaseRecords(specInd).dynamicDetails={};
        phaseRecords(specInd).responseDetails.toggleStim=toggleStim;
        %
        % Initialize this phaseRecord
%         phaseRecords(specInd).proposedReinforcementSizeULorMS = rewardDuration;
%         phaseRecords(specInd).proposedReinforcementType = rewardType;
        
        % added 8/18/08 - strategy (loop, static, trigger, cache, dynamic, expert, timeIndexed, or frameIndexed)
        phaseRecords(specInd).loop = loop;
        phaseRecords(specInd).trigger = trigger;
        phaseRecords(specInd).strategy = strategy;
        phaseRecords(specInd).stochasticProbability = stochasticDistribution;
        phaseRecords(specInd).timeoutLengthInFrames = framesUntilTransition;
        phaseRecords(specInd).floatprecision = floatprecision;
        phaseRecords(specInd).stim=stim;
        phaseRecords(specInd).phaseType = phaseType;
        %
        %         % pump stuff
        %         phaseRecords(specInd).valveErrorDetails=[];
        %         phaseRecords(specInd).latencyToOpenValves=[];
        %         phaseRecords(specInd).latencyToCloseValveRecd=[];
        %         phaseRecords(specInd).latencyToCloseValves=[];
        %         phaseRecords(specInd).latencyToRewardCompleted=[];
        %         phaseRecords(specInd).latencyToRewardCompletelyDone=[];
        %         phaseRecords(specInd).primingValveErrorDetails=[];
        %         phaseRecords(specInd).latencyToOpenPrimingValves=[];
        %         phaseRecords(specInd).latencyToClosePrimingValveRecd=[];
        %         phaseRecords(specInd).latencyToClosePrimingValves=[];
        %         phaseRecords(specInd).actualPrimingDuration=[];
        %
        %         % manual poking stuff
        %         phaseRecords(specInd).containedManualPokes=[];
        %         phaseRecords(specInd).leftWithManualPokingOn=[];
        
        updatePhase = 0;
        
        if strcmp(tm.displayMethod,'LED')
            station=stopPTB(station); %should handle this better -- LED setting is trialManager specific, so other training steps will expect ptb to still exist
            %would prefer to never startPTB until a trialManager needs it,and then start it at the proper res the first time
            %trialManager.doTrial should startPTB if it wants one and there isn't one, and stop it if there is one and it doesn't want it
            %note that ifi is not coming in empty on the first trial and the leftover value from the screen is misleading, need to fix...
            
            fprintf('doing phase %d\n',specInd) %note that the way we use specInd prevents us from revisiting phases, we would overwrite records...  should be fixed...
            
            outputRange=[-5 0]; %hardcoded for our LED amp
            
            if ~isempty(analogOutput)
                stop(analogOutput);
                
                evts=showdaqevents(analogOutput);
                if ~isempty(evts)
                    evts
                end
                
                if specInd>1
                    phaseRecords(specInd-1).LEDstopped=GetSecs; %need to preallocate
                    phaseRecords(specInd-1).totalSampsOutput=get(analogOutput,'SamplesOutput'); %need to preallocate
                else
                    error('shouldn''t happen')
                end

                %need to remove leftover data from previous putdata calls (no other way to do it that i see)
                if get(analogOutput,'SamplesAvailable')>0
                    delete(analogOutput.Channel(1));

                    %this block stolen from openNidaqForAnalogOutput -- need to refactor
                    aoInfo=daqhwinfo(analogOutput);
                    hwChans=aoInfo.ChannelIDs;
                    chans=addchannel(analogOutput,hwChans(1));
                    if length(chans)~=1
                        error('didn''t get requested num chans even though hardware appears to support it')
                    end
                    if setverify(analogOutput,'SampleRate',getHz(spec))~=getHz(spec)
                        rates = propinfo(analogOutput,'SampleRate')
                        rates.ConstraintValue
                        getHz(spec)
                        error('couldn''t set requested sample rate')
                    end
                    verifyRange=setverify(analogOutput.Channel(1),'OutputRange',outputRange);
                    if verifyRange(1)<=outputRange(1)&& verifyRange(2)>=outputRange(2)
                        uVerifyRange=setverify(analogOutput.Channel(1),'UnitsRange',verifyRange);
                        if any(uVerifyRange~=verifyRange)
                            verifyRange
                            uVerifyRange
                            error('could not set UnitsRange to match OutputRange')
                        end
                    else
                        aoInfo.OutputRanges
                        outputRange
                        error('couldn''t get requested output range')
                    end
                    %end refactor block
                end

            else
                preAnalog=GetSecs;
                [analogOutput bits]=openNidaqForAnalogOutput(getHz(spec),outputRange); %should ultimately send bits back through stimOGL to doTrial so can be stored as trialRecords(trialInd).resolution.pixelSize
                fprintf('took %g secs to open analog out (mostly in call to daqhwinfo)\n',GetSecs-preAnalog)
            end
            
            if tm.dropFrames
                error('can''t have dropFrames set for LED')
            end
            
            if isscalar(interTrialLuminance) && interTrialLuminance>=0 && interTrialLuminance<=1
                scaledInterTrialLuminance=interTrialLuminance*diff(outputRange)+outputRange(1);
            else
                error('bad interTrialLuminance')
            end
            verify=setverify(analogOutput,'OutOfDataMode','DefaultValue');
            if ~strcmp(verify,'DefaultValue')
                error('couldn''t set OutOfDataMode to DefaultValue')
            end
            
            verify=setverify(analogOutput.Channel(1),'DefaultChannelValue',scaledInterTrialLuminance);
            if verify~=scaledInterTrialLuminance
                error('couldn''t set DefaultChannelValue')
            end
                    
            data=squeeze(stim);
            
            %could move this logic to updateFrameIndexUsingTextureCache, it is related to that info  
            if frameIndexed
                %might also be loop, will handle below with 'RepeatOutput'
                data=data(indexedFrames);
            elseif loop
                %pass
            elseif trigger
                error('trigger not yet supported by LED') %would be easy to add with putsample, but a single 1x1 discriminandum frame can only be luminance discrimination - not very interesting
            elseif timeIndexed 
                oldData=data;
                data=[];
                for fNum=1:length(timedFrames)
                    data(end+1:end+timedFrames(fNum))=oldData(fNum);
                end
                if timedFrames(end)==0
                    data(end+1)=timedFrames(end);
                    verify=setverify(analogOutput,'OutOfDataMode','Hold');
                    if ~strcmp(verify,'Hold')
                        error('couldn''t set OutOfDataMode to Hold')
                    end
                end
            end
            
            if isvector(data) && all(data>=0) && all(data<=1)
                data=data*diff(outputRange)+outputRange(1);
            else
                error('bad stim size for LED')
            end
            
            if get(analogOutput,'MaxSamplesQueued')>=length(data) %if BufferingMode set to Auto, should only be limited by system RAM, on rig computer >930 mins @ 1200 Hz 
                preAnalog=GetSecs;
                if length(data)>1
                    putdata(analogOutput,data); %crashes when length is 1! have to use putsample, then 'SamplesOutput' doesn't work... :(
                    outputsamplesOK=true;
                else
                    putsample(analogOutput,data);
                    outputsamplesOK=false;
                end
                fprintf('took %g secs to put analog data\n',GetSecs-preAnalog)
            else
                get(analogOutput,'MaxSamplesQueued')/length(data)
                error('need to manually buffer this much data for LED')
            end
            
            if loop
                if timeIndexed || trigger
                    error('can''t have loop when timeIndexed or trigger')
                end
                rpts=inf;
            else
                rpts=0; %sets *additional* repeats, 1 is assumed
            end
            verify=setverify(analogOutput,'RepeatOutput',rpts);
            if rpts~=verify
                rpts
                verify
                error('couldn''t set to repeats')
            end
            
            if outputsamplesOK
                start(analogOutput);
            end
            
            phaseRecords(specInd).LEDstarted=GetSecs; %need to preallocate
            
            if ~noPulses
                framePulse(station);
            end
        end
        
    end
    
    timestamps.phaseUpdated=GetSecs;
    
    doFramePulse=~noPulses;
                
    if window>0
        
        % =====================================================================================================================
        if ~paused
            
            scheduledFrameNum=ceil((GetSecs-firstVBLofPhase)/(framesPerUpdate*ifi)); %could include pessimism about the time it will take to get from here to the flip and how much advance notice flip needs

            % note this does not take pausing into account -- edf thinks we should get rid of pausing
            
            switch strategy
                
                % ====================================================================================================================
                case 'textureCache'
                    % function to determine the frame index using the textureCache strategy
                    [tm frameIndex i done doFramePulse didPulse] = updateFrameIndexUsingTextureCache(tm, ...
                        frameIndexed, loop, trigger, timeIndexed, frameIndex, indexedFrames, size(stim,3), isRequesting, ...
                        i, requestFrame, frameNum, timedFrames, responseOptions, done, doFramePulse, didPulse, scheduledFrameNum);
                    
                    % =====================================================================================================================
                    % function to draw the appropriate texture using the textureCache strategy
                    drawFrameUsingTextureCache(tm, window, i, frameNum, size(stim,3), lastI, dontclear, textures(i), destRect, ...
                        filtMode, labelFrames, xOrigTextPos, yNewTextPos);

                    
                    % =====================================================================================================================
                case 'expert'
                    % 10/31/08 - implementing expert mode
                    % call a method of the given stimManager that draws the expert frame
                    % i=i+1; % 11/7/08 - this needs to happen first because i starts at 0
                    [doFramePulse expertCache dynamicDetails textLabel i] = ...
                        drawExpertFrame(stimManager,stim,i,phaseStartTime,window,textLabel,...
                        floatprecision,destRect,filtMode,expertCache,ifi,scheduledFrameNum,tm.dropFrames);
                    if ~isempty(dynamicDetails)
                        phaseRecords(specInd).dynamicDetails{end+1}=dynamicDetails; % dynamicDetails better specify what frame it is b/c the record will not save empty details
                    end
                otherwise
                    error('unrecognized strategy')
            end
            
            timestamps.frameDrawn=GetSecs;
            
            %logwrite(sprintf('stim is started, i is calculated: %d',i));
            
            if frameDropCorner.on
                Screen('FillRect', window, frameDropCorner.seq(frameDropCorner.ind), frameDropCorner.rect);
                frameDropCorner.ind=frameDropCorner.ind+1;
                if frameDropCorner.ind>length(frameDropCorner.seq)
                    frameDropCorner.ind=1;
                end
            end
            
            timestamps.frameDropCornerDrawn=GetSecs;
            
            %text commands are supposed to be last for performance reasons
            
            % =====================================================================================================================
            % function for drawing text
            if manual
                didManual=1;
            end
            if window>=0
                xTextPos = drawText(tm, window, labelFrames, subID, xOrigTextPos, yTextPos, yNewTextPos, normBoundsRect, stimID, protocolStr, ...
                    textLabel, trialLabel, i, frameNum, manual, didAPause, ptbVersion, ratrixVersion,phaseRecords(specInd).responseDetails.numMisses, phaseRecords(specInd).responseDetails.numApparentMisses, specInd, getStimType(spec));
            end
            
            timestamps.textDrawn=GetSecs;
            
            % =====================================================================================================================
        else
            %do i need to copy previous screen?
            %Screen('CopyWindow', window, window);
            if window>=0
                Screen('DrawText',window,'paused (k+p to toggle)',xTextPos,yNewTextPos,100*ones(1,3));
            end
        end
        
        % =====================================================================================================================
        % function here to do flip and other Screen stuff
        
        [lastI timestamps] = ...
            flipFrameAndDoPulse(tm, window, dontclear, i, framesPerUpdate, ifi, paused, doFramePulse,station,timestamps);
        
        % =====================================================================================================================
        % function here to save information about missed frames
        [phaseRecords(specInd).responseDetails timestamps] = ...
            saveMissedFrameData(tm, phaseRecords(specInd).responseDetails, frameNum, timingCheckPct, ifi, timestamps);
        
        timestamps.missesRecorded=GetSecs;
    else
        
        if ~isempty(analogOutput) || window<=0 || strcmp(tm.displayMethod,'LED')
            phaseRecords(specInd).LEDintermediateTimestamp=GetSecs; %need to preallocate
            phaseRecords(specInd).intermediateSampsOutput=get(analogOutput,'SamplesOutput'); %need to preallocate
            
            if ~isempty(framesUntilTransition)
                %framesUntilTransition is calculated off of the screen's ifi which is not correct when using LED
                framesUntilTransition=stepsInPhase+2; %prevent handlePhasedTrialLogic from tripping to next phase
            end
            
            %note this logic is related to updateFrameIndexUsingTextureCache
            if ~loop && (get(analogOutput,'SamplesOutput')>=length(data) || ~outputsamplesOK)
                if isempty(responseOptions)
                    done=1;
                end
                if ~isempty(framesUntilTransition)
                    framesUntilTransition=stepsInPhase+1; %cause handlePhasedTrialLogic to trip to next phase
                end
            end
        end
        
    end

    % =====================================================================================================================
    % =====================================================================================================================
    % 10/19/08 - get eyeTracker sample
    % immediately after the frame pulse is ideal, not before the frame pulse (which is more important)
    if ~isempty(eyeTracker)
        if ~checkRecording(eyeTracker)
            sca
            error('lost tracker connection!')
        end
        
        if totalFrameNum>length(eyeData)
            %  allocateMore
            newEnd=length(eyeData)+ framesPerAllocationChunk;
            disp(sprintf('did allocation to eyeTrack data; up to %d samples enabled',newEnd))
            eyeData(end+1:newEnd,:)=nan;
            gaze(end+1:newEnd,:)=nan;
        end
        
        [gaze(totalFrameNum,:) eyeData(totalFrameNum,:)]=getSample(eyeTracker);
        
    end
    
    timestamps.eyeTrackerDone=GetSecs;
    
    % =====================================================================================================================
    %logwrite('entering trial logic');
    %all trial logic here
    if ~paused
        ports=readPorts(station);
    end
    doValves=0*ports;
    doPuff=false;
    
    % =====================================================================================================================
    % function to handle keyboard input
    %     mThisLoop=0;
    %     pThisLoop=0;
    [keyIsDown,secs,keyCode]=KbCheck; % do this check outside of function to save function call overhead
    
    timestamps.kbCheckDone=GetSecs;
    
    if keyIsDown
        [didAPause paused done phaseRecords(specInd).response doValves ports didValves didHumanResponse manual doPuff pressingM pressingP...
            timestamps.kbOverhead,timestamps.kbInit,timestamps.kbKDown] = ...
            handleKeyboard(tm, keyCode, didAPause, paused, done, phaseRecords(specInd).response, doValves, ports, didValves, didHumanResponse, ...
            manual, doPuff, pressingM, pressingP, allowQPM, originalPriority, priorityLevel, KbConstants);
    end
    
    timestamps.keyboardDone=GetSecs;
    
    % =====================================================================================================================
    % Handle stochastic port hits (has to be after keyboard so that wont happen if another port already triggered)
    % 8/18/08 - added stochastic port hits
    if ~paused
        if ~isempty(stochasticDistribution) && isempty(find(ports))
            for j=1:2:length(stochasticDistribution)
                if rand<stochasticDistribution{j} % if we meet this probability - go to the corresponding port
                    ports(stochasticDistribution{j+1}) = 1;
                    break;
                end
            end
            didStochasticResponse=true;
        end
    end
    
    % 1/21/09 - how should we handle tries? - do we count attempts that occur during a phase w/ no port transitions (ie timeout only)?
    %     if any(ports)
    %         phaseRecords(specInd).responseDetails.tries{end+1} = ports;
    %         phaseRecords(specInd).responseDetails.times{end+1} = GetSecs() - startTime;
    %     end
    
    if any(ports~=lastPorts)
        phaseRecords(specInd).responseDetails.tries{end+1} = ports;
        phaseRecords(specInd).responseDetails.times{end+1} = GetSecs() - startTime;
        %         disp(ports)
    end
    
    
    % =====================================================================================================================
    % large function here that handles trial logic (what state are we in - did we have a request, response, should we give reward, etc)
    % if phaseRecords(specInd).response got set by keyboard, duplicate response on trial level
    if ~strcmp('none', phaseRecords(specInd).response)
        response = phaseRecords(specInd).response;
    end
    
    timestamps.enteringPhaseLogic=GetSecs;
    
    [tm done newSpecInd specInd updatePhase transitionedByTimeFlag ...
        transitionedByPortFlag phaseRecords(specInd).response response isRequesting lastSoundsPlayed ...
        timestamps.logicGotSounds timestamps.logicSoundsDone timestamps.logicFramesDone timestamps.logicPortsDone timestamps.logicRequestingDone] = ...
        handlePhasedTrialLogic(tm, done, ...
        ports, lastPorts, station, specInd, transitionCriterion, framesUntilTransition, stepsInPhase, isFinalPhase, ...
        phaseRecords(specInd).response, response, ...
        stimManager, msRewardSound, msPenaltySound, targetOptions, distractorOptions, requestOptions, isRequesting, soundNames, lastSoundsPlayed);
    
    stepsInPhase = stepsInPhase + 1; %10/16/08 - moved from handlePhasedTrialLogic to prevent COW
    lastPorts=ports; % moved from above trial logic - we need lastPorts to correctly set isRequesting
    
    timestamps.phaseLogicDone=GetSecs;
    
    % =====================================================================================================================
    % reward stuff copied from old phased stimOGL
    % update reward owed and elapsed time
    if ~isempty(lastRewardTime) && rewardCurrentlyOn
        elapsedTime = GetSecs() - lastRewardTime;
        if strcmp(getRewardMethod(station),'localTimed')
            msRewardOwed = msRewardOwed - elapsedTime*1000.0;
            % error('elapsed time was %d and msRewardOwed is now %d', elapsedTime, msRewardOwed);
            actualReinforcementDurationMSorUL = actualReinforcementDurationMSorUL + elapsedTime*1000.0;
        elseif strcmp(getRewardMethod(station),'localPump')
            % in localPump mode, msRewardOwed gets zeroed out after the call to station/doReward
            % no need to update here
        end
    end
    lastRewardTime = GetSecs();
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % start/stop as necessary
    rStart = msRewardOwed > 0.0 && ~rewardCurrentlyOn;
    rStop = msRewardOwed <= 0.0 && rewardCurrentlyOn;
    currentValveStates=getValves(station);         % get current state of valves and what to change
    
    % if any doValves, override this stuff
    % newValveState will be used to keep track of doValves stuff - figure out server-based use later
    if any(doValves~=newValveState)
        %newValveState
        switch getRewardMethod(station)
            case 'localTimed'
                [newValveState phaseRecords(specInd).valveErrorDetails]=...
                    setAndCheckValves(station,doValves,currentValveStates,...
                    phaseRecords(specInd).valveErrorDetails,...
                    GetSecs,'doValves');
                %doValves
                %disp('set doValves')
                %GetSecs
            case 'localPump'
                if any(doValves)
                    primeMLsPerSec=1.0;
                    if window<=0 || strcmp(tm.displayMethod,'LED')
                        ifi
                        error('ifi will not be appropriate here when using LED')
                    else
                        station=doReward(station,primeMLsPerSec*ifi,doValves,true);
                    end
                end
                newValveState=0*doValves; % set newValveStates to 0 because localPump locks the loop while calling doReward
            otherwise
                error('unsupported rewardMethod');
        end
        
    else
        
        if rStart || rStop
            rewardValves=zeros(1,getNumPorts(station));
            % we give the reward at whatever port is specified by the current phase (weird...fix later?)
            % the default if the current phase does not have a criterion port is the requestOptions (input to stimOGL)
            % 1/29/09 - fix, but for now rewardValves is jsut wahtever the current port triggered is (this works for now..)
            if strcmp(class(ports),'double') %happens on osx, why?
                ports=logical(ports);
            end
            rewardValves(ports)=1;
            
            %         if isempty(rewardPorts)
            %             rewardValves(requestOptions) = 1;
            %         else
            %             rewardValves(rewardPorts)=1;
            %         end
            rewardValves=logical(rewardValves);
            
            if length(rewardValves) ~= 3
                error('rewardValves has %d and currentValveStates has %d with port = %d', length(rewardValves), length(currentValveStates), port);
            end
            
            switch getRewardMethod(station)
                case 'localTimed'
                    % handle start and stop cases
                    if rStart
                        %'turning on localTimed reward'
                        rewardCurrentlyOn = true;
                        %OPEN VALVE
                        [currentValveStates phaseRecords(specInd).valveErrorDetails]=...
                            setAndCheckValves(station,rewardValves,currentValveStates,...
                            phaseRecords(specInd).valveErrorDetails,...
                            lastRewardTime,'correct reward open');
                        %rewardValves
                        %disp('opening valves')
                        %GetSecs
                    elseif rStop
                        %'turning off reward'
                        rewardCurrentlyOn = false;
                        %CLOSE VALVE
                        [currentValveStates phaseRecords(specInd).valveErrorDetails]=...
                            setAndCheckValves(station,zeros(1,getNumPorts(station)),currentValveStates,...
                            phaseRecords(specInd).valveErrorDetails,...
                            lastRewardTime,'correct reward close');
                        %                     newValveState=doValves|rewardValves; % this shouldnt be used for now...figure out later...
                        %disp('closing valves')
                        %GetSecs
                    else
                        error('has to be either start or stop - should not be here');
                    end
                case 'localPump'
                    % localPump method copied from merge stimOGL
                    % (non-phased)
                    if rStart
                        %'turning on localPump reward'
                        rewardCurrentlyOn=true;
                        station=doReward(station,msRewardOwed/1000,rewardValves);
                        actualReinforcementDurationMSorUL = actualReinforcementDurationMSorUL + msRewardOwed;
                        msRewardOwed=0;
                        requestRewardDone=true;
                    elseif rStop
                        rewardCurrentlyOn=false;
                    end
                    % there is nothing to do in the stop case, because the doReward method is already timed to msRewardOwed
                case 'serverPump'
                    % handle serverPump method
                    
                    
                    % =====================================================================================================================
                    % function here to handle serverValveChange and set up serverPump reward method
                    [currentValveState phaseRecords(specInd).valveErrorDetails quit serverValveChange phaseRecords(specInd).responseDetails ...
                        requestRewardStartLogged requestRewardDurLogged] = ...
                        setupServerPumpRewards(tm, rn, station, newValveState, currentValveState, phaseRecords(specInd).valveErrorDetails, ...
                        startTime, serverValveChange, requestRewardStarted, requestRewardStartLogged, rewardValves, requestRewardDone, ...
                        requestRewardDurLogged, phaseRecords(specInd).responseDetails, quit);
                    
                    % =====================================================================================================================
                    % actually carry out serverPump rewards
                    % copied from merge code doTrial
                    valveStart=GetSecs();
                    timeout=-5.0;
                    % trialManager.soundMgr = playLoop(trialManager.soundMgr,'correctSound',station,1); % dont need to play sound (handled by phases)
                    
                    sprintf('*****should be no output between here *****')
                    
                    stopEarly=sendToServer(rn,getClientId(rn),constants.priorities.IMMEDIATE_PRIORITY,constants.stationToServerCommands.C_REWARD_CMD,{rewardSizeULorMS,logical(rewardValves)});
                    rewardDone=false;
                    while ~rewardDone && ~stopEarly
                        [stopEarly openValveCom openValveCmd openValveCmdArgs]=waitForSpecificCommand(rn,[],constants.serverToStationCommands.S_SET_VALVES_CMD,timeout,'waiting for server open valve response to C_REWARD_CMD',constants.statuses.MID_TRIAL);
                        
                        
                        if stopEarly
                            'got stopEarly 2'
                        end
                        
                        
                        if ~stopEarly
                            
                            if any([isempty(openValveCom) isempty(openValveCmd) isempty(openValveCmdArgs)])
                                error('waitforspecificcommand acted like it got a stop early even though it says it didn''t')
                            end
                            
                            requestedValveState=openValveCmdArgs{1};
                            isPrime=openValveCmdArgs{2};
                            
                            
                            
                            if ~isPrime
                                rewardDone=true;
                                phaseRecords(specInd).latencyToOpenValveRecd=GetSecs()-valveStart;
                                
                                [stopEarly phaseRecords(specInd).valveErrorDetails,...
                                    phaseRecords(specInd).latencyToOpenValves,...
                                    phaseRecords(specInd).latencyToCloseValveRecd,...
                                    phaseRecords(specInd).latencyToCloseValves,...
                                    phaseRecords(specInd).actualRewardDuration,...
                                    phaseRecords(specInd).latencyToRewardCompleted,...
                                    phaseRecords(specInd).latencyToRewardCompletelyDone]...
                                    =clientAcceptReward(...
                                    rn,...
                                    openValveCom,...
                                    station,...
                                    timeout,...
                                    valveStart,...
                                    requestedValveState,...
                                    rewardValves,...
                                    isPrime);
                                
                                if stopEarly
                                    'got stopEarly 3'
                                end
                                
                            else
                                
                                [stopEarly phaseRecords(specInd).primingValveErrorDetails(end+1),...
                                    phaseRecords(specInd).latencyToOpenPrimingValves(end+1),...
                                    phaseRecords(specInd).latencyToClosePrimingValveRecd(end+1),...
                                    phaseRecords(specInd).latencyToClosePrimingValves(end+1),...
                                    phaseRecords(specInd).actualPrimingDuration(end+1),...
                                    garbage,...
                                    garbage]...
                                    =clientAcceptReward(...
                                    rn,...
                                    openValveCom,...
                                    station,...
                                    timeout,...
                                    valveStart,...
                                    requestedValveState,...
                                    [],...
                                    isPrime);
                                
                                if stopEarly
                                    'got stopEarly 4'
                                end
                            end
                        end
                        
                    end
                    
                    sprintf('*****and here *****')
                otherwise
                    error('unsupported rewardMethod');
            end
        end
        
    end % end if not doValves
    
    timestamps.rewardDone=GetSecs;
    
    % end reward stuff
    % =====================================================================================================================
    % =====================================================================================================================
    % make function to handle server stuff
    if ~isempty(rn) || strcmp(getRewardMethod(station),'serverPump')
        [done quit phaseRecords(specInd).valveErrorDetails serverValveStates serverValveChange ...
            response newValveState requestRewardDone requestRewardOpenCmdDone] ...
            = handleServerCommands(tm, rn, done, quit, requestRewardStarted, requestRewardStartLogged, requestRewardOpenCmdDone, ...
            requestRewardDone, station, ports, serverValveStates, doValves, response);
    elseif isempty(rn) && strcmp(getRewardMethod(station),'serverPump')
        error('need a rnet for serverPump')
    end
    
    timestamps.serverCommDone=GetSecs;
    
    % =====================================================================================================================
    %before can end, must make sure any request rewards are done so
    %that the valves will be closed.  this includes server reward
    %requests.  right now there is a bug if the response occurs before
    %the request reward is over.
    
    % airpuff stuff
    if ~isempty(lastAirpuffTime) && airpuffOn
        % if airpuff was on from last loop, then subtract from debt
        elapsedTime = GetSecs() - lastAirpuffTime;
        msAirpuffOwed = msAirpuffOwed - elapsedTime*1000.0;
        actualReinforcementDurationMSorUL = actualReinforcementDurationMSorUL + elapsedTime*1000.0;
    end
    
    aStart = msAirpuffOwed > 0 && ~airpuffOn;
    aStop = msAirpuffOwed <= 0 && airpuffOn;
    if aStart || doPuff
        setPuff(station, true);
        airpuffOn = true;
    elseif aStop
        doPuff = false;
        airpuffOn = false;
        setPuff(station, false);
    end
    lastAirpuffTime = GetSecs();
    
    % record some information to phaseRecords if we are transitioning to a new phase
    if updatePhase
        phaseRecords(specInd).transitionedByPortResponse = transitionedByPortFlag;
        phaseRecords(specInd).transitionedByTimeout = transitionedByTimeFlag;
        phaseRecords(specInd).containedManualPokes = didManual;
        phaseRecords(specInd).leftWithManualPokingOn = manual;
        if didManual %if any phase does a manual poke, then the trialRecord should reflect this
            didManualInTrial=true;
        end
        phaseRecords(specInd).didStochasticResponse = didStochasticResponse;
        
        % how do we only clear the textures from THIS phase (since all textures for all phases are precached....)
        % close all textures from this phase if in non-expert mode
        %         if ~strcmp(strategy,'expert')
        %             Screen('Close');
        %         else
        %             expertCleanUp(stimManager);
        %         end
    end
    
    timestamps.phaseRecordsDone=GetSecs;
    
    % increment counters as necessary
    specInd = newSpecInd; % update specInd if necessary
    frameNum = frameNum + 1;
    totalFrameNum = totalFrameNum + 1; % 10/19/08 - for eyeTracker indexing
    framesSinceKbInput = framesSinceKbInput + 1;
    
    timestamps.loopEnd=GetSecs;
    %logwrite('end of stimOGL loop');
end

% =====================================================================================================================
% function here to do closing stuff after real time loop

% 10/28/08 - add three more frame pulses (to determine end of last frame)
if doFramePulse
    % do 3 pulses b/c the analysis expects a 2-pulse signal followed by a single-pulse signal
    framePulse(station);
    framePulse(station);
    framePulse(station);
end

if ~isempty(analogOutput)
    evts=showdaqevents(analogOutput);
    if ~isempty(evts)
        evts
    end
    
    stop(analogOutput);
    delete(analogOutput); %should pass back to caller and preserve for next trial so intertrial works and can avoid contruction costs
end

Screen('Close'); %leaving off second argument closes all textures but leaves windows open
Priority(originalPriority);
%ListenChar(0); %not the best place for this -- we wind up getting intertrial key strokes going thru

% function [tm responseDetails] = closeRealTimeLoop(tm, responseDetails, station, frameNum, startTime, valveErrorDetails, window, texture,
%   destRect, filtMode, dontclear, vbl, framesPerUpdate, ifi, originalPriority)
% [tm responseDetails] = closeRealTimeLoop(tm, responseDetails, station,
% frameNum, startTime, valveErrorDetails, window, textures(size(stim,3)+1), ...
%   destRect, filtMode, dontclear, vbl, framesPerUpdate, ifi, originalPriority);

% =====================================================================================================================
end % end function
