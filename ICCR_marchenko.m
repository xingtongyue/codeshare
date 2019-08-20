%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Calculate Green's Functions Using Marchenko Methods
% ICCR_marchenko.m
%
% NAME - INSTITUTION
% Last Updated - July 2018
%
% This code accompanies the article 'An Introduction to Marchenko Methods for
% Subsurface Imaging' submitted to GEOPHYSICS on 22ND JANUARY 2018. The code
% comments direct readers to the relevant equations in the paper.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
clc; clear all; close all;
 
%% 1) USER INPUT - SETUP VARIABLES
 
% MARCHENKO DEPENDANT PARAMETERS
nitr=5;                                                                    % number of iterations (NOTE: more iterations = longer run time)
tp=0.2;                                                                    % marchenko taper - defined as a fraction of the number of receivers
scaling=1;                                                                 % marchenko scaling - may be required for other data sets, see van der Neut et al. (2015)
 
% SURVEY DEPENDANT PARAMETERS
dt=0.002;                                                                  % time sampling
dx=16;                                                                     % receiver spacing
o_min=4;                                                                   % initial receiver offset
 
% FIGURE DEPENDANT PARAMETERS
plt='y';                                                                   % plot figures 'y' (yes) or 'n' (no)
 
%% 2) LOAD DATA - ORDER = (time samples, receivers, sources)
 
sg=importdata('../UTILS/DATA/MAT/ICCR_marchenko_R.mat');                   % load reflectivity (R)
direct=importdata('../UTILS/DATA/MAT/ICCR_marchenko_TD.mat');              % load direct arrival (T_d)
filter=importdata('../UTILS/DATA/MAT/ICCR_marchenko_theta.mat');           % load filter (theta)
true=importdata('../UTILS/DATA/MAT/ICCR_marchenko_GT.mat');                % load true solution (for comparison)
 
%% 3) AUTOMATICALLY DEFINED - SETUP VARIABLES
 
ns=size(sg,2);                                                             % number of sources/receivers
ro=o_min:dx:(o_min+(ns-1)*dx);                                             % vector of source/receiver offsets
ts=ceil(size(sg,1));                                                       % number of time samples
max_t=floor(ts/2)*dt;                                                      % maximum recording time
 
sg=fft(sg.*(-2*dt*dx*scaling));                                            % scale reflection response and transform to frequency domain
tap=tukeywin(ns,tp);tap=tap';                                              % tapering window
 
%% 4) FOCUSING FUNCTIONS - INITIAL ESTIMATES
 
f0_plus=fft(flipud(direct));                                               % time reverse (conjugate) direct arrival (equ. 3)
f0_minus=zeros(size(f0_plus));                                             % predefine f0_minus array
 
for nsrc=1:ns                                                              % loop (and stack) over all source positions
    f0_minus=f0_minus+(repmat(f0_plus(:,nsrc),[1 ns]).*sg(:,:,nsrc)...
        .*repmat(tap(:,nsrc),[ts ns]));                                    % convolve reflectivity and f0_plus (equ. 4 part 1)
end
 
f0_minus=filter.*ifftshift(real(ifft(f0_minus)),1);                        % apply window (in the time domain) (equ. 4 part 2)
 
fk_minus_tr=fft(flipud(f0_minus));                                         % transfer back to the frequency domain (time reversed)
f0_minus=fft(f0_minus);                                                    % transfer back to the frequency domain
 
%% 5) FOCUSING FUNCTIONS - ITERATIVE CALCULATION
 
for itr=1:nitr                                                             % loop over the number of iterations
    
    fk_minus=zeros(size(fk_minus_tr));                                     % predefine fk_minus array
    mk_plus=fk_minus;                                                      % predefine mk_plus array
    
    for nsrc=1:ns                                                          % loop (and stack) over all source positions
        mk_plus=mk_plus+(repmat(fk_minus_tr(:,nsrc),[1 ns])...
            .*sg(:,:,nsrc).*repmat(tap(:,nsrc),[ts ns]));                  % convolve reflectivity and (time reversed) fk_minus (equ. 5 part 1)
    end
    
    mk_plus=flipud(filter.*(ifftshift(real(ifft((mk_plus))),1)));          % apply window (in the time domain) (equ. 5 part 2)
    mk_plus=fft(mk_plus);                                                  % transfer back to the frequency domain
    
    for nsrc=1:ns                                                          % loop (and stack) over all source positions
        fk_minus=fk_minus+(repmat(mk_plus(:,nsrc),[1 ns]).*sg(:,:,nsrc)...
            .*repmat(tap(:,nsrc),[ts ns]));                                % convolve reflectivity and (time reversed) mk_plus (equ. 6 part 1)
    end
    
    fk_minus=real(ifft(f0_minus))+filter...
        .*(ifftshift(real(ifft(fk_minus)),1));                             % apply window (in the time domain) (equ. 6 part 2)
    fk_minus_tr=fft(flipud(fk_minus));                                     % transfer back to the frequency domain (time reversed)
    fk_minus=fft(fk_minus);                                                % transfer back to the frequency domain
    
end
 
fk_plus=f0_plus+mk_plus;                                                   % calculate total downgoing focusing function
 
%% 6) CALCULATE GREEN'S FUNCTIONS
 
g_minus=zeros(size(fk_plus));                                              % predefine g_minus array
g_plus=g_minus;                                                            % predefine g_plus array
 
for nsrc=1:ns                                                              % loop (and stack) over all source positions
    g_plus=g_plus+(repmat(fk_minus_tr(:,nsrc),[1 ns]).*sg(:,:,nsrc)...
        .*repmat(tap(:,nsrc),[ts ns]));                                    % convolve reflectivity and (time reversed) fk_minus (equ. 1/8 part 1)
    g_minus=g_minus+(repmat(fk_plus(:,nsrc),[1 ns]).*sg(:,:,nsrc)...
        .*repmat(tap(:,nsrc),[ts ns]));                                    % convolve reflectivity and fk_plus (equ. 2/9 part 1)
end
 
g_plus=flip(real(ifft(fk_plus)))-ifftshift(real(ifft(g_plus)),1);          % calculate downgoing green's function (equ. 1/8 part 2)
g_minus=-real(ifft(fk_minus))+ifftshift(real(ifft(g_minus)),1);            % calculate upgoing green's function (equ. 1/9 part 2)

g_total=g_minus+g_plus;                                                    % calculate total green's function
 
% NORMALISE SIGNAL AMPLITUDE
true=true*(1/(max(max(abs(true)))));
g_plus=g_plus*(1/(max(max(abs(g_total)))));
g_minus=g_minus*(1/(max(max(abs(g_total)))));
g_total=g_total*(1/(max(max(abs(g_total)))));

f0_plus=real(ifft(f0_plus));
f0_minus=real(ifft(f0_minus));
fk_plus=real(ifft(fk_plus));
fk_minus=real(ifft(fk_minus));
f0_minus=f0_minus*(1/(max(max(abs(fk_plus)))));
f0_plus=f0_plus*(1/(max(max(abs(fk_plus)))));
fk_minus=fk_minus*(1/(max(max(abs(fk_plus)))));
fk_plus=fk_plus*(1/(max(max(abs(fk_plus)))));
 
% APPLY PRE-DIRECT ARRIVAL MUTE
%   NOTE: Theoretically this step is not required. However, as discussed in
%   the text Marchenko methods in higher dimensions are more prone to
%   errors and these errors manifest themselves as  noise - this filter is
%   removing some of this noise.
filter2=(-filter+1);
g_total=g_total.*filter2;
g_minus=g_minus.*filter2;
g_plus=g_plus.*filter2;
true=true.*filter2;
 
%% 7) FIGURES
 
if plt=='y'
    
    %% 7.1) PLOT INPUT DATA
    
    shot=sort(randi(ns,1,4));
    
    figure;
    
    for idx=1:4
        
        subplot(1,4,idx)
        imagesc(ro,-max_t:dt:max_t,real(ifft(squeeze(sg(:,shot(idx),:)))));
        xlabel('Offset (m)')
        ylabel('Time (s)')
        caxis([-0.002 0.002])
        title(sprintf('Shot Offset %dm',ro(shot(idx))));
        xlim([min(ro) max(ro)])
        ylim([0 max_t])
        pbaspect([1 2.5 1])
        
    end
    
    colormap(gray(500))
    
    %% 7.2) PLOT FOCUSING FUNCTIONS
    
    figure;
    subplot(1,4,1)
    imagesc(ro,-max_t:dt:max_t,f0_plus)
    caxis([-.1 .1])
    xlabel('Offset (m)')
    ylabel('Time (s)')
    title('f_0^+');
    xlim([min(ro) max(ro)])
    ylim([-max_t+0.5 max_t-0.5])
    pbaspect([1 2.5 1])
    
    subplot(1,4,2)
    imagesc(ro,-max_t:dt:max_t,fk_plus)
    caxis([-.1 .1])
    xlabel('Offset (m)')
    ylabel('Time (s)')
    title(sprintf('f_{%d}^+',nitr));
    xlim([min(ro) max(ro)])
    ylim([-max_t+0.5 max_t-0.5])
    pbaspect([1 2.5 1])
    
    subplot(1,4,3)
    imagesc(ro,-max_t:dt:max_t,f0_minus)
    caxis([-.1 .1])
    xlabel('Offset (m)')
    ylabel('Time (s)')
    title('f_0^-');
    xlim([min(ro) max(ro)])
    ylim([-max_t+0.5 max_t-0.5])
    pbaspect([1 2.5 1])
    
    subplot(1,4,4)
    imagesc(ro,-max_t:dt:max_t,fk_minus)
    caxis([-.1 .1])
    xlabel('Offset (m)')
    ylabel('Time (s)')
    title(sprintf('f_{%d}^-',nitr));
    xlim([min(ro) max(ro)])
    ylim([-max_t+0.5 max_t-0.5])
    pbaspect([1 2.5 1])
    
    colormap(gray(500))
    
    %% 7.3) PLOT ESTIMATED GREEN'S FUNCTIONS
    
    figure;
    subplot(1,4,1)
    imagesc(ro,0:dt:max_t,g_minus(ceil(ts/2):end,:))
    caxis([-.1 .1])
    xlabel('Offset (m)')
    ylabel('Time (s)')
    title('G^-')
    xlim([min(ro) max(ro)])
    ylim([0 max_t-0.5])
    pbaspect([1 2.5 1])
    
    subplot(1,4,2)
    imagesc(ro,0:dt:max_t,g_plus(ceil(ts/2):end,:))
    caxis([-.1 .1])
    xlabel('Offset (m)')
    ylabel('Time (s)')
    title('G^+')
    xlim([min(ro) max(ro)])
    ylim([0 max_t-0.5])
    pbaspect([1 2.5 1])
    
    subplot(1,4,3)
    imagesc(ro,0:dt:max_t,g_total(ceil(ts/2):end,:))
    caxis([-.1 .1])
    xlabel('Offset (m)')
    ylabel('Time (s)')
    title('G_{MAR}')
    xlim([min(ro) max(ro)])
    ylim([0 max_t-0.5])
    pbaspect([1 2.5 1])
    
    subplot(1,4,4)
    imagesc(ro,0:dt:max_t,true(ceil(ts/2):end,:))
    caxis([-.1 .1])
    xlabel('Offset (m)')
    ylabel('Time (s)')
    title('G_{TRUE}')
    xlim([min(ro) max(ro)])
    ylim([0 max_t-0.5])
    pbaspect([1 2.5 1])
    
    colormap(gray(500))
    
end
 
%% END
