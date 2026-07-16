
function eegSignal = data_gen(n_channels,fs, Ts, f0, A, N, nfft, n)

    eegSignal =  zeros(N, n_channels);

    for i=1:n_channels
        eegSignal(:,i)= A*sin(2*pi*f0*n*Ts) + .1*randn(1,N);    % 1 W sinewave + noise
    end

end

