function setupMice
names = {'test','j10lt','j10ln','j8lt','j8ln'};
%names = {'test','j10rt','j8rt','j7rt','j6rt'};

ratrixPath = 'C:\Users\nlab\Desktop\mouseData';
for i=1:length(names)
    standAloneRun(ratrixPath,'setProtocolMouse',names{i},[],[],true)
end
end