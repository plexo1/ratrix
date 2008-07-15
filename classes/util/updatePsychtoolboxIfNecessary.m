function updatePsychtoolboxIfNecessary

[wcrev reprev repurl]=getSVNRevisionFromXML(psychtoolboxroot);
if wcrev ~= reprev %limit unnecessary use of updatepsychtoolbox due to the PsychtoolboxRegistration data 
    %Christopher Broussard chrg@sas.upenn.edu) maintains platypus.psych.upenn.edu and complained that we were
    %making his server logs gigantic
    
    %first remove our stuff from the path, cuz updatepsychtoolbox has the
    %side effect of making path change permanent
    p=path;
    r=getRatrixPath;
    while ~isempty(p)
        [item p]=strtok(p,pathsep);
        if ~isempty(findstr(r,item))
            rmpath(item);
        end
    end
    
    UpdatePsychtoolbox
else
    'psychtoolbox appears to be up to date, not updating'
end