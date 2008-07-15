function [step parameters]=setFlankerStimRewardAndTrialManager(parameters, nameOfShapingStep,tmClass)

if ~exist('tmClass','var')
    tmClass='nAFC'
end

p=parameters;
stim = ifFeatureGoRightWithTwoFlank([p.pixPerCycs],[p.goRightOrientations],[p.goLeftOrientations],[p.flankerOrientations],...
    p.topYokedToBottomFlankerOrientation,p.topYokedToBottomFlankerContrast,[p.goRightContrast],[p.goLeftContrast],...
    [p.flankerContrast],p.mean,p.cueLum,p.cueSize,p.xPositionPercent,p.cuePercentTargetEcc,p.stdGaussMask,p.flankerOffset,...
    p.framesJustFlanker,p.framesTargetOn,p.thresh,p.yPositionPercent,p.toggleStim,p.typeOfLUT,p.rangeOfMonitorLinearized,...
    p.maxCorrectOnSameSide,p.positionalHint,p.xPosNoise,p.yPosNoise,p.displayTargetAndDistractor,p.phase,p.persistFlankersDuringToggle,...
    p.distractorFlankerYokedToTargetFlanker,p.distractorOrientation,p.distractorFlankerOrientation,p.distractorContrast,...
    p.distractorFlankerContrast, p.distractorYokedToTarget, p.flankerYokedToTargetPhase, p.fractionNoFlanks,...
    p.shapedParameter, p.shapingMethod, p.shapingValues,...
    p.gratingType, p.framesMotionDelay, p.numMotionStimFrames, p.framesPerMotionStim,...
    p.protocolType,p.protocolVersion,p.protocolSettings, ...
    p.flankerPosAngle,...
    p.maxWidth,p.maxHeight,p.scaleFactor,p.interTrialLuminance);

increasingReward=rewardNcorrectInARow(p.rewardNthCorrect,p.msPenalty,p.fractionOpenTimeSoundIsOn,p.fractionPenaltySoundIsOn, p.scalar);

switch tmClass
    case 'nAFC'
        tm=nAFC(p.msFlushDuration,p.msMinimumPokeDuration,p.msMinimumClearDuration,p.sndManager,...
            p.requestRewardSizeULorMS,p.percentCorrectionTrials,p.msResponseTimeLimit,p.pokeToRequestStim,...
            p.maintainPokeToMaintainStim,p.msMaximumStimPresentationDuration,p.maximumNumberStimPresentations,p.doMask,increasingReward);
    case 'promptedNAFC'
        
        %p.eyeTracker=geometricTracker(getDefaults(geometricTracker));
        p.eyeTracker=geometricTracker('simple', 2, 3, 12, 0, int16([1280,1024]), [42,28], int16([1024,768]), [400,290], 300, -25, 0, 45, 0);
        p.eyeController=[];

        
        tm=promptedNAFC(p.msFlushDuration,p.msMinimumPokeDuration,p.msMinimumClearDuration,p.sndManager,...
            p.requestRewardSizeULorMS,p.percentCorrectionTrials,p.msResponseTimeLimit,p.pokeToRequestStim,...
            p.maintainPokeToMaintainStim,p.msMaximumStimPresentationDuration,p.maximumNumberStimPresentations,p.doMask,increasingReward,...
            p.delayMeanMs, p.delayStdMs, p.delayStim, p.promptStim,p.eyeTracker,p.eyeController);
end
step= trainingStep(tm, stim, p.graduation, p.scheduler); %it would be nice to add the nameOfShapingStep

