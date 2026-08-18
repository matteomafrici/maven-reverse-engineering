%% maven_postprocessing.m
%  =========================================================================
%  MAVEN EPS - Post-Processing
%  =========================================================================
%  Detailed analysis of the simulation results:
%    - Per-orbit energy balance
%    - SOC statistics per mode
%    - Power per pointing mode
%    - P_solar STK vs analytical model validation
%    - Theta, AU, beta analysis
%    - Communication window analysis
%    - CSV export and summary tables
%
%  Prerequisite: run maven_standalone_simulation.m
%  Inputs: ../data/maven_sim_results.mat
%  Outputs: ../data/maven-eps-*.csv , ../figures/maven-eps-*.png
%  =========================================================================

clear; clc; close all;
fprintf('=== MAVEN EPS - Post-Processing ===\n\n');

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
%  1. LOAD RESULTS
%  -----------------------------------------------------------------------
if ~isfile(fullfile(data_dir, 'maven_sim_results.mat'))
    error(['maven_sim_results.mat not found in ', data_dir, ...
           '. Run maven_standalone_simulation.m first.']);
end
load(fullfile(data_dir, 'maven_sim_results.mat'), 'sim_results', 'maven_data');

dt = maven_data.dt;
N  = maven_data.N;
t_hours = maven_data.time_s / 3600;
t_days  = maven_data.time_s / 86400;

fprintf('[LOAD] Results loaded: %d samples, %.2f days\n', N, t_days(end));

%% -----------------------------------------------------------------------
%  2. PER-ORBIT ANALYSIS
%  -----------------------------------------------------------------------
fprintf('\n[ORBIT] Per-orbit analysis...\n');

orbit_period_samples = round(maven_data.cfg.orbit_period / dt);
n_orbits = floor(N / orbit_period_samples);

orbit_stats = struct();
orbit_stats.E_solar   = zeros(n_orbits, 1);
orbit_stats.E_demand  = zeros(n_orbits, 1);
orbit_stats.SOC_min   = zeros(n_orbits, 1);
orbit_stats.SOC_max   = zeros(n_orbits, 1);
orbit_stats.SOC_mean  = zeros(n_orbits, 1);
orbit_stats.eclipse_s = zeros(n_orbits, 1);
orbit_stats.theta_mean= zeros(n_orbits, 1);

for orb = 1:n_orbits
    idx = ((orb-1)*orbit_period_samples + 1) : min(orb*orbit_period_samples, N);
    orbit_stats.E_solar(orb)   = sum(maven_data.P_solar(idx)) * dt / 3600;
    orbit_stats.E_demand(orb)  = sum(sim_results.P_demand(idx)) * dt / 3600;
    orbit_stats.SOC_min(orb)   = min(sim_results.SOC(idx));
    orbit_stats.SOC_max(orb)   = max(sim_results.SOC(idx));
    orbit_stats.SOC_mean(orb)  = mean(sim_results.SOC(idx));
    orbit_stats.eclipse_s(orb) = sum(maven_data.eclipse_flag(idx) == 2) * dt;
    orbit_stats.theta_mean(orb)= mean(maven_data.incidence_angle(idx));
end

fprintf('       %d orbits analyzed\n', n_orbits);
fprintf('       E_solar per orbit: min=%.0f Wh, max=%.0f Wh, mean=%.0f Wh\n', ...
        min(orbit_stats.E_solar), max(orbit_stats.E_solar), mean(orbit_stats.E_solar));
fprintf('       Eclipse per orbit: min=%.0f s, max=%.0f s\n', ...
        min(orbit_stats.eclipse_s), max(orbit_stats.eclipse_s));

%% -----------------------------------------------------------------------
%  3. POWER PER POINTING MODE
%  -----------------------------------------------------------------------
fprintf('\n[MODE] Power per mode analysis...\n');

mode_names = sim_results.mode_names;
n_modes = length(mode_names);

fprintf('\n       %-14s  %8s  %8s  %8s  %8s  %8s\n', ...
        'Mode', 'N_samp', 'P_sol_m', 'P_dem_m', 'SOC_m', 'Theta_m');
fprintf('       %s\n', repmat('-', 1, 65));

for m = 1:n_modes
    idx = (maven_data.pointing_mode_eff == m);
    n_m = sum(idx);
    if n_m == 0, continue; end
    fprintf('       %-14s  %8d  %8.1f  %8.1f  %7.1f%%  %7.1f deg\n', ...
            mode_names{m}, n_m, ...
            mean(maven_data.P_solar(idx)), ...
            mean(sim_results.P_demand(idx)), ...
            mean(sim_results.SOC(idx))*100, ...
            mean(maven_data.incidence_angle(idx)));
end

%% -----------------------------------------------------------------------
%  4. P_SOLAR VALIDATION: STK vs ANALYTICAL MODEL
%  -----------------------------------------------------------------------
fprintf('\n[VALID] Validating P_solar STK vs Model...\n');

idx_sun = (maven_data.eclipse_flag == 0) & (maven_data.P_solar > 10);
P_stk = maven_data.P_solar(idx_sun);
P_mod = maven_data.P_solar_model(idx_sun);

err_abs = P_stk - P_mod;
err_rel = err_abs ./ P_stk * 100;

fprintf('       Sunlit samples analyzed: %d\n', sum(idx_sun));
fprintf('       Absolute error: mean=%.1f W, std=%.1f W\n', mean(err_abs), std(err_abs));
fprintf('       Relative error: mean=%.1f%%, std=%.1f%%\n', mean(err_rel), std(err_rel));
fprintf('       Correlation: R^2 = %.4f\n', corr(P_stk, P_mod)^2);

% Validation plot
figure('Position', [50 50 1200 500]);
subplot(1,2,1);
scatter(P_stk, P_mod, 2, 'filled', 'MarkerFaceAlpha', 0.3);
hold on; plot([0 2500], [0 2500], 'r--', 'LineWidth', 1.5);
xlabel('P_{solar} STK [W]'); ylabel('P_{solar} Model [W]');
title('Scatter: STK vs Analytical Model');
axis equal; grid on; xlim([0 2500]); ylim([0 2500]);

subplot(1,2,2);
histogram(err_rel, 50, 'FaceColor', [0.2 0.6 0.8]);
xlabel('Relative error [%]'); ylabel('Count');
title(sprintf('Error distribution (mean=%.1f%%)', mean(err_rel)));
grid on;

saveas(gcf, fullfile(fig_dir, 'maven-eps-stk-model-validation.png'));

%% -----------------------------------------------------------------------
%  5. ORBITAL CONTEXT ANALYSIS
%  -----------------------------------------------------------------------
fprintf('\n[CONTEXT] Orbital context analysis...\n');

fprintf('       AU distance: %.6f - %.6f (delta=%.6f)\n', ...
        min(maven_data.distance_AU), max(maven_data.distance_AU), ...
        max(maven_data.distance_AU) - min(maven_data.distance_AU));
fprintf('       Beta angle: %.2f to %.2f deg\n', ...
        min(maven_data.beta_angle), max(maven_data.beta_angle));
fprintf('       Altitude: %.0f - %.0f km\n', ...
        min(maven_data.altitude_km), max(maven_data.altitude_km));

%% -----------------------------------------------------------------------
%  6. COMMUNICATION ANALYSIS
%  -----------------------------------------------------------------------
fprintf('\n[COMM] Communication window analysis...\n');

n_dsn = sum(maven_data.comm_flag == 1);
n_msl = sum(maven_data.comm_flag == 2);
n_nocomm = sum(maven_data.comm_flag == 0);

fprintf('       DSN contact:   %d samples (%.1f%% of time)\n', n_dsn, 100*n_dsn/N);
fprintf('       MSL relay:     %d samples (%.1f%% of time)\n', n_msl, 100*n_msl/N);
fprintf('       No comm:       %d samples (%.1f%% of time)\n', n_nocomm, 100*n_nocomm/N);

if n_dsn > 0
    fprintf('       Mean SOC during DSN: %.1f%%\n', ...
            mean(sim_results.SOC(maven_data.comm_flag==1))*100);
end

%% -----------------------------------------------------------------------
%  7. POST-PROCESSING PLOTS
%  -----------------------------------------------------------------------
fprintf('\n[PLOT] Generating post-processing plots...\n');

% === Power by Mode ===
figure('Position', [50 50 1400 600]);
mode_power = zeros(n_modes, 2);
mode_count = zeros(n_modes, 1);
for m = 1:n_modes
    idx = (maven_data.pointing_mode_eff == m);
    if sum(idx) > 0
        mode_power(m, 1) = mean(maven_data.P_solar(idx));
        mode_power(m, 2) = mean(sim_results.P_demand(idx));
        mode_count(m) = sum(idx);
    end
end

active_modes = mode_count > 0;
bar_data = mode_power(active_modes, :);
bar(bar_data);
set(gca, 'XTickLabel', mode_names(active_modes));
legend('P_{solar} mean', 'P_{demand} mean');
ylabel('Power [W]'); title('MAVEN EPS - Mean Power per Mode');
grid on;
saveas(gcf, fullfile(fig_dir, 'maven-eps-power-by-mode.png'));

% === SOC Statistics ===
figure('Position', [50 50 1200 500]);
orb_x = 1:n_orbits;
fill([orb_x fliplr(orb_x)], ...
     [orbit_stats.SOC_min'*100 fliplr(orbit_stats.SOC_max'*100)], ...
     [0.8 0.9 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.5); hold on;
plot(orb_x, orbit_stats.SOC_mean*100, 'Color', [0 0.5 0], 'LineWidth', 1.5);
xlabel('Orbit #'); ylabel('SOC [%]');
title('MAVEN EPS - SOC per Orbit (min/mean/max)');
legend('SOC range', 'SOC mean');
grid on;
saveas(gcf, fullfile(fig_dir, 'maven-eps-soc-stats.png'));

% === Theta per orbit ===
figure('Position', [50 50 1200 400]);
bar(orb_x, orbit_stats.theta_mean, 'FaceColor', [0.8 0.3 0.1]);
xlabel('Orbit #'); ylabel('Mean \theta [deg]');
title('MAVEN EPS - Mean Incidence Angle per Orbit');
grid on;
saveas(gcf, fullfile(fig_dir, 'maven-eps-theta-per-orbit.png'));

%% -----------------------------------------------------------------------
%  8. CSV EXPORT
%  -----------------------------------------------------------------------
fprintf('\n[EXPORT] Exporting CSVs...\n');

% --- 1. Full timeseries ---
T = table(maven_data.time_s, maven_data.P_solar, maven_data.P_solar_model, ...
          sim_results.P_demand, sim_results.P_battery, sim_results.SOC*100, ...
          sim_results.V_bus, sim_results.P_surplus, sim_results.P_deficit, ...
          double(sim_results.load_shed), ...
          maven_data.eclipse_flag, ...
          maven_data.pointing_mode_eff, maven_data.incidence_angle, ...
          maven_data.distance_AU, maven_data.beta_angle, ...
          maven_data.altitude_km, maven_data.comm_flag, ...
          'VariableNames', {'Time_s', 'P_solar_STK_W', 'P_solar_model_W', ...
          'P_demand_W', 'P_battery_W', 'SOC_pct', 'V_bus_V', ...
          'P_surplus_W', 'P_deficit_W', 'LoadShed', ...
          'Eclipse_flag', 'Pointing_mode', 'Theta_deg', ...
          'Distance_AU', 'Beta_deg', 'Altitude_km', 'Comm_flag'});

writetable(T, fullfile(data_dir, 'maven-eps-timeseries.csv'));
fprintf('       maven-eps-timeseries.csv        (%d rows)\n', height(T));

% --- 2. Per-orbit summary ---
T_orb = table((1:n_orbits)', orbit_stats.E_solar, orbit_stats.E_demand, ...
              orbit_stats.SOC_min*100, orbit_stats.SOC_max*100, ...
              orbit_stats.SOC_mean*100, orbit_stats.eclipse_s, ...
              orbit_stats.theta_mean, ...
              orbit_stats.E_solar ./ max(orbit_stats.E_demand, 1), ...
              'VariableNames', {'Orbit', 'E_solar_Wh', 'E_demand_Wh', ...
              'SOC_min_pct', 'SOC_max_pct', 'SOC_mean_pct', ...
              'Eclipse_s', 'Theta_mean_deg', 'Energy_ratio'});

writetable(T_orb, fullfile(data_dir, 'maven-eps-orbit-summary.csv'));
fprintf('       maven-eps-orbit-summary.csv     (%d orbits)\n', height(T_orb));

% --- 3. Mode analysis ---
mode_analysis = cell(n_modes, 7);
for m = 1:n_modes
    idx_m = (maven_data.pointing_mode_eff == m);
    n_m = sum(idx_m);
    if n_m > 0
        mode_analysis(m,:) = {mode_names{m}, n_m, n_m*dt/3600, ...
            mean(maven_data.P_solar(idx_m)), ...
            mean(sim_results.P_demand(idx_m)), ...
            mean(sim_results.SOC(idx_m))*100, ...
            mean(maven_data.incidence_angle(idx_m))};
    else
        mode_analysis(m,:) = {mode_names{m}, 0, 0, 0, 0, 0, 0};
    end
end
T_mode = cell2table(mode_analysis, 'VariableNames', ...
    {'Mode', 'N_samples', 'Duration_h', 'P_solar_mean_W', ...
     'P_demand_mean_W', 'SOC_mean_pct', 'Theta_mean_deg'});
writetable(T_mode, fullfile(data_dir, 'maven-eps-mode-analysis.csv'));
fprintf('       maven-eps-mode-analysis.csv     (%d modes)\n', height(T_mode));

% --- 4. STK vs Model validation ---
T_valid = table( ...
    {'Mean_abs_error_W'; 'Std_abs_error_W'; 'Mean_rel_error_pct'; ...
     'Std_rel_error_pct'; 'R_squared'; 'N_sunlit_samples'}, ...
    [mean(err_abs); std(err_abs); mean(err_rel); std(err_rel); ...
     corr(P_stk, P_mod)^2; sum(idx_sun)], ...
    'VariableNames', {'Metric', 'Value'});
writetable(T_valid, fullfile(data_dir, 'maven-eps-validation.csv'));
fprintf('       maven-eps-validation.csv        (%d metrics)\n', height(T_valid));

% --- 5. Allocated power per subsystem ---
subsys_clean = cellfun(@(s) strrep(s, ' ', '_'), ...
    sim_results.subsys_names, 'UniformOutput', false);
T_subsys = array2table(sim_results.P_allocated, 'VariableNames', subsys_clean);
T_subsys = [table(maven_data.time_s, 'VariableNames', {'Time_s'})  T_subsys];
writetable(T_subsys, fullfile(data_dir, 'maven-eps-subsys-power.csv'));
fprintf('       maven-eps-subsys-power.csv      (%d rows)\n', height(T_subsys));

% --- 6. Global summary statistics ---
E_solar_tot  = sum(maven_data.P_solar) * dt / 3600;
E_demand_tot = sum(sim_results.P_demand) * dt / 3600;
E_surplus_tot= sum(sim_results.P_surplus) * dt / 3600;
E_deficit_tot= sum(sim_results.P_deficit) * dt / 3600;

stat_names = {'Duration_days'; 'Samples'; 'dt_s'; ...
    'P_solar_mean_W'; 'P_solar_max_W'; 'E_solar_tot_Wh'; ...
    'P_demand_mean_W'; 'P_demand_max_W'; 'E_demand_tot_Wh'; ...
    'SOC_init_pct'; 'SOC_final_pct'; 'SOC_min_pct'; 'SOC_max_pct'; ...
    'E_surplus_tot_Wh'; 'E_deficit_tot_Wh'; 'LoadShed_events'; ...
    'Ratio_Esol_Edem'; ...
    'AU_min'; 'AU_max'; 'Beta_min_deg'; 'Beta_max_deg'; ...
    'DSN_contact_pct'; 'MSL_relay_pct'; ...
    'Validation_R2'; 'Validation_mean_err_pct'};
stat_vals = [ ...
    t_days(end); N; dt; ...
    mean(maven_data.P_solar); max(maven_data.P_solar); E_solar_tot; ...
    mean(sim_results.P_demand); max(sim_results.P_demand); E_demand_tot; ...
    sim_results.SOC(1)*100; sim_results.SOC(end)*100; ...
    min(sim_results.SOC)*100; max(sim_results.SOC)*100; ...
    E_surplus_tot; E_deficit_tot; sum(sim_results.load_shed); ...
    E_solar_tot / E_demand_tot; ...
    min(maven_data.distance_AU); max(maven_data.distance_AU); ...
    min(maven_data.beta_angle); max(maven_data.beta_angle); ...
    100*n_dsn/N; 100*n_msl/N; ...
    corr(P_stk, P_mod)^2; mean(err_rel)];
T_stats = table(stat_names, stat_vals, 'VariableNames', {'Metric', 'Value'});
writetable(T_stats, fullfile(data_dir, 'maven-eps-summary-stats.csv'));
fprintf('       maven-eps-summary-stats.csv    (%d metrics)\n', height(T_stats));

fprintf('\n[EXPORT] CSV export completed: 6 files.\n');
fprintf('\n=== Post-Processing completed ===\n');
