clear;
clc;
close all;

addpath("func/timeConversion/time/");
addpath("func");

% Constants
mu_s  = astroConstants(4);
Body1 = 3;   % Earth
Body2 = 4;   % Mars

% MJD2000 reference epoch: 01-Jan-2000 12:00:00 UTC
t0_matlab = datenum([2000 1 1 12 0 0]);

% Mission reference dates for comparison
% MAVEN launch: 18-Nov-2013 18:28:00 UTC
% MAVEN MOI burn start: 22-Sep-2014 01:50:00 UTC
dep_target = date2mjd2000([2013 11 18 18 28 00]);
arr_target = date2mjd2000([2014 09 22 01 50 00]);

% Search windows
dep1_E = date2mjd2000([2013 11 10 0 0 0]);
dep2_E = date2mjd2000([2013 12 25 0 0 0]);
arr1_M = date2mjd2000([2014 09 15 0 0 0]);
arr2_M = date2mjd2000([2014 10 05 0 0 0]);

N_time = 1000;

% Force exact target dates into the grids
dt_dep_E = sort(unique([linspace(dep1_E, dep2_E, N_time), dep_target]));
dt_arr_M = sort(unique([linspace(arr1_M, arr2_M, N_time), arr_target]));

nDep = numel(dt_dep_E);
nArr = numel(dt_arr_M);

% Preallocation
C3_matrix       = NaN(nDep, nArr);
A_matrix        = NaN(nDep, nArr);
P_matrix        = NaN(nDep, nArr);
E_matrix        = NaN(nDep, nArr);
TPAR_matrix     = NaN(nDep, nArr);
TH_matrix       = NaN(nDep, nArr);
vInf_dep_matrix = NaN(nDep, nArr);
vInf_arr_matrix = NaN(nDep, nArr);
ToF_matrix      = NaN(nDep, nArr);
valid_mask      = false(nDep, nArr);

% Lambert sweep
for i = 1:nDep
    dep_mjd = dt_dep_E(i);

    [kepE, ~] = uplanet(dep_mjd, Body1);
    [rrE, vvE] = kep2car(kepE(1), kepE(2), kepE(3), kepE(4), kepE(5), kepE(6), mu_s);

    for j = 1:nArr
        arr_mjd  = dt_arr_M(j);
        tof_days = arr_mjd - dep_mjd;

        if tof_days <= 0
            continue
        end

        [kepM, ~] = uplanet(arr_mjd, Body2);

        % Correct order: [a e i Om om theta]
        [rrM, vvM] = kep2car(kepM(1), kepM(2), kepM(3), kepM(4), kepM(5), kepM(6), mu_s);

        tof_sec = tof_days * 86400;

        try
            [A, P, E, ERROR, v1T, v2T, TPAR, THETA] = lambertMR(rrE, rrM, tof_sec, mu_s, 0, 0, 0);

            if ERROR ~= 0
                continue
            end

            vInf_dep = v1T(:) - vvE(:);
            vInf_arr = v2T(:) - vvM(:);

            vInf_dep_matrix(i,j) = norm(vInf_dep);
            vInf_arr_matrix(i,j) = norm(vInf_arr);
            C3_matrix(i,j)       = norm(vInf_dep)^2;
            A_matrix(i,j)        = A;
            P_matrix(i,j)        = P;
            E_matrix(i,j)        = E;
            TPAR_matrix(i,j)     = TPAR;
            TH_matrix(i,j)       = THETA;
            ToF_matrix(i,j)      = tof_days;
            valid_mask(i,j)      = true;
        catch
            continue
        end
    end
end

%% Optional mask on ToF
% ToF_min = 290;
% ToF_max = 330;
% bad = ToF_matrix < ToF_min | ToF_matrix > ToF_max | ~valid_mask;
% C3_matrix(bad)       = NaN;
% vInf_arr_matrix(bad) = NaN;
% ToF_matrix(bad)      = NaN;

%% Plot axes in MATLAB datenum
x_dates = dt_dep_E + t0_matlab;
y_dates = dt_arr_M + t0_matlab;

% C3 map
fig1 = figure;
imagesc(x_dates, y_dates, C3_matrix');
axis xy;
colormap(jet);
clim([8 15]);
cb = colorbar;
title('MAVEN launch window: C3 [km^2/s^2]');
xlabel('Departure date');
ylabel('Arrival date');
ylabel(cb, 'C3 [km^2/s^2]');
datetick('x', 'dd-mmm-yy', 'keeplimits');
datetick('y', 'dd-mmm-yy', 'keeplimits');
axis tight;
set(fig1, 'Color', 'k');
set(findall(fig1, 'Type', 'axes'), 'Color', 'k', 'XColor', 'w', 'YColor', 'w');
set(findall(fig1, 'Type', 'text'), 'Color', 'w');

% Arrival vInf map
fig2 = figure;
imagesc(x_dates, y_dates, vInf_arr_matrix');
axis xy;
colormap(jet);
clim([3.0 3.4]);
cb = colorbar;
title('MAVEN launch window: Arrival v_\infty [km/s]');
xlabel('Departure date');
ylabel('Arrival date');
ylabel(cb, 'v_\infty [km/s]');
datetick('x', 'dd-mmm-yy', 'keeplimits');
datetick('y', 'dd-mmm-yy', 'keeplimits');
axis tight;

%% DEP-ARR couple selector
[~, i_dep] = min(abs(dt_dep_E - dep_target));
[~, j_arr] = min(abs(dt_arr_M - arr_target));

C3_value       = C3_matrix(i_dep, j_arr);
vInf_arr_value = vInf_arr_matrix(i_dep, j_arr);
ToF_value      = ToF_matrix(i_dep, j_arr);
th_value       = TH_matrix(i_dep, j_arr);

dep_selected = dt_dep_E(i_dep);
arr_selected = dt_arr_M(j_arr);

fprintf('Target departure = %s UTC\n', datestr(dep_target   + t0_matlab, 'dd-mmm-yyyy HH:MM:SS'));
fprintf('Grid   departure = %s UTC\n', datestr(dep_selected + t0_matlab, 'dd-mmm-yyyy HH:MM:SS'));
fprintf('Target arrival   = %s UTC\n', datestr(arr_target   + t0_matlab, 'dd-mmm-yyyy HH:MM:SS'));
fprintf('Grid   arrival   = %s UTC\n', datestr(arr_selected + t0_matlab, 'dd-mmm-yyyy HH:MM:SS'));

fprintf('Departure offset = %.3f min\n', (dep_selected - dep_target)*24*60);
fprintf('Arrival   offset = %.3f min\n', (arr_selected - arr_target)*24*60);

fprintf('C3        = %.6f km^2/s^2\n', C3_value);
fprintf('vInf_arr  = %.6f km/s\n', vInf_arr_value);
fprintf('THETA     = %.6f deg\n', th_value * 180/pi);
fprintf('ToF       = %.6f days\n', ToF_value);



%% MOI deltaV using MAVEN nominal initial capture orbit

mu_M = astroConstants(10+Body2);   % km^3/s^2
R_M  = astroConstants(20+Body2);   % km

T_cap  = 35 * 3600;    % s, nominal capture orbit period
hp_cap = 380;          % km, nominal capture periapsis altitude

rp_cap = R_M + hp_cap;
a_cap  = (mu_M * (T_cap/(2*pi))^2)^(1/3);
ra_cap = 2*a_cap - rp_cap;
ha_cap = ra_cap - R_M;
e_cap  = (ra_cap - rp_cap) / (ra_cap + rp_cap);

v_p_hyp = sqrt(vInf_arr_value^2 + 2*mu_M/rp_cap);         % km/s
v_p_cap = sqrt(mu_M*(2/rp_cap - 1/a_cap));                % km/s

deltaV_MOI_ms = (v_p_hyp - v_p_cap) * 1000;               % m/s


fprintf('Capture orbit period    = %.3f h\n', T_cap/3600);
fprintf('Capture orbit periapsis = %.3f km alt\n', hp_cap);
fprintf('Capture orbit apoapsis  = %.3f km alt\n', ha_cap);
fprintf('Capture orbit ecc       = %.6f\n', e_cap);
fprintf('deltaV_MOI              = %.3f m/s\n', deltaV_MOI_ms);

optimal_deltavmin_cap = vInf_arr_value * sqrt((e_cap+1)/2);
rp_optimal_deltavmin_cap = 2 * ((1-e_cap)/(1+e_cap)) * (mu_M/(vInf_arr_value^2));
ra_optimal_deltavmin_cap = 2  * (mu_M/(vInf_arr_value^2));



%% DEEP-DIPS
% hp: ra_sci = ra_dip

% e_sci = 0.4600;
ra_sci = R_M + 6200;
rp_dip = R_M + 125;
rp_sci = R_M + 150; 
% rp_sci = ra_sci * ((1-e_sci)/(1+e_sci));
ra_dip = ra_sci;
a_sci = (rp_sci + ra_sci) / 2;
a_dip = (rp_dip + ra_dip) / 2;
% delta_a = a_dip - a_sci;
e_sci = (ra_sci-rp_sci)/(ra_sci+rp_sci); 
e_dip = (ra_dip-rp_dip)/(ra_dip+rp_dip);
p_dip = a_dip * ( 1 - e_dip^2);
p_sci = a_sci * ( 1 - e_sci^2);
va_sci = sqrt(mu_M/p_sci) * ( 1 - e_sci );
va_dip = sqrt(mu_M/p_dip) * ( 1 - e_dip );
dv_dip = va_dip - va_sci;

% va_mean = (va_dip+va_sci)/2
% deltaE = (mu_M/2) * (1/a_sci - 1/(a_sci+delta_a));
% dv_mean = deltaE / va_mean

fprintf('deltaV_deep_dip         = 2 x |%.3f| = %.3f m/s\n', dv_dip*1000, abs(2*dv_dip*1000));


%% TRANSITION TO SCIENCE ORBIT

% PLM1 (Periapsis Lowering Maneuvre)

rp_plm1 = R_M + 200;
ra_plm1 = ra_cap;
e_plm1 = (ra_plm1 - rp_plm1)/(ra_plm1 + rp_plm1);
a_plm1 = 0.5*(ra_plm1+rp_plm1);
p_plm1 = a_plm1 * (1 - e_plm1^2);
p_cap = a_cap * ( 1 - e_cap^2 );
va_cap = sqrt(mu_M/p_cap) * (1 - e_cap);
va_plm1 = sqrt(mu_M/p_plm1) * (1 - e_plm1);
dv_plm1 = va_plm1 - va_cap;
fprintf('hp_plm1                 = 200 km\n');
fprintf('deltaV_plm1             = %.3f m/s\n', dv_plm1*1000);

vp_plm1 = sqrt(mu_M/p_plm1) * (1 + e_plm1);

% PRM1 (Period Reduction Maneuvre)

rp_prm1 = rp_plm1;
T_prm1  = 5.5 * 3600;    

a_prm1  = (mu_M * (T_prm1/(2*pi))^2)^(1/3);
ra_prm1 = 2*a_prm1 - rp_prm1;
ha_prm1 = ra_prm1 - R_M;
e_prm1  = (ra_prm1 - rp_prm1) / (ra_prm1 + rp_prm1);
p_prm1 = a_prm1 * (1 - e_prm1^2);

vp_prm1 = sqrt(mu_M/p_prm1) * (1 + e_prm1);
dv_prm1 = vp_prm1 - vp_plm1;

fprintf('deltaV_prm1             = %.3f m/s\n', dv_prm1*1000);

% PRM2 (Period Reduction Maneuvre)

rp_prm2 = rp_prm1;
T_prm2  = 4.61 * 3600;    

a_prm2  = (mu_M * (T_prm2/(2*pi))^2)^(1/3);
ra_prm2 = 2*a_prm2 - rp_prm2;
ha_prm2 = ra_prm2 - R_M;
e_prm2  = (ra_prm2 - rp_prm2) / (ra_prm2 + rp_prm2);
p_prm2 = a_prm2 * (1 - e_prm2^2);

vp_prm2 = sqrt(mu_M/p_prm2) * (1 + e_prm2);
dv_prm2 = vp_prm2 - vp_prm1;

fprintf('deltaV_prm2             = %.3f m/s\n', dv_prm2*1000);




% MAVEN transition maneuvers - PLM2 / PLM3
% ---- SUBSTITUTE atmospheric parameters

% ---- NOTE:
% These are NOT the exact MarsGS / Monte MarsGsDensity parameters.
% They are substitute values derived from the NASA Mars Atmosphere
% metric model for an equivalent exponential density law.
%
% rho(h,t) = rho0 * exp(-(h-h0)/H) * D(t)
%
% ---- SUBSTITUTE atmospheric parameters from NASA Mars Atmosphere Model
% NASA model:
% p = 0.699 * exp(-0.00009*h_m)   [kPa], h_m in meters
% T(h=0) = -31 degC
% rho = p / (0.1921*(T+273.1))    [kg/m^3]
%
% Equivalent exponential-density substitute:
% h0   = 0.0;           % km
% H    = 11.111111;     % km
% rho0 = 1.503e7;       % kg/km^3 %



     % ---- Tuning starter vars
h0 = 0.0;
H = 11.111111;
    % ---- Deterministic density factor parameters from MAVEN MarsGS description
A11yr = 0.35;
T11yr = 4014.1;
AANN  = 0.2;
TANN  = 686.98;

t11yr = datetime(1998,9,1,0,0,0,'TimeZone','UTC');
tANN  = datetime(1998,6,27,12,0,0,'TimeZone','UTC');
     % ---- Actual maneuver dates from MAVEN timeline
t_plm2 = datetime(2014,10,5,21,12,0,'TimeZone','UTC');
t_plm3 = datetime(2014,10,23,23,15,0,'TimeZone','UTC');
     % ---- Time-dependent density scale factors
dt11_plm2 = days(t_plm2 - t11yr);
dtAN_plm2 = days(t_plm2 - tANN);
D_plm2 = 10*( A11yr*sin(2*pi*dt11_plm2/T11yr) ...
            - AANN *sin(2*pi*dtAN_plm2/TANN) );

dt11_plm3 = days(t_plm3 - t11yr);
dtAN_plm3 = days(t_plm3 - tANN);
D_plm3 = 10*( A11yr*sin(2*pi*dt11_plm3/T11yr) ...
            - AANN *sin(2*pi*dtAN_plm3/TANN) );

rho_target_plm2 = 0.05;
rho_target_plm3 = 0.15;

hp_ref_plm3 = 155.0;
rho0 = rho_target_plm3*exp((hp_ref_plm3 - h0)/H)/D_plm3;

hp_plm2 = h0 - H*log(rho_target_plm2/(rho0*D_plm2));
rp_plm2 = R_M + hp_plm2;
ra_plm2 = ra_prm2;
e_plm2 = (ra_plm2 - rp_plm2)/(ra_plm2 + rp_plm2);
a_plm2 = 0.5*(ra_plm2 + rp_plm2);
p_plm2 = a_plm2*(1 - e_plm2^2);
p_prm2 = a_prm2*(1 - e_prm2^2);
va_prm2 = sqrt(mu_M/p_prm2)*(1 - e_prm2);
va_plm2 = sqrt(mu_M/p_plm2)*(1 - e_plm2);
vp_plm2 = sqrt(mu_M/p_plm2)*(1 + e_plm2);
dv_plm2 = va_plm2 - va_prm2;

fprintf('hp_plm2                 = %.3f km\n', hp_plm2);
fprintf('deltaV_plm2             = %.3f m/s\n', dv_plm2*1000);

hp_plm3 = h0 - H*log(rho_target_plm3/(rho0*D_plm3));
rp_plm3 = R_M + hp_plm3;
ra_plm3 = ra_plm2;
e_plm3 = (ra_plm3 - rp_plm3)/(ra_plm3 + rp_plm3);
a_plm3 = 0.5*(ra_plm3 + rp_plm3);
p_plm3 = a_plm3*(1 - e_plm3^2);
va_plm3 = sqrt(mu_M/p_plm3)*(1 - e_plm3);
vp_plm3 = sqrt(mu_M/p_plm3)*(1 + e_plm3);
dv_plm3 = va_plm3 - va_plm2;

fprintf('hp_plm3                 = %.3f km\n', hp_plm3);
fprintf('deltaV_plm3             = %.3f m/s\n', dv_plm3*1000);



%% ============================================================
%% TCM / B-PLANE / MONTE CARLO REVERSE ENGINEERING FOR MAVEN
%% ============================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf('TCM / B-PLANE / MONTE CARLO REVERSE ENGINEERING\n');
fprintf('=============================================================\n');

%% Selected nominal geometry from the previously chosen DEP-ARR pair
[kepE_sel, ~] = uplanet(dep_selected, Body1);
[rrE_sel, vvE_sel] = kep2car(kepE_sel(1), kepE_sel(2), kepE_sel(3), ...
                             kepE_sel(4), kepE_sel(5), kepE_sel(6), mu_s);

[kepM_sel, ~] = uplanet(arr_selected, Body2);
[rrM_sel, vvM_sel] = kep2car(kepM_sel(1), kepM_sel(2), kepM_sel(3), ...
                             kepM_sel(4), kepM_sel(5), kepM_sel(6), mu_s);

tof_sel_sec = (arr_selected - dep_selected) * 86400;

% Nominal center-target transfer (used as reference final arrival)
[A0, P0, E0, ERR0, v1_nom, v2_nom, TPAR0, TH0] = ...
    lambertMR(rrE_sel, rrM_sel, tof_sel_sec, mu_s, 0, 0, 0);

if ERR0 ~= 0
    error('Nominal Lambert solution failed for selected DEP-ARR pair.');
end

v1_nom = v1_nom(:);
v2_nom = v2_nom(:);
rrE_sel = rrE_sel(:);
vvE_sel = vvE_sel(:);
rrM_sel = rrM_sel(:);
vvM_sel = vvM_sel(:);

vInf_dep_nom_vec = v1_nom - vvE_sel;
vInf_arr_nom_vec = v2_nom - vvM_sel;

%% MAVEN biased B-plane target used for launch targeting
BT_bias = 16100;      % km
BR_bias = -19300;     % km

% Build B-plane basis from nominal incoming v-infinity
[S_hat, T_hat, R_hat] = local_bplane_basis(vInf_arr_nom_vec);

% Pseudo B-plane target point at Mars arrival epoch:
% simple patched-conics reverse engineering:
% launch targets a point offset on the plane normal to incoming v_inf
rrM_bias = rrM_sel + BT_bias*T_hat + BR_bias*R_hat;

% Lambert to biased aimpoint (this is the launch-targeted transfer)
[Ab, Pb, Eb, ERRb, v1_bias, v2_bias, TPARb, THb] = ...
    lambertMR(rrE_sel, rrM_bias, tof_sel_sec, mu_s, 0, 0, 0);

if ERRb ~= 0
    error('Biased Lambert solution failed. Try a slightly different arrival epoch or reduce B-plane offset.');
end

v1_bias = v1_bias(:);
v2_bias = v2_bias(:);

vInf_dep_bias_vec = v1_bias - vvE_sel;
vInf_arr_bias_vec = v2_bias - vvM_sel;

dr_bias = rrM_bias - rrM_sel;
BT_check = dot(dr_bias, T_hat);
BR_check = dot(dr_bias, R_hat);

fprintf('B-plane biased launch target\n');
fprintf('BT_target                = %.3f km\n', BT_bias);
fprintf('BR_target                = %.3f km\n', BR_bias);
fprintf('BT_check                 = %.3f km\n', BT_check);
fprintf('BR_check                 = %.3f km\n', BR_check);
fprintf('C3_nominal_center        = %.6f km^2/s^2\n', norm(vInf_dep_nom_vec)^2);
fprintf('C3_biased_launch         = %.6f km^2/s^2\n', norm(vInf_dep_bias_vec)^2);
fprintf('vInf_arr_center          = %.6f km/s\n', norm(vInf_arr_nom_vec));
fprintf('vInf_arr_biased          = %.6f km/s\n', norm(vInf_arr_bias_vec));

%% TCM setup
% TCM-1 and TCM-2 match the mission design paper (L+15d and L+90d).
% TCM-3..5 below are simple cruise placeholders you can move if desired.
tcm_days = [15 90 180 240 300];
tcm_names = {'TCM-1','TCM-2','TCM-3','TCM-4','TCM-5'};

% Project comparison budgets you wanted on screen
budget_project_ms = [20 10 10 10 10];

%% Deterministic TCMs (no injection error)
% These are the burns needed to remove the intentional launch B-plane bias
% and re-target the nominal Mars-center arrival at each correction epoch.
dv_det_ms = NaN(1, numel(tcm_days));

x0_bias_nom = [rrE_sel; v1_bias];

for k = 1:numel(tcm_days)
    tk_sec = tcm_days(k)*86400;
    if tk_sec >= tof_sel_sec
        continue
    end

    xk_nom = local_kepler_universal(x0_bias_nom, tk_sec, mu_s);
    tof_rem_sec = tof_sel_sec - tk_sec;

    try
        [~, ~, ~, ERRk, v1_req_k, ~, ~, ~] = ...
            lambertMR(xk_nom(1:3), rrM_sel, tof_rem_sec, mu_s, 0, 0, 0);

        if ERRk == 0
            dv_det_ms(k) = 1000 * norm(v1_req_k(:) - xk_nom(4:6));
        end
    catch
    end
end

fprintf('\nDeterministic bias-removal TCMs\n');
for k = 1:numel(tcm_days)
    if isfinite(dv_det_ms(k))
        fprintf('%-6s @ L+%6.1f d = %8.3f m/s\n', tcm_names{k}, tcm_days(k), dv_det_ms(k));
    else
        fprintf('%-6s @ L+%6.1f d = %8s\n', tcm_names{k}, tcm_days(k), 'NaN');
    end
end

%% Monte Carlo injection dispersion
% NASA paper quotes ~3sigma of order:
% position ~10 m, velocity ~15 m/s.
% Since the full ULA covariance is not available in this script, we use a
% simple isotropic component model with equal variance per axis.
N_mc = 2000;
rng(42);

sigma_r3s_m  = 10.0;      % total-order reference from paper
sigma_v3s_ms = 15.0;      % total-order reference from paper

sigma_r_comp_km  = (sigma_r3s_m  / 1000) / (3*sqrt(3));
sigma_v_comp_kms = (sigma_v3s_ms / 1000) / (3*sqrt(3));

dv_samples_ms = NaN(N_mc, numel(tcm_days));
BT_arr_samples = NaN(N_mc,1);
BR_arr_samples = NaN(N_mc,1);

for n = 1:N_mc

    dr0 = sigma_r_comp_km  * randn(3,1);
    dv0 = sigma_v_comp_kms * randn(3,1);

    % Off-nominal injected state around the biased launch target
    x0_mc = [rrE_sel + dr0; v1_bias + dv0];

    % Uncorrected arrival dispersion on pseudo B-plane
    x_arr = local_kepler_universal(x0_mc, tof_sel_sec, mu_s);
    dr_arr = x_arr(1:3) - rrM_sel;
    BT_arr_samples(n) = dot(dr_arr, T_hat);
    BR_arr_samples(n) = dot(dr_arr, R_hat);

    % TCM opportunities:
    % each one is treated as "first available correction opportunity"
    % removing both the intentional bias and the sampled launch error
    for k = 1:numel(tcm_days)

        tk_sec = tcm_days(k)*86400;
        if tk_sec >= tof_sel_sec
            continue
        end

        xk = local_kepler_universal(x0_mc, tk_sec, mu_s);
        tof_rem_sec = tof_sel_sec - tk_sec;

        try
            [~, ~, ~, ERRk, v1_req_k, ~, ~, ~] = ...
                lambertMR(xk(1:3), rrM_sel, tof_rem_sec, mu_s, 0, 0, 0);

            if ERRk == 0
                dv_samples_ms(n,k) = 1000 * norm(v1_req_k(:) - xk(4:6));
            end
        catch
        end
    end
end

%% Pseudo B-plane statistics
valid_bp = isfinite(BT_arr_samples) & isfinite(BR_arr_samples);
BTv = BT_arr_samples(valid_bp);
BRv = BR_arr_samples(valid_bp);

BT_mean = mean(BTv);
BR_mean = mean(BRv);
BT_std  = std(BTv);
BR_std  = std(BRv);

% Very simple Monte Carlo impact proxy on pseudo B-plane:
% count arrivals whose projected miss distance is smaller than Mars radius
Pimpact_mc = mean((BTv.^2 + BRv.^2) <= R_M^2);

fprintf('\nPseudo B-plane dispersion at arrival (uncorrected launch bias + injection dispersion)\n');
fprintf('BT_mean                  = %.3f km\n', BT_mean);
fprintf('BR_mean                  = %.3f km\n', BR_mean);
fprintf('BT_std                   = %.3f km\n', BT_std);
fprintf('BR_std                   = %.3f km\n', BR_std);
fprintf('Pseudo P_impact_MC       = %.6e\n', Pimpact_mc);

%% TCM statistics
fprintf('\nTCM Monte Carlo statistics\n');
for k = 1:numel(tcm_days)

    s = local_stats(dv_samples_ms(:,k));

    fprintf('%s @ L+%.1f d\n', tcm_names{k}, tcm_days(k));
    fprintf('  samples               = %d\n', s.N);
    fprintf('  min                   = %.3f m/s\n', s.minv);
    fprintf('  max                   = %.3f m/s\n', s.maxv);
    fprintf('  mean                  = %.3f m/s\n', s.meanv);
    fprintf('  std                   = %.3f m/s\n', s.stdv);
    fprintf('  mean+3sigma           = %.3f m/s\n', s.threesig);
    fprintf('  DV99                  = %.3f m/s\n', s.p99);
    fprintf('  deterministic         = %.3f m/s\n', dv_det_ms(k));
    fprintf('  model budget          = %.3f m/s\n', s.budget);
    fprintf('  project budget        = %.3f m/s\n', budget_project_ms(k));
end

fprintf('\nSuggested quick checks:\n');
fprintf('1) TCM-1 deterministic should come out of order few m/s.\n');
fprintf('2) TCM-1 model budget should be of order ~10-20 m/s if the simple model is consistent.\n');
fprintf('3) Later TCMs depend strongly on the chosen placeholder epochs and missing residual nav covariance.\n');

%% Export figures
outDir = fullfile('figures');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
exportgraphics(fig1, fullfile(outDir, 'launch-window-c3.png'), 'Resolution', 300);
exportgraphics(fig2, fullfile(outDir, 'launch-window-v-infinity.png'), 'Resolution', 300);

%% ============================================================
%% Local functions
%% ============================================================

function [S_hat, T_hat, R_hat] = local_bplane_basis(vinf_vec)
    S_hat = vinf_vec(:) / norm(vinf_vec);
    k_hat = [0;0;1];
    T_hat = cross(S_hat, k_hat);

    if norm(T_hat) < 1e-12
        k_hat = [0;1;0];
        T_hat = cross(S_hat, k_hat);
    end

    T_hat = T_hat / norm(T_hat);
    R_hat = cross(S_hat, T_hat);
    R_hat = R_hat / norm(R_hat);
end

function x = local_kepler_universal(x0, dt, mu)
    r0_vec = x0(1:3);
    v0_vec = x0(4:6);

    r0 = norm(r0_vec);
    v0 = norm(v0_vec);
    vr0 = dot(r0_vec, v0_vec) / r0;

    alpha = 2/r0 - v0^2/mu;

    if abs(alpha) > 1e-12
        chi = sqrt(mu) * abs(alpha) * dt;
    else
        h = cross(r0_vec, v0_vec);
        p = norm(h)^2 / mu;
        s = 0.5 * (pi/2 - atan(3*sqrt(mu/p^3)*dt));
        w = atan(tan(s)^(1/3));
        chi = sqrt(p) * 2 * cos(2*w) / sin(2*w);
    end

    if dt < 0
        chi = -abs(chi);
    else
        chi = abs(chi);
    end

    tol = 1e-11;
    maxIter = 200;

    for iter = 1:maxIter
        z = alpha * chi^2;
        C = local_stumpC(z);
        S = local_stumpS(z);

        F = r0*vr0/sqrt(mu)*chi^2*C + (1 - alpha*r0)*chi^3*S + r0*chi - sqrt(mu)*dt;
        dF = r0*vr0/sqrt(mu)*chi*(1 - z*S) + (1 - alpha*r0)*chi^2*C + r0;

        ratio = F / dF;
        chi = chi - ratio;

        if abs(ratio) < tol
            break
        end
    end

    z = alpha * chi^2;
    C = local_stumpC(z);
    S = local_stumpS(z);

    f = 1 - chi^2/r0 * C;
    g = dt - chi^3*S/sqrt(mu);

    r_vec = f*r0_vec + g*v0_vec;
    r = norm(r_vec);

    fdot = sqrt(mu)/(r*r0) * (alpha*chi^3*S - chi);
    gdot = 1 - chi^2/r * C;

    v_vec = fdot*r0_vec + gdot*v0_vec;

    x = [r_vec; v_vec];
end

function C = local_stumpC(z)
    if z > 1e-8
        sz = sqrt(z);
        C = (1 - cos(sz)) / z;
    elseif z < -1e-8
        sz = sqrt(-z);
        C = (cosh(sz) - 1) / (-z);
    else
        C = 1/2 - z/24 + z^2/720 - z^3/40320;
    end
end

function S = local_stumpS(z)
    if z > 1e-8
        sz = sqrt(z);
        S = (sz - sin(sz)) / (sz^3);
    elseif z < -1e-8
        sz = sqrt(-z);
        S = (sinh(sz) - sz) / (sz^3);
    else
        S = 1/6 - z/120 + z^2/5040 - z^3/362880;
    end
end

function s = local_stats(x)
    x = x(isfinite(x));

    if isempty(x)
        s.N = 0;
        s.minv = NaN;
        s.maxv = NaN;
        s.meanv = NaN;
        s.stdv = NaN;
        s.threesig = NaN;
        s.p99 = NaN;
        s.budget = NaN;
        return
    end

    xs = sort(x(:));
    N = numel(xs);
    idx99 = max(1, ceil(0.99*N));

    s.N = N;
    s.minv = xs(1);
    s.maxv = xs(end);
    s.meanv = mean(xs);
    s.stdv = std(xs);
    s.threesig = s.meanv + 3*s.stdv;
    s.p99 = xs(idx99);
    s.budget = max(s.threesig, s.p99);
end



