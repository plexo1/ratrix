function out=stimMgrOKForTrialMgr(sm,tm)
if isa(tm,'trialManager')
    switch class(tm)
        case {'freeDrinks' 'nAFC'}
            out=true;
        otherwise
            out=false;
    end
else
    error('need a trialManager object')
end