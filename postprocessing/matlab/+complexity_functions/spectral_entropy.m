function [Spec, BandEn] = spectral_entropy(Sig, varargin) 
% SpecEn  estimates the spectral entropy of a univariate data sequence.
%
%   [Spec, BandEn] = SpecEn(Sig) 
% 
%   Returns the spectral entropy estimate of the full spectrum (``Spec``)
%   and the within-band entropy (``BandEn``) estimated from the data sequence 
%   (``Sig``) using the default parameters: 
%   N-point FFT = ``length(Sig)*2 + 1``, normalised band edge frequencies = [0 1],
%   logarithm = natural, normalisation = w.r.t # of spectrum/band values.
%
%   [Spec, BandEn] = SpecEn(Sig, name, value, ...)
% 
%   Returns the spectral entropy (``Spec``) and the within-band entropy (``BandEn``)
%   estimate for the data sequence (``Sig``) using the specified name/value pair arguments:
%       * ``N``'     - Resolution of spectrum (N-point FFT), an integer > 1
%       * ``Freqs`` - Normalised spectrum band edge-frequencies, a 2 element vector
%         with values in range [0 1] where 1 corresponds to the Nyquist frequency (Fs/2).
%         Note: When no band frequencies are entered, ``BandEn == SpecEn``
%       * ``Logx``  - Logarithm base, a positive scalar (default: natural log) 
%       * ``Norm``  - Normalisation of ``Spec`` value, a boolean:
%               -  [false]  no normalisation.
%               -  [true]   normalises w.r.t # of spectrum/band frequency values (default).
%
%   See also:
%       XSpecEn, fft, periodogram
%   
%   References:
%     [1] G.E. Powell and I.C. Percival,
%           "A spectral entropy method for distinguishing regular and 
%           irregular motion of Hamiltonian systems." 
%           Journal of Physics A: Mathematical and General 
%           12.11 (1979): 2053.
% 
%     [2] Tsuyoshi Inouye, et al.,
%           "Quantification of EEG irregularity by use of the entropy of 
%           the power spectrum." 
%           Electroencephalography and clinical neurophysiology 
%           79.3 (1991): 204-210.
% 
narginchk(1,9)
Sig = squeeze(Sig);
p = inputParser;
Chk = @(x) isnumeric(x) && isscalar(x) && (x > 1) && (mod(x,1)==0);
Chk2 = @(x) isvector(x) && (min(x) >= 0) && (max(x) <= 1) && (length(x)==2);
addRequired(p,'Sig',@(x) isnumeric(x) && isvector(x) && (length(x) > 10));
addParameter(p,'N',(length(Sig)*2)+1,Chk);
addParameter(p,'Freqs',[0 1],Chk2);
addParameter(p,'Logx',exp(1),@(x) isscalar(x) && (x >= 0));
addParameter(p,'Norm',true,@(x) islogical(x));
parse(p,Sig,varargin{:})
N = p.Results.N; Freqs = p.Results.Freqs; 
Logx = p.Results.Logx; Norm = p.Results.Norm;
if Logx == 0
    Logx = exp(1);
end
if size(Sig,1) > size(Sig,2)
    Sig = Sig';
end
Fx = ceil(N/2);
Freqs = round(Freqs*Fx);
Freqs(Freqs==0) = 1;
if Freqs(1) > Freqs(2)
    error('Lower band frequency must come first.')
elseif diff(Freqs) < 1
    error('Spectrum resoution too low to determine bandwidth.') 
elseif min(Freqs)<0 || max(Freqs)>Fx
    error('Freqs must be normalized w.r.t sampling frequency [0 1].')
% elseif round(Freqs*ceil(N/2)) > N || round(Freqs*ceil(N/2)) < 1
%     error('Spectrum resoution too low - rounding error.')      
end
Pt = abs(fft(conv(Sig,Sig),N));
Pxx = Pt(1:Fx)/sum(Pt(1:Fx));
Spec = -(Pxx*log(Pxx)')/log(Logx);
Pband = (Pxx(Freqs(1):Freqs(2)))/sum(Pxx(Freqs(1):Freqs(2)));
BandEn = -(Pband*log(Pband)')/log(Logx);
if Norm
    Spec = Spec/(log(Fx)/log(Logx));
    BandEn = BandEn/(log(diff(Freqs)+1)/log(Logx));
end
end
%   Copyright 2021 Matthew W. Flood, EntropyHub
% 
%   Licensed under the Apache License, Version 2.0 (the "License");
%   you may not use this file except in compliance with the License.
%   You may obtain a copy of the License at
%
%        http://www.apache.org/licenses/LICENSE-2.0
%
%   Unless required by applicable law or agreed to in writing, software
%   distributed under the License is distributed on an "AS IS" BASIS,
%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%   See the License for the specific language governing permissions and
%   limitations under the License.
%
%   For Terms of Use see https://github.com/MattWillFlood/EntropyHub
