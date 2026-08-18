%% maven_standalone_simulation.m
%  =========================================================================
%  MAVEN EPS - Standalone Simulation with real STK data
%  =========================================================================
%  Simulates the full energy cycle using:
%    - P_solar from STK (direct input)
%    - theta(t) from STK for analytical model validation
%    - Eclipse flag for mode override
%    - Attitude schedule for pointing mode
%    - Distance AU, Beta angle for context
%    - Comm windows for operational analysis
%    "Li-Ion battery model (2x60Ah EaglePicher LP 33165, 8S1P)"
%    - Load shedding by subsystem priority
%
%  Prerequisite: run maven_stk_data_loader.m (generates maven_stk_data.mat)
%
%  Inputs: ../data/maven_stk_data.mat
%  Outputs: ../data/maven_sim_results.mat
%  =========================================================================

clear; clc; close all;
fprintf('=== MAVEN EPS - Standalone Simulation ===\n\n');

%% -----------------------------------------------------------------------
%  0. PATHS AND FIGURE STYLE
%  -----------------------------------------------------------------------
this_dir = fileparts(mfilename('fullpath'));
if isempty(this_dir), this_dir = pwd; end
eps_dir  = fileparts(this_dir);                    % subsystems/eps
data_dir = fullfile(eps_dir, 'data');
fig_dir  = fullfile(eps_dir, 'figures');
if ~isfolder(data_dir), mkdir(data_dir); end
if ~isfolder(fig_dir),  mkdir(fig_dir);  end

set(0, 'DefaultFigureColor', 'k');
set(0, 'DefaultAxesColor', 'k');
set(0, 'DefaultAxesXColor', 'w');
set(0, 'DefaultAxesYColor', 'w');
set(0, 'DefaultAxesZColor', 'w');
set(0, 'DefaultTextColor', 'w');
set(0, 'DefaultLineColor', 'w');
set(0, 'DefaultAxesGridColor', [0.4 0.4 0.4]);

%% -----------------------------------------------------------------------
%  1. LOAD STK DATA
%  -----------------------------------------------------------------------
fprintf('[LOAD] Loading maven_stk_data.mat...\n');

if ~isfile(fullfile(data_dir, 'maven_stk_data.mat'))
    error(['maven_stk_data.mat not found in ', data_dir, ...
           '. Run maven_stk_data_loader.m first.']);
end
load(fullfile(data_dir, 'maven_stk_data.mat'), 'maven_data');
fprintf('       %d samples, dt=%d s, duration=%.2f days\n', ...
        maven_data.N, maven_data.dt, maven_data.t_end - maven_data.t_start);

%% -----------------------------------------------------------------------
%  2. BATTERY AND SUBSYSTEM PARAMETERS
%  -----------------------------------------------------------------------
fprintf('\n[PARAMS] Battery and subsystem configuration...\n');

% --- Battery ---
%  Battery sizing: 2 batteries of 2764.8 Wh each (report secondary sizing)
bat.V_nom          = 28;
bat.capacity_Wh    = 5529.6;  % [Wh] 2 x 2764.8 Wh
bat.capacity_Ah    = bat.capacity_Wh / bat.V_nom;  % = 197.5 Ah
bat.SOC_init       = maven_data.cfg.initial_SOC;
bat.SOC_min        = 0.20;
bat.SOC_max        = 1.00;
bat.eta_charge     = 0.95;
bat.eta_discharge  = 0.97;
bat.SOC_bp         = [0.00 0.05 0.10 0.20 0.50 0.80 0.90 0.95 1.00];
bat.OCV_bp         = [24.0 24.8 25.6 26.4 28.0 30.4 31.2 32.0 32.8];
bat.R_int          = 0.016;       % [Ohm] 8 cells x 2 mOhm

fprintf('       Capacity: %.0f Ah (%.0f Wh) @ %.0f V nom\n', ...
        bat.capacity_Ah, bat.capacity_Wh, bat.V_nom);
fprintf('       SOC range: %.0f%% - %.0f%%, init: %.0f%%\n', ...
        bat.SOC_min*100, bat.SOC_max*100, bat.SOC_init*100);

% --- Subsystems (19 subsystems x 9 modes) ---
subsys_names = {
    'C&DH_Primary';       'C&DH_Backup';          'AACS_RWA';
    'AACS_StarTracker';    'AACS_IMU';             'AACS_SunSensor';
    'Telecom_X_SDST';     'Telecom_X_TWTA';       'Telecom_UHF_Electra';
    'Propulsion_Valves';   'Propulsion_Heaters';   'Thermal_Heaters';
    'Thermal_Louvers';     'Power_PCU';            'Power_Shunt';
    'Payload_PFP';         'Payload_IUVS';         'Payload_NGIMS';
    'Payload_APP_Actuator'
};

% =======================================================================
% POWER_DEMAND_TABLE v4 (reconciled with report tab:pw_budget_provided)
% Reconciliation vs v3:
%   - Thermal_Heaters: reconciled with MAVEN TCS literature (~200 W sunlit,
%     ~250 W eclipse; source: 28% of 1135 W from maveninstr)
%   - C&DH_Primary: extended to OBDH + mechanisms (~120 W; 18% of 1135 W)
%   - Power_PCU: includes estimated harness losses ~65 W (~7% of bus load)
%   - AACS_RWA: added ADCS heater +20 W
%   - All other components: unchanged from v3
% =======================================================================

%              FlyY  FlyZ  SunV   HGA  DDip   Ecl  Safe  Slew  Relay
power_demand_table = [
    120  120  120  120  120  100   65  120  120; % C&DH Primary
    0    0    0    0    0    0   15    0    0; % C&DH Backup
    70   70   70   70   75   45   50   70   70; % AACS RWA (+heater)
    12   12   12   12   12    0    0   12   12; % AACS Star Tracker
    18   18   18   18   18   18   18   18   18; % AACS IMU
    2    2    2    2    2    2    5    2    2; % AACS Sun Sensor
    15   15   15   15   15   15   15   15   15; % Telecom X-band SDST
    0    0    0  100    0    0    0    0    0; % Telecom X-band TWTA
    0    0    0    0    0    0    0    0   62; % Telecom UHF Electra
    0    0    0    0    5    0    0    0    0; % Propulsion Valves
    10   10   10   10   15   10   10   10   10; % Propulsion Heaters
    197  197  192  137  197  247  177  192  197; % Thermal Heaters (reconciled)
    3    3    3    3    3    3    3    3    3; % Thermal Louvers
    85   85   85   85   85   85   85   85   85; % Power PCU (incl. harness losses)
    5    5    5    5    5    5    5    5    5; % Power Shunt
    80   80   75    0   85   30    0   75   80; % Payload PFP
    50   50   50    0   55    0    0   50   50; % Payload IUVS
    40   40   30    0   45   30    0   30   40; % Payload NGIMS
    24   24   24   16   24   10    8   24   24; % Payload APP
    ];

n_subsys = size(power_demand_table, 1);
n_modes  = size(power_demand_table, 2);

subsys_priority = [
    1; 1; 2; 3; 2; 2; 3; 5; 5; 4; 3; 3; 4; 1; 1; 6; 6; 6; 5
];

mode_names = {'Fly-Y','Fly-Z','Sun-Vel','HGA_Comm','DeepDip',...
              'Eclipse','SafeMode','Slew','Relay'};

total_per_mode = sum(power_demand_table, 1);
fprintf('\n[DEMAND] Total power per mode:\n');
for m = 1:n_modes
    fprintf('         %d %-14s: %4.0f W\n', m, mode_names{m}, total_per_mode(m));
end

%% -----------------------------------------------------------------------
%  3. MAIN SIMULATION
%  -----------------------------------------------------------------------
fprintf('\n[SIM] Starting simulation...\n');

dt = maven_data.dt;
N  = maven_data.N;

SOC            = zeros(N, 1);
V_bus          = zeros(N, 1);
P_battery      = zeros(N, 1);
P_demand       = zeros(N, 1);
P_allocated    = zeros(N, n_subsys);
P_surplus      = zeros(N, 1);
P_deficit      = zeros(N, 1);
load_shed_flag = false(N, 1);

SOC(1) = bat.SOC_init;
V_bus(1) = interp1(bat.SOC_bp, bat.OCV_bp, SOC(1), 'linear', 'extrap');

for k = 1:N
    P_gen = maven_data.P_solar(k);

    mode_k = maven_data.pointing_mode_eff(k);
    if mode_k < 1 || mode_k > n_modes
        mode_k = 3;
    end

    P_req_subsys = power_demand_table(:, mode_k);
    P_demand(k) = sum(P_req_subsys);

    P_net = P_gen - P_demand(k);

    if P_net < 0 && SOC(k) < 0.30
        [P_req_subsys, shed] = apply_load_shedding(P_req_subsys, ...
            subsys_priority, P_gen, SOC(k));
        P_demand(k) = sum(P_req_subsys);
        P_net = P_gen - P_demand(k);
        load_shed_flag(k) = shed;
    end

    P_allocated(k, :) = P_req_subsys';

    if P_net >= 0
        if SOC(k) >= bat.SOC_max
            P_surplus(k) = P_net;
            P_battery(k) = 0;
        else
            P_battery(k) = -P_net;
            P_surplus(k) = 0;
        end
    else
        if SOC(k) <= bat.SOC_min
            P_battery(k) = 0;
            P_deficit(k) = abs(P_net);
        else
            P_battery(k) = abs(P_net);
            P_deficit(k) = 0;
        end
    end

    if k < N
        if P_battery(k) > 0
            dE = P_battery(k) * dt / 3600;
            SOC(k+1) = SOC(k) - dE / bat.capacity_Wh;
        elseif P_battery(k) < 0
            dE = abs(P_battery(k)) * bat.eta_charge * dt / 3600;
            SOC(k+1) = SOC(k) + dE / bat.capacity_Wh;
        else
            SOC(k+1) = SOC(k);
        end
        SOC(k+1) = max(bat.SOC_min, min(bat.SOC_max, SOC(k+1)));
        V_bus(k+1) = interp1(bat.SOC_bp, bat.OCV_bp, SOC(k+1), 'linear', 'extrap');
    end
end

fprintf('[SIM] Simulation completed.\n');

%% -----------------------------------------------------------------------
%  4. STATISTICS
%  -----------------------------------------------------------------------
fprintf('\n========== SIMULATION STATISTICS ==========\n');
fprintf('Simulation duration:   %.2f days (%.0f h)\n', ...
        (maven_data.t_end - maven_data.t_start), ...
        (maven_data.t_end - maven_data.t_start)*24);
fprintf('Samples:               %d (dt = %d s)\n', N, dt);

fprintf('\n--- Solar Generation ---\n');
fprintf('P_solar mean:          %.1f W\n', mean(maven_data.P_solar));
fprintf('P_solar max:           %.1f W\n', max(maven_data.P_solar));
fprintf('Total solar energy:    %.1f Wh\n', sum(maven_data.P_solar)*dt/3600);

fprintf('\n--- Incidence Angle (theta STK) ---\n');
fprintf('Mean theta (sunlit):   %.1f deg\n', ...
        mean(maven_data.incidence_angle(maven_data.eclipse_flag==0)));
fprintf('Max theta:             %.1f deg\n', max(maven_data.incidence_angle));

fprintf('\n--- Solar Distance ---\n');
fprintf('Mean AU:               %.6f\n', mean(maven_data.distance_AU));
fprintf('Mean solar flux:       %.1f W/m^2\n', mean(maven_data.solar_flux));

fprintf('\n--- Demand ---\n');
fprintf('P_demand mean:         %.1f W\n', mean(P_demand));
fprintf('P_demand max:          %.1f W\n', max(P_demand));
fprintf('Total demand energy:   %.1f Wh\n', sum(P_demand)*dt/3600);

fprintf('\n--- Battery ---\n');
fprintf('SOC initial:           %.1f%%\n', SOC(1)*100);
fprintf('SOC final:             %.1f%%\n', SOC(end)*100);
fprintf('SOC minimum:           %.1f%%\n', min(SOC)*100);
fprintf('SOC maximum:           %.1f%%\n', max(SOC)*100);

fprintf('\n--- Balance ---\n');
E_solar  = sum(maven_data.P_solar) * dt / 3600;
E_demand = sum(P_demand) * dt / 3600;
fprintf('Solar energy:          %.1f Wh\n', E_solar);
fprintf('Demand energy:         %.1f Wh\n', E_demand);
fprintf('Ratio E_sol/E_dem:     %.2f\n', E_solar / E_demand);
fprintf('Total surplus:         %.1f Wh (shunt)\n', sum(P_surplus)*dt/3600);
fprintf('Total deficit:         %.1f Wh (uncovered)\n', sum(P_deficit)*dt/3600);
fprintf('Load shedding events:  %d samples (%.2f%%)\n', ...
        sum(load_shed_flag), 100*sum(load_shed_flag)/N);
fprintf('==============================================\n');

%% -----------------------------------------------------------------------
%  5. SAVE RESULTS
%  -----------------------------------------------------------------------
sim_results.SOC                = SOC;
sim_results.V_bus              = V_bus;
sim_results.P_battery          = P_battery;
sim_results.P_demand           = P_demand;
sim_results.P_allocated        = P_allocated;
sim_results.P_surplus          = P_surplus;
sim_results.P_deficit          = P_deficit;
sim_results.load_shed          = load_shed_flag;
sim_results.bat                = bat;
sim_results.subsys_names       = subsys_names;
sim_results.mode_names         = mode_names;
sim_results.power_demand_table = power_demand_table;
sim_results.subsys_priority    = subsys_priority;

save(fullfile(data_dir, 'maven_sim_results.mat'), 'sim_results', 'maven_data', '-v7.3');
fprintf('\n[SAVE] maven_sim_results.mat saved in %s.\n', data_dir);

%% -----------------------------------------------------------------------
%  6. RESULT PLOTS
%  -----------------------------------------------------------------------
fprintf('\n[PLOT] Generating result plots...\n');

t_hours = maven_data.time_s / 3600;
t_days  = maven_data.time_s / 86400;

% === Plot 1: Overview ===
figure('Position', [50 50 1500 1000]);

subplot(5,1,1);
plot(t_hours, maven_data.P_solar, 'Color', [1 0.6 0], 'LineWidth', 0.5);
ylabel('P_{solar} [W]'); title('MAVEN EPS - Simulation with real STK data');
xlim([0 t_hours(end)]); grid on;

subplot(5,1,2);
plot(t_hours, P_demand, 'b', 'LineWidth', 0.5);
ylabel('P_{demand} [W]');
xlim([0 t_hours(end)]); grid on;

subplot(5,1,3);
plot(t_hours, P_battery, 'Color', [0.8 0 0], 'LineWidth', 0.5);
ylabel('P_{bat} [W]'); yline(0, 'w--');
xlim([0 t_hours(end)]); grid on;
legend('Discharge(+) / Charge(-)');

subplot(5,1,4);
plot(t_hours, SOC*100, 'Color', [0 0.5 0], 'LineWidth', 1);
ylabel('SOC [%]'); yline(bat.SOC_min*100, 'r--', 'DoD Limit');
xlim([0 t_hours(end)]); ylim([0 105]); grid on;

subplot(5,1,5);
plot(t_hours, V_bus, 'Color', [0.5 0 0.5], 'LineWidth', 0.8);
ylabel('V_{bus} [V]'); xlabel('Time [h]');
xlim([0 t_hours(end)]); grid on;

saveas(gcf, fullfile(fig_dir, 'maven-eps-overview.png'));

% === Plot 2: Energy Balance ===
figure('Position', [50 50 1400 600]);

E_sol_cum  = cumsum(maven_data.P_solar) * dt / 3600;
E_dem_cum  = cumsum(P_demand) * dt / 3600;
E_surp_cum = cumsum(P_surplus) * dt / 3600;

plot(t_hours, E_sol_cum, 'Color', [1 0.6 0], 'LineWidth', 1.5); hold on;
plot(t_hours, E_dem_cum, 'b', 'LineWidth', 1.5);
plot(t_hours, E_surp_cum, 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
plot(t_hours, E_sol_cum - E_dem_cum, 'g', 'LineWidth', 1.5);
hold off;
legend('E_{solar}', 'E_{demand}', 'E_{surplus}', 'E_{net}', 'Location', 'northwest');
xlabel('Time [h]'); ylabel('Energy [Wh]');
title('MAVEN EPS - Cumulative Energy Balance');
grid on;
saveas(gcf, fullfile(fig_dir, 'maven-eps-energy-balance.png'));

% === Plot 3: Subsystem Power Breakdown ===
figure('Position', [50 50 1400 700]);

cat_idx = {[1 2], [3 4 5 6], [7 8 9], [10 11], [12 13], [14 15], [16 17 18 19]};
cat_names = {'C&DH', 'AACS', 'Telecom', 'Propulsion', 'Thermal', 'Power', 'Payload'};
n_cat = length(cat_idx);

P_cat = zeros(N, n_cat);
for c = 1:n_cat
    P_cat(:, c) = sum(P_allocated(:, cat_idx{c}), 2);
end

area(t_hours, P_cat);
legend(cat_names, 'Location', 'eastoutside');
xlabel('Time [h]'); ylabel('Power [W]');
title('MAVEN EPS - Power by Category');
xlim([0 t_hours(end)]); grid on;
saveas(gcf, fullfile(fig_dir, 'maven-eps-subsystem-power.png'));

% === Plot 4: 3-Orbit Zoom ===
figure('Position', [50 50 1500 900]);

ecl_start_idx = find(maven_data.eclipse_flag == 2, 1, 'first');
if ~isempty(ecl_start_idx)
    zoom_center = ecl_start_idx;
else
    zoom_center = round(N/2);
end
zoom_span = round(3 * maven_data.cfg.orbit_period / dt);
zoom_idx = max(1, zoom_center - zoom_span/2) : min(N, zoom_center + zoom_span/2);
t_zoom = t_hours(zoom_idx);

subplot(4,1,1);
plot(t_zoom, maven_data.P_solar(zoom_idx), 'Color', [1 0.6 0], 'LineWidth', 1);
ylabel('P_{solar} [W]'); title('MAVEN EPS - 3-Orbit Zoom');
xlim([t_zoom(1) t_zoom(end)]); grid on;

subplot(4,1,2);
plot(t_zoom, P_demand(zoom_idx), 'b', 'LineWidth', 1); hold on;
plot(t_zoom, maven_data.P_solar(zoom_idx), 'Color', [1 0.6 0 0.5], 'LineWidth', 0.5);
ylabel('Power [W]'); legend('Demand', 'Solar');
xlim([t_zoom(1) t_zoom(end)]); grid on;

subplot(4,1,3);
plot(t_zoom, SOC(zoom_idx)*100, 'Color', [0 0.5 0], 'LineWidth', 1.5);
ylabel('SOC [%]');
xlim([t_zoom(1) t_zoom(end)]); grid on;

subplot(4,1,4);
plot(t_zoom, maven_data.pointing_mode_eff(zoom_idx), 'r-', 'LineWidth', 1);
ylabel('Mode'); yticks(1:9); yticklabels(mode_names);
xlabel('Time [h]');
xlim([t_zoom(1) t_zoom(end)]); grid on;

saveas(gcf, fullfile(fig_dir, 'maven-eps-3-orbit-zoom.png'));

% === Plot 5: Theta + AU + Beta context ===
figure('Position', [50 50 1500 700]);

subplot(3,1,1);
plot(t_hours, maven_data.incidence_angle, 'Color', [0.8 0.3 0.1], 'LineWidth', 0.5);
ylabel('\theta [deg]'); title('MAVEN EPS - Orbital Context');
xlim([0 t_hours(end)]); grid on;

subplot(3,1,2);
plot(t_hours, maven_data.distance_AU, 'Color', [0.6 0.2 0.8], 'LineWidth', 1);
ylabel('r_{AU} [AU]');
xlim([0 t_hours(end)]); grid on;

subplot(3,1,3);
plot(t_hours, maven_data.beta_angle, 'Color', [0 0.5 0.8], 'LineWidth', 1);
ylabel('\beta [deg]'); xlabel('Time [h]');
xlim([0 t_hours(end)]); grid on;

saveas(gcf, fullfile(fig_dir, 'maven-eps-orbital-context.png'));

fprintf('[PLOT] All plots saved.\n');
fprintf('\n=== Simulation completed ===\n');


%% =======================================================================
%  LOAD SHEDDING FUNCTION
%  =======================================================================
function [P_req, shed] = apply_load_shedding(P_req, priority, P_avail, SOC)
    shed = false;
    max_prio = max(priority);

    for prio = max_prio:-1:1
        if sum(P_req) <= P_avail
            break;
        end
        idx = find(priority == prio);
        for j = 1:length(idx)
            if sum(P_req) <= P_avail, break; end
            if SOC < 0.25
                P_req(idx(j)) = P_req(idx(j)) * 0.3;
                shed = true;
            elseif SOC < 0.30
                P_req(idx(j)) = P_req(idx(j)) * 0.5;
                shed = true;
            end
        end
    end
end
