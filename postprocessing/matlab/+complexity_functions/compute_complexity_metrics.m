function Comp_metrics= compute_complexity_metrics(eegSignal, fs)

%%
    FD = zeros(size(eegSignal, 1),1);
    PE = zeros(size(eegSignal, 1),1);
    WMEAN = zeros(size(eegSignal, 1),1);
    SSV = zeros(size(eegSignal, 1),1);

    for i = 1:size(eegSignal, 1)
        channe1 = eegSignal(i,:);
        
        fd = abs(complexity_functions.fractal_dimension(channe1)); % abs del número complejo (está bien?)
        [pe,hist] = complexity_functions.permutation_entropy(channe1, 3, 1);
        [wmean,ssv] = complexity_functions.wiener_entropy(channe1, fs);

        FD(i) = fd;
        PE(i) = pe;
        WMEAN(i) = wmean;
        SSV(i) = ssv;

    end
    
    Comp_metrics.FD = FD;
    Comp_metrics.PE = PE;
    Comp_metrics.WMEAN = WMEAN;
    Comp_metrics.SSV = SSV;

    clc
end