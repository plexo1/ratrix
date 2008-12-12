function [scrWidth scrHeight scaleFactor height width scrRect scrLeft scrTop scrRight scrBottom destRect] ...
    = determineScreenParametersAndLUT(tm, window, station, metaPixelSize, stim, LUT, verbose)
% This function determines the scaleFactor and LUT of the Screen window.
% Part of stimOGL rewrite.
% INPUT: window, station, metaPixelSize, stim, LUT
% OUTPUT: scrWidth scrHeight scaleFactor

if window>=0
    [scrWidth scrHeight]=Screen('WindowSize', window);
else
    scrWidth=getWidth(station);
    scrHeight=getHeight(station);
end

if metaPixelSize == 0
    scaleFactor = [scrHeight scrWidth]./[size(stim,1) size(stim,2)];
elseif length(metaPixelSize)==2 && all(metaPixelSize)>0
    scaleFactor = metaPixelSize;
else
    error('bad metaPixelSize argument')
end
if any(scaleFactor.*[size(stim,1) size(stim,2)]>[scrHeight scrWidth])
    scaleFactor.*[size(stim,1) size(stim,2)]
    scaleFactor
    size(stim)
    [scrHeight scrWidth]
    error('metaPixelSize argument too big')
end


height = scaleFactor(1)*size(stim,1);
width = scaleFactor(2)*size(stim,2);

if window>=0
    scrRect = Screen('Rect', window);
    scrLeft = scrRect(1); %am i retarted?  why isn't [scrLeft scrTop scrRight scrBottom]=Screen('Rect', window); working?  deal doesn't work
    scrTop = scrRect(2);
    scrRight = scrRect(3);
    scrBottom = scrRect(4);
else
    scrLeft = 0;
    scrTop = 0;
    scrRight = scrWidth;
    scrBottom = scrHeight;
end

destRect = round([((scrRight-scrLeft)/2)-(width/2) ((scrBottom-scrTop)/2)-(height/2) ((scrRight-scrLeft)/2)+(width/2) ((scrBottom-scrTop)/2)+(height/2)]); %[left top right bottom]




[oldCLUT, dacbits, reallutsize] = Screen('ReadNormalizedGammaTable', window);

%LOAD COLOR LOOK UP TABLE (if it is the right size)
if isreal(LUT) && all(size(LUT)==[256 3])
    if any(LUT(:)>1) || any(LUT(:)<0)
        error('LUT values must be normalized values between 0 and 1')
    end
    try
        oldCLUT = Screen('LoadNormalizedGammaTable', window, LUT,0); %apparently it's ok to use a window ptr instead of a screen ptr, despite the docs
    catch e
        %if the above fails, we lose our window :(
        %window=Screen('OpenWindow',max(Screen('Screens')));
        e.message
        %warning('failed to load clut and had to reopen the window, everything is probably screwed')
        error('couldnt set clut')
    end
    currentCLUT = Screen('ReadNormalizedGammaTable', window);
    %test clut values
    if all(all(currentCLUT-LUT<0.00001))
        if verbose
            disp('LUT is LOADED')
            disp('clut is more or less what you want it to be')
        end
    else
        oldCLUT
        currentCLUT
        LUT             %requested
        currentCLUT-LUT %error
        error('the LUT is not what you think it is')
    end
else
    reallutsize
    error('LUT must be real 256 X 3 matrix')
end

maxV=max(currentCLUT(:))
minV=min(currentCLUT(:))

if verbose && (minV ~= 0 || maxV ~= 1)
    disp(sprintf('clut has a min of %4.6f and a max of %4.6f',minV,maxV));
end

end % end function