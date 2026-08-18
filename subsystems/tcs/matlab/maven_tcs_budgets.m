%% maven_tcs_budgets.m
%  =========================================================================
%  MAVEN TCS - Subsystem budgets (report Section 2.6)
%  =========================================================================
%  Builds the three TCS subsystem budgets (power, mass, data) from:
%    - ../data/tcs-a-workspace.mat : heater powers from
%      maven_tcs_units_controlled.m
%    - passive/static components   : literature + heritage values
%  Output: three CSV tables matching the report budget tables.
%
%  POWER BUDGET (cold case, peak)
%    Active components: Kapton heaters (Q_htr) + thermostats (one per zone).
%    DMM: 5% heaters, 10% thermostats. Subsystem margin: 20% on DMM subtotal.
%
%  MASS BUDGET
%    Passive: MLI blankets, radiator panels, thermo-optical paint.
%    Active:  Kapton heater strips, thermostat controllers, thermal straps.
%    DMM: 20% MLI/radiator/paint, 5% heater strips, 10% thermostats/straps.
%    Subsystem margin: 20% on the raw subtotal (report convention).
%
%  DATA BUDGET
%    Housekeeping: temperature sensors + heater status flags.
%    Sampling f_s = 1/60 Hz, 16 bit/channel, T_orb = 4.6 h (report).
%    Memory margin: 50%.
%
%  Eclipse fraction: f_ecl = 10.74% of the 11-23 Feb 2015 simulation window
%  (eclipse flag in the EPS standalone time-series), used for the
%  orbit-averaged heater power.
%
%  Inputs : ../data/tcs-a-workspace.mat
%  Outputs: ../data/tcs-b-power.csv , ../data/tcs-b-mass.csv ,
%           ../data/tcs-b-data.csv
%  =========================================================================

clear; close all;

%% -------------------------------------------------------------------------
%  0. PATHS
%  -------------------------------------------------------------------------
this_dir = fileparts(mfilename('fullpath'));
if isempty(this_dir), this_dir = pwd; end
tcs_dir  = fileparts(this_dir);                     % subsystems/tcs
data_dir = fullfile(tcs_dir, 'data');

%% -------------------------------------------------------------------------
%  1. LOAD SCRIPT A RESULTS
%  -------------------------------------------------------------------------
fprintf('Loading tcs-a-workspace.mat...\n');
load(fullfile(data_dir, 'tcs-a-workspace.mat'));   % Q_htr_total, Q_htr, units

f_ecl   = 0.1074;   % eclipse fraction of the 11-23 Feb 2015 window (1,872
                    % of 17,426 samples with eclipse flag set in the EPS
                    % standalone time-series)
T_orb_h = 4.6;     % [h] science orbit period (report data budget)

fprintf('  Q_htr_total (cold case peak) = %.2f W\n', Q_htr_total);
fprintf('  Eclipse duty cycle           = %.1f %%\n', f_ecl * 100);

%% -------------------------------------------------------------------------
%  2. POWER BUDGET
%  -------------------------------------------------------------------------
fprintf('\n=== Power Budget (cold case, peak) ===\n');

active_idx = find(Q_htr > 0);
n_heaters  = length(active_idx);

DMM_htr    = 0.05;        % 5%  heater strips
DMM_therm  = 0.10;        % 10% thermostat controllers
n_therm    = n_heaters;   % one thermostat per heater zone
P_therm_ea = 0.50;        % [W/unit]
margin_ss  = 0.20;        % 20% subsystem margin

pw_names = {};
pw_qty   = {};
pw_Punit = [];
pw_Ptot  = [];
pw_DMM   = [];
pw_wDMM  = [];

for k = 1:n_heaters
    i = active_idx(k);
    pw_names{end+1} = sprintf('Kapton heater strips (%s)', units.Unit(i));
    pw_qty{end+1}   = '1';
    pw_Punit(end+1) = Q_htr(i);
    pw_Ptot(end+1)  = Q_htr(i);
    pw_DMM(end+1)   = DMM_htr * 100;
    pw_wDMM(end+1)  = Q_htr(i) * (1 + DMM_htr);
end

pw_names{end+1} = 'Thermostat controllers (all zones)';
pw_qty{end+1}   = num2str(n_therm);
pw_Punit(end+1) = P_therm_ea;
pw_Ptot(end+1)  = n_therm * P_therm_ea;
pw_DMM(end+1)   = DMM_therm * 100;
pw_wDMM(end+1)  = n_therm * P_therm_ea * (1 + DMM_therm);

subtotal_P    = sum(pw_Ptot);
subtotal_wDMM = sum(pw_wDMM);
margin_P      = subtotal_wDMM * margin_ss;
total_P       = subtotal_wDMM + margin_P;

P_avg = Q_htr_total * f_ecl;   % [W] orbit-averaged heater power

fprintf('  Subtotal (no margin): %.2f W\n', subtotal_P);
fprintf('  Subtotal (w/ DMM):    %.2f W\n', subtotal_wDMM);
fprintf('  Subsystem margin:     %.2f W\n', margin_P);
fprintf('  TOTAL TCS power:      %.2f W\n', total_P);
fprintf('  Orbit-averaged (f_ecl=%.1f%%): %.2f W\n', f_ecl * 100, P_avg);

T_power = table( ...
    pw_names(:), pw_qty(:), ...
    cellstr(num2str(pw_Punit(:), '%.2f')), ...
    cellstr(num2str(pw_Ptot(:), '%.2f')), ...
    cellstr(num2str(pw_DMM(:), '%.0f%%')), ...
    cellstr(num2str(pw_wDMM(:), '%.2f')), ...
    'VariableNames', {'Component','Qty','P_unit_W','P_tot_W','DMM_pct','P_wDMM_W'});
summary_rows = table( ...
    {'Subtotal'; 'Subsystem margin (20%)'; 'Total TCS power'}, ...
    {'---'; '---'; '---'}, ...
    {'---'; '---'; '---'}, ...
    {sprintf('%.2f', subtotal_P); '---'; '---'}, ...
    {'---'; '---'; '---'}, ...
    {sprintf('%.2f', subtotal_wDMM); sprintf('%.2f', margin_P); sprintf('%.2f', total_P)}, ...
    'VariableNames', T_power.Properties.VariableNames);
T_power_full = [T_power; summary_rows];
writetable(T_power_full, fullfile(data_dir, 'tcs-b-power.csv'));
fprintf('Written: tcs-b-power.csv\n');

%% -------------------------------------------------------------------------
%  3. MASS BUDGET
%  -------------------------------------------------------------------------
fprintf('\n=== Mass Budget ===\n');

DMM_MLI    = 0.20;   % 20%
DMM_rad    = 0.20;
DMM_paint  = 0.20;
DMM_strip  = 0.05;
DMM_therm2 = 0.10;
DMM_strap  = 0.10;

m_MLI_ea   = 0.5 * 5.4;   % [kg] rho ~0.5 kg/m2 on ~5.4 m2 of blanketed bus
m_rad_ea   = 2.500;       % [kg] Al honeycomb panel (~100 W/m2 rejection)
m_paint_ea = 0.025;       % [kg] OSR coating on radiators
m_strip_ea = 0.050;       % [kg]
m_therm_ea = 0.150;       % [kg]
m_strap_ea = 0.100;       % [kg]
n_straps   = 2;

mass_items = {
    'MLI blankets (bus + tanks)',      1, m_MLI_ea,   DMM_MLI,   'rho ~0.5 kg/m2';
    'Passive radiator panels',         1, m_rad_ea,   DMM_rad,   'Al honeycomb, ~100 W/m2';
    'Thermo-optical paint (radiators)', 1, m_paint_ea, DMM_paint, 'OSR coating'};
for k = 1:n_heaters
    i = active_idx(k);
    mass_items(end+1, :) = {sprintf('Kapton heater strips (%s)', units.Unit(i)), ...
                            1, m_strip_ea, DMM_strip, '5 W/cm2'};
end
mass_items(end+1, :) = {'Thermostat controllers', n_therm, m_therm_ea, DMM_therm2, 'Heritage'};
mass_items(end+1, :) = {'Thermal straps (battery zone)', n_straps, m_strap_ea, DMM_strap, 'Cu braid'};

n_items  = size(mass_items, 1);
ms_names = cell(n_items, 1);
ms_qty   = zeros(n_items, 1);
ms_munit = zeros(n_items, 1);
ms_mtot  = zeros(n_items, 1);
ms_DMM   = zeros(n_items, 1);
ms_mwDMM = zeros(n_items, 1);
ms_remark = cell(n_items, 1);
for j = 1:n_items
    ms_names{j}  = mass_items{j, 1};
    ms_qty(j)    = mass_items{j, 2};
    ms_munit(j)  = mass_items{j, 3};
    ms_mtot(j)   = ms_qty(j) * ms_munit(j);
    ms_DMM(j)    = mass_items{j, 4} * 100;
    ms_mwDMM(j)  = ms_mtot(j) * (1 + mass_items{j, 4});
    ms_remark{j} = mass_items{j, 5};
end

subtotal_m     = sum(ms_mtot);
subtotal_mwDMM = sum(ms_mwDMM);
margin_m       = subtotal_m * margin_ss;          % on raw subtotal (report)
total_m        = subtotal_m + margin_m;

fprintf('  Subtotal (no margin): %.3f kg\n', subtotal_m);
fprintf('  Subtotal (w/ DMM):    %.3f kg\n', subtotal_mwDMM);
fprintf('  Subsystem margin:     %.3f kg\n', margin_m);
fprintf('  TOTAL TCS mass:       %.3f kg\n', total_m);

T_mass = table(ms_names, cellstr(num2str(ms_qty)), ms_munit, ms_mtot, ms_DMM, ms_mwDMM, ms_remark, ...
    'VariableNames', {'Component','Qty','m_unit_kg','m_tot_kg','DMM_pct','m_wDMM_kg','Remark'});
ms_summary = table( ...
    {'Subtotal'; 'Subsystem margin (20%)'; 'Total TCS mass'}, ...
    {'---'; '---'; '---'}, ...
    [NaN; NaN; NaN], ...
    [subtotal_m; margin_m; total_m], ...
    [NaN; NaN; NaN], ...
    [NaN; NaN; NaN], ...
    {'---'; '---'; '---'}, ...
    'VariableNames', T_mass.Properties.VariableNames);
T_mass_full = [T_mass; ms_summary];
writetable(T_mass_full, fullfile(data_dir, 'tcs-b-mass.csv'));
fprintf('Written: tcs-b-mass.csv\n');

%% -------------------------------------------------------------------------
%  4. DATA BUDGET
%  -------------------------------------------------------------------------
fprintf('\n=== Data Budget ===\n');

Delta_t   = 60;      % [s] sampling interval (1/60 Hz)
T_orb_s   = T_orb_h * 3600;
bits_ch   = 16;      % [bit] per sample

N_samp    = T_orb_s / Delta_t;              % samples/orbit/channel
V_ch_kbit = N_samp * bits_ch / 1e3;         % kbit/orbit/channel

ch_names = {'Unit temperature sensors (1 per unit)';
            'Bus panel temperatures (4 external faces)';
            'SA boomlet MAG sensor temperatures';
            'Heater ON/OFF status flags (active zones)'};
n_ch = [n_units; 4; 2; n_heaters];

n_total_ch  = sum(n_ch);
V_groups    = n_ch .* V_ch_kbit;
V_subtotal  = sum(V_groups);
margin_data = 0.50;                         % 50% memory margin
V_margin    = V_subtotal * margin_data;
V_total     = V_subtotal + V_margin;

fprintf('  Sampling: f_s=1/%d Hz, %d bit/sample\n', Delta_t, bits_ch);
fprintf('  N_samp = %d samples/orbit/channel\n', round(N_samp));
fprintf('  V_ch   = %.2f kbit/orbit/channel\n', V_ch_kbit);
fprintf('  Channels: %d temperature + %d heater status = %d total\n', ...
        n_units + 4 + 2, n_heaters, n_total_ch);
fprintf('  Subtotal: %.2f kbit/orbit | +50%% margin: %.2f | Total: %.2f kbit/orbit\n', ...
        V_subtotal, V_margin, V_total);

T_data = table( ...
    [ch_names; {'Subtotal'; 'Memory margin (50%)'; 'Total TCS data'}], ...
    [n_ch; n_total_ch; n_total_ch; n_total_ch], ...
    [N_samp; N_samp; N_samp; N_samp; N_samp; N_samp; N_samp], ...
    [bits_ch; bits_ch; bits_ch; bits_ch; bits_ch; bits_ch; bits_ch], ...
    [V_groups; V_subtotal; V_margin; V_total], ...
    'VariableNames', {'Channel','N_channels','N_samp_orbit', ...
                      'bits_per_sample','V_kbit_orbit'});
writetable(T_data, fullfile(data_dir, 'tcs-b-data.csv'));
fprintf('Written: tcs-b-data.csv\n');

fprintf('\n=== Script B complete. Tables ready for the report Section 2.6 ===\n');