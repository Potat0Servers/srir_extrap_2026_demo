function  freqplot_smooth(x, Fs, NoctSmoothing, graphFormatting, lineWidth)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function to plot the single sided frequency spectrum of an audio signal.
% Returns handle to the figure.
% Parameters:
% x: Input signal
% Fs: Sampling rate
% style: Plot style. e.g. 'r:' plots a red dotted line. See 'plot' help
% myfontsize: Text font size
% mytitle: figure title
% myxlabel: x-axis label
% myylabel: y-axis label
% my_ylim, my_xlim: axis limits in Hz.
% normflag: Normalise the spectrum prior to plotting. Makes the peak 0dBFS
% dcfiltflag: Removes any DC offset via a 30Hz highpass filter

% == Modified by Tom McKenzie, added octave smoothing option with variable
% == 'Noct', 2017

% NoctSmoothing is for octave smoothing (0 is no smoothing, 1 is 1 octave, 2 is 1/2
% octave, 3 is 1/3 octave, etc ...) TM 2017
% if nargin<5; lineWidth = 1;         end
if nargin<4; graphFormatting = '-'; end
if nargin<3; NoctSmoothing = 3;    end
if nargin<2; Fs = 48000;           end

if size(x,2)>size(x,1)
    x=x';
end

dcfiltflag = 0;
Nfft=length(x);
% Nfft=32;

% my_ylim= 
my_xlim = [20,20000];
normflag = 0;



%%%%%%%%%%%%%%% Gavin Kearney, University of York, 2015 %%%%%%%%%%%%%%%%%%%

if dcfiltflag == 1
    dcfilt = fir1(Nfft, 30/(Fs/2),'high'); % high pass filter
    x = fftfilt(dcfilt,x);
end

%%%%%%%%%%%%%%%%%%


% if nargin < 2
%     NoctSmoothing=0;
% end
% if nargin < 3
%     Nfft=8192;
% end
X=20*log10(abs(fft(x,Nfft)));

freq=(0:Fs/(Nfft-1):(Fs/2))';

%%%%%%%%%%%%%%%%%%%%%%%%

if normflag == 1
    X = X./max(abs(X(:))); % Normalize if requested
end

frlow = round(my_xlim(1)*Nfft/Fs); % Compute freq bins for x-axis limits
if frlow == 0; frlow = 1; end
frhigh = round(my_xlim(2)*Nfft/Fs);


f = Fs/Nfft:Fs/Nfft:Fs; % Frequency vector for plotting


%--------------------------------------------------------------------------
% octave smoothing --- adapted from
% https://uk.mathworks.com/matlabcentral/fileexchange/19228-short-time-fft-with-octave-smooth
% % Added by TM 2.2.2017

if NoctSmoothing > 0
    NoctSmoothing=2*NoctSmoothing;
    % octave center frequencies
    f1=1;
    i=0;
    while f1 < (Fs/2)
        f1=f1*10^(3/(10*NoctSmoothing));
        i=i+1;
        fc(i,:)=f1;
    end
    
    % octave edge frequencies
    for i=0:length(fc)-1
        i=i+1;
        f1=10^(3/(20*NoctSmoothing))*fc(i);
        fe(i,:)=f1;
    end
    
    % find nearest frequency edges
    for i=1:length(fe)
        fe_p=find(freq>fe(i),1,'first');
        fe_m=find(freq<fe(i),1,'last');
        fe_0=find(freq==fe(i));
        if isempty(fe_0)==0
            fe(i)=fe_0;
        else
            p=fe_p-fe(i);
            m=fe(i)-fe_m;
            if p<m
                fe(i)=fe_p;
            else
                fe(i)=fe_m;
            end
        end
    end
    assignin('base','a',fe);
    for i=1:length(fe)-1
        X_i=X(fe(i):fe(i+1),:);
        X_oct(i,1:size(X,2))=mean(X_i);
    end
    fc=fc(2:end);
    X_oct=interp1(fc,X_oct,freq,'spline');
end

%--------------------------------------------------------------------------

if NoctSmoothing > 0
    X=X_oct;
end

if nargin<5
    h = semilogx(f(frlow:frhigh),(X(frlow:frhigh)),graphFormatting); % plot
else
h = semilogx(f(frlow:frhigh),(X(frlow:frhigh)),graphFormatting,'LineWidth',lineWidth); % plot
end

% Formatting
xlim([30 20000]);
% ylim(my_ylim);

xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
grid on;
