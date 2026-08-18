clear;
clc;
close all;
addpath("func/timeConversion/time/");
addpath("func");

% Planet constants (Mars)
pl_ID = 4;
mu  = astroConstants(10 + pl_ID);      % [km^3/s^2]
R   = astroConstants(20 + pl_ID);      % [km]
j2  = astroConstants(30 + pl_ID);      % [-]
j3 = 3.145e-5;
omegaMars = [0; 0; 7.0882181e-5];      % [rad/s]
AU_km     = 149597870.7;               % [km]
Psr_1AU   = 4.56e-6;                   % [N/m^2] at 1 AU

% Official-like MAVEN nominal science orbit
hp = 150;                              % [km]
ha = 6200;                             % [km]
a  = R + (hp + ha)/2;
rp = R + hp;
ra = R + ha;
e  = (ra - rp) / (ra + rp);
incl = deg2rad(75);
RAAN = 0;
omg  = 0;
th   = 0;

[r0, v0] = kep2car(a, e, incl, RAAN, omg, th, mu);
y0 = [r0; v0];

% Spacecraft model
sc.mass_kg   = 903;
sc.Cr        = 1.30;
sc.Cd        = 2.20;
sc.A_srp_m2  = 14.0;
sc.A_drag_m2 = 5.0;

% Simple Mars atmosphere model
atm.h0_km = 0.0;
atm.H_km  = 11.111111;

atm.A11yr = 0.35;
atm.T11yr = 4014.1;
atm.AANN  = 0.2;
atm.TANN  = 686.98;

atm.t11yr = datetime(1998,9,1,0,0,0,'TimeZone','UTC');
atm.tANN  = datetime(1998,6,27,12,0,0,'TimeZone','UTC');

atm.rho_corr_low_kgkm3  = 0.05;
atm.rho_corr_high_kgkm3 = 0.15;
atm.hp_ref_km = 150.0;
atm.t_ref = datetime(2014,10,23,23,15,0,'TimeZone','UTC');

dt11_ref = days(atm.t_ref - atm.t11yr);
dtAN_ref = days(atm.t_ref - atm.tANN);
D_ref = 10*( atm.A11yr*sin(2*pi*dt11_ref/atm.T11yr) ...
           - atm.AANN*sin(2*pi*dtAN_ref/atm.TANN) );

atm.rho0_kgkm3 = atm.rho_corr_high_kgkm3 * exp((atm.hp_ref_km - atm.h0_km)/atm.H_km) / D_ref;

% Sun model
sun.sunHat_MCI   = [1; 0; 0];
sun.d_MarsSun_AU = 1.52;

% Propagation parameters
par.mu = mu;
par.R  = R;
par.J2 = j2;
par.J3 = j3;
par.omegaPlanet = omegaMars;

par.useJ2   = true;
par.useJ3   = true;
par.useSRP  = true;
par.useDrag = true;

par.Psr_1AU = Psr_1AU;
par.AU_km   = AU_km;

par.mass_kg   = sc.mass_kg;
par.Cr        = sc.Cr;
par.Cd        = sc.Cd;
par.A_srp_m2  = sc.A_srp_m2;
par.A_drag_m2 = sc.A_drag_m2;

par.atm = atm;
par.sun = sun;

% Time span
t0 = 0;
tf = 60 * 24 * 3600;                   % [s]
tEval = (t0:60:tf).';
opts = odeset('RelTol',1e-12,'AbsTol',1e-12,'MaxStep',300);

par.epoch = datetime(2014,11,16,0,0,0,'TimeZone','UTC');
time = par.epoch + seconds(tEval);

% Propagation
[T, S] = ode113(@(t,s) propagateMAVENOrbit(t, s, par), tEval, y0, opts);

% Cartesian states
r = S(:,1:3);
v = S(:,4:6);

% Radius and altitude histories
rho = vecnorm(r, 2, 2);
alt = rho - R;

% Pericenter detection
Torb0 = 2*pi*sqrt(a^3/mu);
dt = median(diff(T));
[negRp, idxPeri] = findpeaks(-rho, 'MinPeakDistance', max(1, round(0.8*Torb0/dt)));
rp_orb = -negRp;
hp_orb = rp_orb - R;
timePeri = par.epoch + seconds(T(idxPeri));

% Equivalent altitude band of nominal density corridor
dt11_peri = days(timePeri - atm.t11yr);
dtAN_peri = days(timePeri - atm.tANN);
D_peri = 10.^( atm.A11yr*sin(2*pi*dt11_peri/atm.T11yr) ...
             - atm.AANN*sin(2*pi*dtAN_peri/atm.TANN) );

h_corr_min = atm.h0_km - atm.H_km * log(atm.rho_corr_high_kgkm3 ./ (atm.rho0_kgkm3 .* D_peri));
h_corr_max = atm.h0_km - atm.H_km * log(atm.rho_corr_low_kgkm3  ./ (atm.rho0_kgkm3 .* D_peri));

% 3D orbit plot
fig1 = figure();
fig = gcf;
ax = axes(fig);

tNum = datenum(time);

surface(ax, ...
    [r(:,1) r(:,1)], ...
    [r(:,2) r(:,2)], ...
    [r(:,3) r(:,3)], ...
    [tNum tNum], ...
    'FaceColor', 'none', ...
    'EdgeColor', 'interp', ...
    'LineWidth', 1.4);

xlabel('X [km]');
ylabel('Y [km]');
zlabel('Z [km]');
title('MAVEN nominal science orbit - 60 days');
axis equal;
grid on;
hold(ax,'on');

marsTexture = imread('mars-texture.jpg');
[xm, ym, zm] = sphere(80);
surf(ax, R*xm, R*ym, R*zm, ...
    'FaceColor', 'texturemap', ...
    'CData', marsTexture, ...
    'EdgeColor', 'none');

view(ax,3);
colormap(ax,turbo);
caxis(ax,[tNum(1) tNum(end)]);

cb = colorbar(ax,'eastoutside');
nTicks = 6;
cb.Ticks = linspace(tNum(1), tNum(end), nTicks);
cb.TickLabels = cellstr(datestr(cb.Ticks, 'dd-mmm-yyyy'));
cb.Label.String = 'Date [UTC]';

% ax.InteractionOptions.RotateEnabled = true;
% ax.InteractionOptions.ZoomEnabled = true;
% ax.InteractionOptions.PanEnabled = true;
enableDefaultInteractivity(ax);
rotate3d(ax,'on');

hold(ax,'off');

% Pericenter altitude vs time with density corridor
fig2 = figure();
ax2 = gca;

tPeriNum = datenum(timePeri(:));
xpatch = [tPeriNum; flipud(tPeriNum)];
ypatch = [h_corr_min(:); flipud(h_corr_max(:))];

patch(ax2, xpatch, ypatch, [1.0 0.85 0.3], ...
    'FaceAlpha', 0.25, ...
    'EdgeColor', 'none', ...
    'DisplayName', 'Equivalent altitude band of nominal density corridor');

hold(ax2,'on');
plot(ax2, tPeriNum, hp_orb, 'o-', 'LineWidth', 1.2, 'MarkerSize', 4, ...
    'DisplayName', 'Pericenter altitude');
plot(ax2, tPeriNum, h_corr_min, '--', 'LineWidth', 1.0, ...
    'DisplayName', '\rho = 0.15 kg/km^3 equivalent altitude');
plot(ax2, tPeriNum, h_corr_max, '--', 'LineWidth', 1.0, ...
    'DisplayName', '\rho = 0.05 kg/km^3 equivalent altitude');

xlabel('Date [UTC]');
ylabel('Pericenter altitude [km]');
title('MAVEN pericenter altitude and equivalent altitude band of nominal density corridor');
datetick(ax2, 'x', 'dd-mmm-yyyy', 'keeplimits');
legend(ax2,'Location','best');
grid(ax2,'on');
hold(ax2,'off');

%% Export figures (nominal science orbit)
outDir = fullfile('figures');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
exportgraphics(fig1, fullfile(outDir, 'science-orbit-3d.png'), 'Resolution', 300);
exportgraphics(fig2, fullfile(outDir, 'science-orbit-pericenter-corridor.png'), 'Resolution', 300);



%% STATION KEEPING BUDGET

clear;
clc;
close all;
addpath("func/timeConversion/time/");
addpath("func");

% Planet constants (Mars)
pl_ID = 4;
mu  = astroConstants(10 + pl_ID);      % [km^3/s^2]
R   = astroConstants(20 + pl_ID);      % [km]
j2  = astroConstants(30 + pl_ID);      % [-]
j3 = 3.145e-5;
omegaMars = [0; 0; 7.0882181e-5];      % [rad/s]
AU_km     = 149597870.7;               % [km]
Psr_1AU   = 4.56e-6;                   % [N/m^2] at 1 AU

% Official-like MAVEN nominal science orbit
hp_nom = 155;                          % [km]
ha_nom = 6200;                         % [km]
a  = R + (hp_nom + ha_nom)/2;
rp = R + hp_nom;
ra = R + ha_nom;
e  = (ra - rp) / (ra + rp);
incl = deg2rad(75);
RAAN = 0;
omg  = 0;
th   = 0;

[r0, v0] = kep2car(a, e, incl, RAAN, omg, th, mu);
y0 = [r0; v0];

% Spacecraft model
sc.mass_kg   = 903;
sc.Cr        = 1.30;
sc.Cd        = 2.20;
sc.A_srp_m2  = 14.0;
sc.A_drag_m2 = 5.0;

% Simple Mars atmosphere model
atm.h0_km = 0.0;
atm.H_km  = 11.111111;

atm.A11yr = 0.35;
atm.T11yr = 4014.1;
atm.AANN  = 0.2;
atm.TANN  = 686.98;

atm.t11yr = datetime(1998,9,1,0,0,0,'TimeZone','UTC');
atm.tANN  = datetime(1998,6,27,12,0,0,'TimeZone','UTC');

atm.rho_corr_low_kgkm3  = 0.05;
atm.rho_corr_high_kgkm3 = 0.15;
atm.hp_ref_km = 155.0;
atm.t_ref = datetime(2014,10,23,23,15,0,'TimeZone','UTC');

dt11_ref = days(atm.t_ref - atm.t11yr);
dtAN_ref = days(atm.t_ref - atm.tANN);
D_ref = 10^( atm.A11yr*sin(2*pi*dt11_ref/atm.T11yr) ...
           - atm.AANN*sin(2*pi*dtAN_ref/atm.TANN) );

atm.rho0_kgkm3 = atm.rho_corr_high_kgkm3 * exp((atm.hp_ref_km - atm.h0_km)/atm.H_km) / D_ref;

% Sun model
sun.sunHat_MCI   = [1; 0; 0];
sun.d_MarsSun_AU = 1.52;

% Propagation parameters
par.mu = mu;
par.R  = R;
par.J2 = j2;
par.J3 = j3;
par.omegaPlanet = omegaMars;

par.useJ2   = true;
par.useJ3   = true;
par.useSRP  = true;
par.useDrag = true;

par.Psr_1AU = Psr_1AU;
par.AU_km   = AU_km;

par.mass_kg   = sc.mass_kg;
par.Cr        = sc.Cr;
par.Cd        = sc.Cd;
par.A_srp_m2  = sc.A_srp_m2;
par.A_drag_m2 = sc.A_drag_m2;

par.atm = atm;
par.sun = sun;

% Time span
dtOut = 60;                            % [s]
tMonth = 30 * 24 * 3600;               % [s]
tf = 60 * 24 * 3600;                   % [s]
opts = odeset('RelTol',1e-12,'AbsTol',1e-12,'MaxStep',300);

par.epoch = datetime(2014,11,16,0,0,0,'TimeZone','UTC');

% First arc: propagate slightly beyond 1 month to reach next apoapsis
Torb0 = 2*pi*sqrt(a^3/mu);
tArc1End = tMonth + ceil(1.2*Torb0/dtOut)*dtOut;
tEval1 = (0:dtOut:tArc1End).';

[T1, S1] = ode113(@(t,s) propagateMAVENOrbit(t, s, par), tEval1, y0, opts);

r1 = S1(:,1:3);
rho1 = vecnorm(r1, 2, 2);
[ra_peaks, idxApoAll] = findpeaks(rho1, 'MinPeakDistance', max(1, round(0.8*Torb0/dtOut)));

idxAfterMonth = find(T1(idxApoAll) >= tMonth, 1, 'first');
if isempty(idxAfterMonth)
    error('No apoapsis found after the first month. Increase tArc1End.');
end

idxApoBurn = idxApoAll(idxAfterMonth);
tBurn = T1(idxApoBurn);

rBurn = S1(idxApoBurn,1:3).';
vBurn = S1(idxApoBurn,4:6).';

rA = norm(rBurn);
vA = norm(vBurn);

rp_des = R + hp_nom;
a_des = 0.5 * (rA + rp_des);
vA_des = sqrt(mu * (2/rA - 1/a_des));

dv_sk_kms = vA_des - vA;
vHat = vBurn / norm(vBurn);
vBurnCorr = vBurn + dv_sk_kms * vHat;

yBurnCorr = [rBurn; vBurnCorr];

% Second arc: propagate from burn to 60 days total
tEval2 = (0:dtOut:(tf - tBurn)).';
[T2, S2] = ode113(@(t,s) propagateMAVENOrbit(t, s, par), tEval2, yBurnCorr, opts);

% Merge arcs
T = [T1(1:idxApoBurn-1); tBurn + T2];
S = [S1(1:idxApoBurn-1,:); S2];

time = par.epoch + seconds(T);
burnTimeUTC = par.epoch + seconds(tBurn);

% Cartesian states
r = S(:,1:3);
v = S(:,4:6);

% Radius and altitude histories
rho = vecnorm(r, 2, 2);
alt = rho - R;

% Pericenter detection
dt = median(diff(T));
[negRp, idxPeri] = findpeaks(-rho, 'MinPeakDistance', max(1, round(0.8*Torb0/dt)));
rp_orb = -negRp;
hp_orb = rp_orb - R;
timePeri = par.epoch + seconds(T(idxPeri));

% Equivalent altitude band of nominal density corridor
dt11_peri = days(timePeri - atm.t11yr);
dtAN_peri = days(timePeri - atm.tANN);
D_peri = 10.^( atm.A11yr*sin(2*pi*dt11_peri/atm.T11yr) ...
             - atm.AANN*sin(2*pi*dtAN_peri/atm.TANN) );

h_corr_min = atm.h0_km - atm.H_km * log(atm.rho_corr_high_kgkm3 ./ (atm.rho0_kgkm3 .* D_peri));
h_corr_max = atm.h0_km - atm.H_km * log(atm.rho_corr_low_kgkm3  ./ (atm.rho0_kgkm3 .* D_peri));

%% 3D orbit plot with plot3

fig3 = figure();
fig = gcf;
ax = axes(fig);
hold(ax,'on');
grid(ax,'on');
axis(ax,'equal');
view(ax,3);

% Orbit with plot3
plot3(ax, r(:,1), r(:,2), r(:,3), ...
    'Color', [0 0.4470 0.7410], ...
    'LineWidth', 1.4, ...
    'DisplayName', 'Orbit');

% Labels
xlabel(ax,'X [km]');
ylabel(ax,'Y [km]');
zlabel(ax,'Z [km]');
title(ax,'MAVEN nominal science orbit with monthly apoapsis station keeping - 60 days');

% Mars
marsTexture = imread('mars-texture.jpg');
[xm, ym, zm] = sphere(50);
surf(ax, R*xm, R*ym, R*zm, ...
    'FaceColor', 'texturemap', ...
    'CData', marsTexture, ...
    'EdgeColor', 'none', ...
    'DisplayName', 'Mars');

% Burn marker
scatter3(ax, rBurn(1), rBurn(2), rBurn(3), ...
    48, 'r', 'filled', ...
    'DisplayName', 'Station-keeping burn');

% Optional nicer lighting
camlight(ax,'headlight');
lighting(ax,'gouraud');

% Interactive rotation
rotate3d(fig,'on');

legend(ax,'Location','best');
hold(ax,'off');
%%
figure();
ax = axes();
tNum = datenum(time);

surface(ax, ...
    [r(:,1) r(:,1)], ...
    [r(:,2) r(:,2)], ...
    [r(:,3) r(:,3)], ...
    [tNum tNum], ...
    'FaceColor', 'none', ...
    'EdgeColor', 'interp', ...
    'LineWidth', 1.4);

xlabel('X [km]');
ylabel('Y [km]');
zlabel('Z [km]');
title('MAVEN nominal science orbit with monthly apoapsis station keeping - 60 days');
axis(ax,'equal');
grid(ax,'on');
hold(ax,'on');

marsTexture = imread('mars-texture.jpg');
[xm, ym, zm] = sphere(50);
surf(ax, R*xm, R*ym, R*zm, ...
    'FaceColor', 'texturemap', ...
    'CData', marsTexture, ...
    'EdgeColor', 'none');

scatter3(ax, rBurn(1), rBurn(2), rBurn(3), 48, 'r', 'filled');

view(ax,3);
colormap(ax,turbo);
clim(ax,[tNum(1) tNum(end)]);

cb = colorbar(ax,'eastoutside');
cb.Ticks = linspace(tNum(1), tNum(end), 6);
cb.TickLabels = cellstr(datestr(cb.Ticks, 'dd-mmm-yyyy'));
cb.Label.String = 'Date [UTC]';

ax.Interactions = [rotateInteraction zoomInteraction];
hold(ax,'off');
%% Pericenter altitude vs time with density corridor
fig4 = figure();
ax2 = gca;

tPeriNum = datenum(timePeri(:));
xpatch = [tPeriNum; flipud(tPeriNum)];
ypatch = [h_corr_min(:); flipud(h_corr_max(:))];

patch(ax2, xpatch, ypatch, [1.0 0.85 0.3], ...
    'FaceAlpha', 0.25, ...
    'EdgeColor', 'none', ...
    'DisplayName', 'Equivalent altitude band of nominal density corridor');

hold(ax2,'on');
plot(ax2, tPeriNum, hp_orb, 'o-', 'LineWidth', 1.2, 'MarkerSize', 4, ...
    'DisplayName', 'Pericenter altitude');
plot(ax2, tPeriNum, h_corr_min, '--', 'LineWidth', 1.0, ...
    'DisplayName', '\rho = 0.15 kg/km^3 equivalent altitude');
plot(ax2, tPeriNum, h_corr_max, '--', 'LineWidth', 1.0, ...
    'DisplayName', '\rho = 0.05 kg/km^3 equivalent altitude');
xline(ax2, datenum(burnTimeUTC), ':r', 'LineWidth', 1.2, ...
    'DisplayName', 'Monthly apoapsis burn');

xlabel('Date [UTC]');
ylabel('Pericenter altitude [km]');
title('MAVEN pericenter altitude and equivalent altitude band of nominal density corridor');
datetick(ax2, 'x', 'dd-mmm-yyyy', 'keeplimits');
legend(ax2,'Location','best');
grid(ax2,'on');
hold(ax2,'off');

%% Station-keeping budget extrapolation
missionStart = par.epoch;
missionEndProxy = datetime(2015,11,01,0,0,0,'TimeZone','UTC');
missionDuration_s = seconds(missionEndProxy - missionStart);
nMonthlySK = floor(missionDuration_s / tMonth);
dv_sk_ms = abs(dv_sk_kms) * 1000;
dv_budget_ms = nMonthlySK * dv_sk_ms;

fprintf('Monthly station-keeping burn epoch  = %s UTC\n', datestr(burnTimeUTC, 'dd-mmm-yyyy HH:MM:SS'));
fprintf('Monthly station-keeping deltaV      = %.6f m/s\n', dv_sk_ms);
fprintf('Assumed mission start               = %s UTC\n', datestr(missionStart, 'dd-mmm-yyyy HH:MM:SS'));
fprintf('Assumed end-of-life proxy           = %s UTC\n', datestr(missionEndProxy, 'dd-mmm-yyyy HH:MM:SS'));
fprintf('Number of monthly SK maneuvers      = %d\n', nMonthlySK);
fprintf('Total SK deltaV budget              = %.6f m/s\n', dv_budget_ms);

%% Export figures (station keeping)
outDir = fullfile('figures');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
exportgraphics(fig3, fullfile(outDir, 'station-keeping-3d.png'), 'Resolution', 300);
exportgraphics(fig4, fullfile(outDir, 'station-keeping-pericenter-corridor.png'), 'Resolution', 300);