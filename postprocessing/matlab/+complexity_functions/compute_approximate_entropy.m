function APEN= compute_approximate_entropy(channelEegSignal)
%%    

 %   for i = 1:1%size(pxx, 1)
 %           approximateEntropy(eegSignal(i,:))
 %   end
 %complexity_functions.approximate_entropy(eegSignal(1,:),5, 0.2)
 tic
 [C, H] = complexity_functions.Lempel_Ziv_complexity(eegSignal(1,:), 'exhaustive', 1)
 toc
%%
end