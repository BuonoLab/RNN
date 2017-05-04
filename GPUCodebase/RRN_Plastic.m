%Sussilo and Abbott
%Firing rate model with tau = 10;
%you can train w/ TRAIN_SWITCH = 1 and READW_SWITCH = 0;
%and test with 0 and 1, respectively.
%WExEx(pre,post);

clear historyEx historyExOld historyOut historyOUT WExEx WInEx WExOut WOutEx Figures historyEX
clear P PRec PreSyn
clear EXTARGET currentExTarget

close all

if TRAIN_SWITCH
    TrainLoops = wExOutTrainTrials;
    rand('seed',seed);
    randn('seed',seed);
else
    rand('seed',seed);
    randn('seed',seed);
end

if (TRAIN_RECURRENT_SWITCH == 1)
    TrainLoops = rrnTrainTrials;
    load(strcat(ratSaveFolder, 'ExTarget'));    %prestored target for all Ex units
end
g = testG;
alphaParam = 10; %10;
trainStart = initInputStart+initInputWind;
numIn = 30;
P_Connect = 0.2;
numOut= 1;

%% INPUT AMPLITUDES: Second Value is Real Input
%%% InAmp2 is set based on the current training/testing paradigm
InAmp    = initStims; %changed 5/22 for constant input
if TRAIN_SWITCH == 0 && TRAIN_RECURRENT_SWITCH == 0 && READW_SWITCH == 0 %get innate target
    InAmp2 = originalTonicLvl;
elseif TRAIN_SWITCH == 0 && TRAIN_RECURRENT_SWITCH == 1 && READW_SWITCH == 0 % RRN training
    InAmp2 = ExExTrainTonicStims;
elseif TRAIN_SWITCH == 0 && TRAIN_RECURRENT_SWITCH == 0 && READW_SWITCH == 1 % testing
    InAmp2 = testTonicStims;
elseif TRAIN_SWITCH == 1 && TRAIN_RECURRENT_SWITCH == 0 && READW_SWITCH == 1 % train WExOut
    InAmp2 = ExOutTrainTonicStim;
end
numStim = length(InAmp2);

%% Instantiate Weight matrices
WMask = rand(numEx,numEx);        %to make a sparse W matrix
WMask(find(WMask<(1-P_Connect)))=0;
WMask(find(WMask>0)) = 1;
WExEx = randn(numEx,numEx)*sqrt(1/(numEx*P_Connect));
WExEx = g*WExEx.*WMask;

WExEx(1:(numEx+1):numEx*numEx)=0;
WExExInit = WExEx;
WOutEx = ((rand(1,numEx)*2)-1);
if (NOFEEDBACK)
    fprintf('NO FEEDBACK\n');
    WOutEx = WOutEx*0;
end
WExOut = randn(numEx,1)*sqrt(1/numEx);
WInEx = randn(numEx,numIn);

%% INITIAL CONDITIONS
Ex   = zeros(numEx,1);
Ex   = rand(numEx,1)*2-1;
ExV  = zeros(numEx,1);
Out  = zeros(numOut,1);
In   = zeros(numIn,1);

for i=1:numEx
    PreSyn(i).ind = find(WExEx(:,i));
    PRec(i).P = eye(length(PreSyn(i).ind))/alphaParam;
end
PREC = eye(numEx)/alphaParam;
P   = eye(numEx)/alphaParam;

if READW_SWITCH
    load(strcat(ratSaveFolder, 'W_RRN_Plastic'));
    tempseed = seed+tempseed;
    rand('seed',tempseed);
    randn('seed',tempseed);
end

%% generate the output target and scale output and RRN targets
totalTargLen = targLen+200; % total length to acquire 
activeRRNEnd = totalTargLen; % end of the period of RRN trajectory
if restEx
    totalTargLen = totalTargLen + restTime;
end
originalTarget = normpdf(1:activeRRNEnd,targLen,25);
historyOUT = num2cell(1:numStim)';
historyEX = num2cell(1:numStim)';
historyIN = num2cell(1:numStim)';
historyEXV = num2cell(1:numStim)';
Figures = {};

if TRAIN_RECURRENT_SWITCH == 1
    trainingExTarget = EXTARGET(:, trainStart+1:activeRRNEnd+trainStart);
    preTrainExTarget = EXTARGET(:,1:trainStart);
    if restEx
        restExTarget = EXTARGET(:, activeRRNEnd+trainStart+1:totalTargLen+trainStart);
%         restExTarget = EXTARGET(:, activeRRNEnd+1:totalTargLen);
    end
    highResExTarget = interp1(trainingExTarget',[1/HighResSampleRate:1/HighResSampleRate:activeRRNEnd]);
    highResOutTarget = interp1(1:activeRRNEnd,originalTarget,[1/HighResSampleRate:1/HighResSampleRate:activeRRNEnd]);
    for inAmpInd = 1:length(InAmp2)
        currentStim = InAmp2(inAmpInd);
        numScales = (currentStim-originalTonicLvl)/scalingTics*scaleDir;
        newExTargSample = round([1:(1/(1-scalingFactor*numScales)):activeRRNEnd]*HighResSampleRate);
        sampledExTarget = highResExTarget(newExTargSample,:);
        newExTarget = [preTrainExTarget sampledExTarget'];
        if restEx
            newExTarget = [preTrainExTarget sampledExTarget' restExTarget];
            newExTargLen = length(newExTarget);
            ZeroTime = newExTargLen-restTime;
            totalExLenWithRest = newExTargLen;
            ExTargetMask = 1:totalExLenWithRest;
            ExTargetMask(ZeroTime:end)= exp((-(([ZeroTime:totalExLenWithRest])-ZeroTime)/(2*tau)));
            ExTargetMask(ExTargetMask>1)=1;
            newExTarget = newExTarget.*repmat(ExTargetMask,numEx,1);
        end
        scaledExTargs{inAmpInd} = newExTarget;
        newOutTargSample = round([1:(1/(1-scalingFactor*numScales)):activeRRNEnd]*HighResSampleRate);
        scaledOutTargs{inAmpInd} = [[1:trainStart]*0,highResOutTarget(newOutTargSample)];
    end
    save(strcat(ratSaveFolder, 'scaledExTargs'), 'scaledExTargs', 'scaledOutTargs');
    save(strcat(ratSaveFolder, 'scaledOutTargs'), 'scaledOutTargs');
    clear highResExTarget highResOutTarget
elseif TRAIN_SWITCH == 1
    highResOutTarget = interp1(1:activeRRNEnd,originalTarget,[1/HighResSampleRate:1/HighResSampleRate:activeRRNEnd]);
    for inAmpInd = 1:length(InAmp2)
        currentStim = InAmp2(inAmpInd);
        numScales = (currentStim-originalTonicLvl)/scalingTics*scaleDir;
        %highResExTarget = highResExTarget';
        newOutTargSample = round([1:(1/(1-scalingFactor*numScales)):activeRRNEnd]*HighResSampleRate);
        scaledOutTargs{inAmpInd} = [[1:trainStart]*0,highResOutTarget(newOutTargSample)];
    end
    save(strcat(ratSaveFolder, 'scaledOutTargs'), 'scaledOutTargs');
    clear highResOutTarget
elseif TRAIN_SWITCH == 0 && TRAIN_RECURRENT_SWITCH == 0 && READW_SWITCH == 1
    highResOutTarget = interp1(1:activeRRNEnd,originalTarget,[1/HighResSampleRate:1/HighResSampleRate:activeRRNEnd]);
    for inAmpInd = 1:length(InAmp2)
        currentStim = InAmp2(inAmpInd);
        numScales = (currentStim-originalTonicLvl)/scalingTics*scaleDir;
        %highResExTarget = highResExTarget';
        newOutTargSample = round([1:(1/(1-scalingFactor*numScales)):activeRRNEnd]*HighResSampleRate);
        testOutTargets{inAmpInd} = [[1:trainStart]*0,highResOutTarget(newOutTargSample)];
    end
end
%% Training

for loop = 1:TrainLoops
    stim = mod(loop-1,numStim)+1;
    InAmp2(stim)
    %%% SET tmax, trainTime, and target %%%
    if TRAIN_SWITCH == 0 && TRAIN_RECURRENT_SWITCH == 0 && READW_SWITCH == 0 %Innate
        target = [[1:trainStart]*0,originalTarget];
        trainTime = length(target); %amount of time the network is trained to produce the target
        tmax = length(target);
        if restEx % if training a gated attractor
            tmax = tmax + restTime;
        end
    elseif TRAIN_SWITCH == 0 && TRAIN_RECURRENT_SWITCH == 0 && READW_SWITCH == 1 %Testing
        target = testOutTargets{stim};
        trainTime = 1;
        tmax = length(target);
        if restEx
            tmax = tmax + restTime;
        end
    elseif TRAIN_SWITCH == 0 && TRAIN_RECURRENT_SWITCH == 1 && READW_SWITCH == 0 %Train RRN
        target = [[1:trainStart]*0,originalTarget];
        currentExTarget = scaledExTargs{stim};
        trainTime = size(currentExTarget,2);
        tmax = length(currentExTarget);
    else                                                             %Train WExOut
        target = scaledOutTargs{stim};
        trainTime = length(target);
        tmax = length(target);
        if restEx
            tmax = tmax + restTime;
        end
    end

%% Define input pulses
    ResponseTime = [1000 8000];
    INPUT1   = [999999 999999; 999999 999999];
    INPUT2   = [initInputStart trainStart; 999999 999999];
    INPUT3   = [initInputStart tmax; 999999 999999];
    if restEx
        INPUT3   = [initInputStart (tmax - restTime); 999999 999999];
    end
    
    [numInputPulses2 dummy]=size(INPUT2);
    [numInputPulses3 dummy]=size(INPUT3);

    TRAIN_WINDOW = [trainStart+1 trainTime]
    TargetBase = 0;
    TARGET = zeros(1,tmax);
    
    targettime=TRAIN_WINDOW(1):length(target);
    TARGET(targettime) = ((1-TargetBase)/max(target))*target(targettime)+TargetBase;
    if (loop>1), historyExOld = historyEx; end
    historyEx=zeros(numEx,tmax);
    historyOut=zeros(numOut,tmax);
    historyIn =zeros(numIn,tmax);
    error_minus = zeros(1,tmax);
    error_plus = zeros(1,tmax);
    dW   = zeros(numEx,1);

%% Instatiate the netowrk state and begin the time loop
    if (TRAIN_SWITCH==0)
        fprintf('LEARNING IS OFF | LOOP = %3d(%d)\n',loop,stim);
    else
        fprintf('LOOP = %3d(%d)\n',loop,stim);
    end
    if (TRAIN_RECURRENT_SWITCH==1)
        fprintf('RECURRENT LEARNING IS ON | LOOP = %3d(%d)\n',loop,stim);
    end

    ExV = ExV*0;
    Ex  = Ex*0;
    Out = Out*0;

    %% random initial state
    ExV = 2*rand(numEx,1)-1;
postTime = 1000;
%% Time Loop
    for t=1:(tmax + postTime)
        In(:) = 0;
        if rem(t,1000)==0, fprintf('t=%5d\n',t), end;
        %% set the input amplitudes for this time step depending on the
        %% input window
        if (t>=INPUT1(1) && t<INPUT1(2))
            In(1) = InAmp(1);
        elseif (t>=INPUT1(3) && t<INPUT1(4))
            In(1) = 1;
        else
            In(1) = 0;
        end
        
        for i=1:numInputPulses2
            if (t>=INPUT2(i,1) && t<INPUT2(i,2))
                In(2) = InAmp(1);
                if (multipleTrigInputs==1 && PURE_TEST==1) %%if testing an untrained input
                    In(2) = 0;
                    In(4) = InAmp(1);
                end
            end
            
        end
        for i=1:numInputPulses3
            if (t>=INPUT3(i,1) && t<INPUT3(i,2))
                In(3) = InAmp2(stim);
            end
        end


        %%% DYNAMICS HAPPENS HERE
        ex_input = WExEx'*Ex + WInEx*In + randn(numEx,1)*NoiseAmp;
        ExV = ExV + (-ExV + ex_input)./tau;
        Ex = tanh(ExV);

        %%% UPDATE Ex & Out UNITS
        out_input = WExOut'*Ex;
        Out = out_input;
        if (TEACHER_FORCING == 1)
            TARGET(t)
        end

        %%    TRAIN OUTPUT UNIT
        if (TRAIN_SWITCH)
            if t>TRAIN_WINDOW(1) & t<TRAIN_WINDOW(2) % end of training
                error_minus(t) = Out - TARGET(t);
                %From Sussillo and Abbott Code
                k = P*Ex;
                ExPEx = Ex'*k;
                c = 1.0/(1.0 + ExPEx);
                P = P - k*(k'*c);
                dw = error_minus(t)*k*c;
                WExOut = WExOut - dw;

                dW(t) = sum(abs(dw));
            end
        end

        %%    TRAIN RECURRENT UNITS
        if (TRAIN_RECURRENT_SWITCH)
            if t>TRAIN_WINDOW(1) & t<TRAIN_WINDOW(2) % end of training
                error_rec = Ex - currentExTarget(:,t);
                firstExNum = 1;
                lastExNum = testExNum;
                
                 for i=[firstExNum:lastExNum]
                    tempWExs{i} = WExEx(PreSyn(i).ind, i);
                end
                parfor i=[firstExNum:lastExNum] %loop through Post Ex
                    %From Sussillo and Abbott Code
                    theseWExEx = tempWExs{i};
                    preind = PreSyn(i).ind;
                    ex = historyEx(preind,t-1);
                    k = PRec(i).P*ex;
                    expex = ex'*k;
                    c = 1.0/(1.0 + expex);
                    PRec(i).P = PRec(i).P - k*(k'*c);
                    dw = error_rec(i)*k*c;
                    WUpdate = theseWExEx - dw;
                    tempWExs{i} = WUpdate;
                end
                for i=[firstExNum:lastExNum]
                    WExEx(PreSyn(i).ind, i)=tempWExs{i};
                end


            end
        end

        historyEx(:,t)=Ex;
        historyOut(:,t)=Out;
        historyIn(:,t)=In;
        historyExV(:,t)=ExV;
    end
%% plot output graphs and save variables
    fig = figure(stim+5);
    SP1 = subplot(2,1,1);
    imagesc(historyEx);
    SP2 = subplot(2,1,2);
    plot(historyOut*4,'linewidth',[2]);
    hold on
    plot(TARGET*4,'r');
    plot(error_minus,'g');
    plot(dW,'c');
    plot(historyIn')
    plot( ( historyEx(1:10,:)-repmat(([1:10]*2)',1,(tmax+postTime)) )','linewidth',[1]);
    set(gca,'ylim',[-22 5]);
    set(SP2,'xlim',[0 tmax+150]);
    drawnow;
    Figures{stim} = fig;

    if TRAIN_SWITCH == 0 && TRAIN_RECURRENT_SWITCH == 0
        historyOUT{stim,((loop-stim)/numStim + 1)} = historyOut(:,:);
        historyEX{stim} = single(historyEx(:,:));
        historyIN{stim,((loop-stim)/numStim + 1)} = historyIn(:,:);
        historyEXV{stim} = single(historyExV(:,:));
%         historyEX{stim,((loop-stim)/numStim + 1)} = historyEx(:,:);
    end
end

if (TRAIN_SWITCH == 1 || TRAIN_RECURRENT_SWITCH == 1)
    save(strcat(ratSaveFolder, 'W_RRN_Plastic'), 'WExOut', 'WOutEx', 'WExEx', 'WInEx', 'seed', 'g', 'alpha', 'P_Connect') %NoiseAmp
end