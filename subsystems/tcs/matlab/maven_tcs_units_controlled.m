%% maven_tcs_units_controlled.m
%  =========================================================================
%  MAVEN TCS - Units specifically controlled (report Section 2.4)
%  =========================================================================
%  For each thermally critical unit:
%    (a) COLD CASE: heater power Q_htr [W] required to keep T >= T_min
%        during eclipse + SafeMode (minimum internal dissipation).
%    (b) HOT CASE: equilibrium temperature T_eq_hot [C] under full Sun
%        + Deep Dip (maximum internal dissipation); passive check.
%  Results feed the report Section 2.4 and maven_tcs_budgets.m.
%
%  Thermal model - single-node, steady-state:
%    COLD CASE (eclipse: q_sun = 0, q_alb = 0):
%      Q_htr + Q_int + q_IR * A = eps * sigma * A * T_set^4
%      => Q_htr = eps*sigma*A*T_set^4 - Q_int - q_IR*A
%      T_set = T_min + 15 K   (heater set-point, report convention)
%    HOT CASE (full Sun + Deep Dip):
%      alpha*(q_sun + q_alb)*A_cross + eps*q_IR*A + Q_int = eps*sigma*A*T_eq^4
%      Solve T_eq; verify T_eq <= T_max.
%
%  External fluxes (per-unit analysis, report Section 2.4):
%    Cold : q_sun = 0, q_alb = 0, q_IR = 29.32 W/m2
%    Hot  : q_sun = 716.62, q_alb = 100.18, q_IR = 98.10 W/m2
%
%  Inputs : ../data/tcs-unit-limits.csv
%  Outputs: ../data/tcs-a-results-units.csv , ../data/tcs-a-workspace.mat
%  =========================================================================

clear; clc;

%% -------------------------------------------------------------------------
%  0. PATHS
%  -------------------------------------------------------------------------
this_dir = fileparts(mfilename('fullpath'));
if isempty(this_dir), this_dir = pwd; end
tcs_dir  = fileparts(this_dir);                     % subsystems/tcs
data_dir = fullfile(tcs_dir, 'data');
if ~isfolder(data_dir), mkdir(data_dir); end

%% -------------------------------------------------------------------------
%  1. PHYSICAL CONSTANTS
%  -------------------------------------------------------------------------
sigma = 5.670e-8;   % Stefan-Boltzmann constant [W/m2/K4] (ECSS-E-ST-10-04C)

%% -------------------------------------------------------------------------
%  2. ORBITAL ENVIRONMENT  (per-unit analysis, report Section 2.4)
%  -------------------------------------------------------------------------
q_sun_cold =   0.00;   % [W/m2] eclipse
q_alb_cold =   0.00;   % [W/m2] eclipse
q_IR_cold  =  29.32;   % [W/m2] Mars IR, cold case

q_sun_hot  = 716.62;   % [W/m2] perihelion, full Sun
q_alb_hot  = 100.18;   % [W/m2] Deep Dip
q_IR_hot   =  98.10;   % [W/m2] Deep Dip

fprintf('=== External heat fluxes (report Section 2.4) ===\n');
fprintf('  Cold case: q_sun=%.2f  q_alb=%.2f  q_IR=%.2f  W/m2\n', ...
        q_sun_cold, q_alb_cold, q_IR_cold);
fprintf('  Hot  case: q_sun=%.2f  q_alb=%.2f  q_IR=%.2f  W/m2\n', ...
        q_sun_hot,  q_alb_hot,  q_IR_hot);

%% -------------------------------------------------------------------------
%  3. LOAD UNIT THERMAL PARAMETERS
%  -------------------------------------------------------------------------
fprintf('\nLoading unit thermal parameters...\n');
units = readtable(fullfile(data_dir, 'tcs-unit-limits.csv'), 'TextType', 'string');

units.Properties.VariableNames = ...
    {'Unit','TminC','TmaxC','Qint_cold_W','Qint_hot_W', ...
     'Area_m2','A_cross_m2','epsilon','alpha','mass_kg'};

n_units = height(units);
fprintf('  %d units loaded.\n', n_units);
disp(units(:, 1:9));

%% -------------------------------------------------------------------------
%  4. COLD CASE HEATER SIZING
%     Q_htr = eps*sigma*A*T_set^4 - Q_int - q_IR*A
%     T_set = T_min + 15 K (report convention)
%  -------------------------------------------------------------------------
fprintf('\n=== Cold Case Heater Sizing ===\n');

T_margin_K = 15.0;   % heater set-point margin above T_min [K] (report)

Q_htr          = zeros(n_units, 1);
T_eq_cold      = zeros(n_units, 1);
passive_ok_cold = false(n_units, 1);

for i = 1:n_units
    T_min_K = units.TminC(i) + 273.15;
    T_set_K = T_min_K + T_margin_K;
    A       = units.Area_m2(i);
    epsu    = units.epsilon(i);
    Q_int   = units.Qint_cold_W(i);

    Q_rad_set = epsu * sigma * A * T_set_K^4;    % [W] outgoing
    Q_IR_in   = q_IR_cold * A;                    % [W] Mars IR absorbed

    Q_htr(i) = Q_rad_set - Q_int - Q_IR_in;

    T_eq_cold(i) = ((Q_int + Q_IR_in) / (epsu * sigma * A))^0.25 - 273.15;

    if Q_htr(i) <= 0
        Q_htr(i) = 0;
        passive_ok_cold(i) = true;
        fprintf('  %-18s PASSIVE OK   T_eq_cold=%+6.1f C  T_min=%+5.1f C\n', ...
                units.Unit(i), T_eq_cold(i), units.TminC(i));
    else
        fprintf('  %-18s HEATER REQ.  Q_htr=%6.2f W  T_set=%+6.1f C  T_min=%+5.1f C\n', ...
                units.Unit(i), Q_htr(i), T_set_K - 273.15, units.TminC(i));
    end
end

%% -------------------------------------------------------------------------
%  5. HOT CASE EQUILIBRIUM CHECK
%     Q_in = alpha*(q_sun + q_alb)*A_cross + eps*q_IR*A + Q_int
%     Q_out = eps*sigma*A*T_eq^4  =>  T_eq = (Q_in/(eps*sigma*A))^(1/4)
%  -------------------------------------------------------------------------
fprintf('\n=== Hot Case Equilibrium Check ===\n');

T_eq_hot = zeros(n_units, 1);
hot_ok   = false(n_units, 1);

for i = 1:n_units
    T_max_K = units.TmaxC(i) + 273.15;
    A       = units.Area_m2(i);
    A_cross = units.A_cross_m2(i);
    epsu    = units.epsilon(i);
    alphau  = units.alpha(i);
    Q_int   = units.Qint_hot_W(i);

    Q_sun_abs = alphau * q_sun_hot * A_cross;
    Q_alb_abs = alphau * q_alb_hot * A_cross;
    Q_IR_abs  = epsu   * q_IR_hot  * A;
    Q_in_tot  = Q_sun_abs + Q_alb_abs + Q_IR_abs + Q_int;

    T_eq_hot(i) = (Q_in_tot / (epsu * sigma * A))^0.25 - 273.15;
    hot_ok(i)   = T_eq_hot(i) <= units.TmaxC(i);

    status = 'OK  ';
    if ~hot_ok(i), status = 'OVER'; end
    fprintf('  %-18s %s  T_eq_hot=%+6.1f C  T_max=%+5.1f C  margin=%+5.1f C\n', ...
            units.Unit(i), status, T_eq_hot(i), units.TmaxC(i), ...
            units.TmaxC(i) - T_eq_hot(i));
end

%% -------------------------------------------------------------------------
%  6. CONTROL CLASSIFICATION SUMMARY
%  -------------------------------------------------------------------------
fprintf('\n=== Control Classification Summary ===\n');
fprintf('%-18s %10s %10s %10s %14s\n', ...
        'Unit','T_eq_cold','Q_htr_W','T_eq_hot','Control');
fprintf('%s\n', repmat('-', 1, 68));

control_type = strings(n_units, 1);
for i = 1:n_units
    if Q_htr(i) > 0 && ~hot_ok(i)
        control_type(i) = "BOTH";
    elseif Q_htr(i) > 0
        control_type(i) = "HEATER_REQ";
    elseif ~hot_ok(i)
        control_type(i) = "HOT_CONCERN";
    else
        control_type(i) = "PASSIVE_OK";
    end
    fprintf('%-18s %+9.1f   %10.2f %+9.1f   %14s\n', ...
            units.Unit(i), T_eq_cold(i), Q_htr(i), T_eq_hot(i), control_type(i));
end

Q_htr_total = sum(Q_htr);
fprintf('%s\n', repmat('-', 1, 68));
fprintf('%-18s %10s %10.2f %10s\n', 'TOTAL', '', Q_htr_total, '');
fprintf('\nTotal heater power (cold case peak): %.2f W\n', Q_htr_total);

%% -------------------------------------------------------------------------
%  7. SAVE OUTPUTS
%  -------------------------------------------------------------------------
results = units(:, 1:10);
results.T_eq_cold_C  = T_eq_cold;
results.Q_htr_W      = Q_htr;
results.T_eq_hot_C   = T_eq_hot;
results.Hot_case_OK  = hot_ok;
results.Control_type = control_type;

writetable(results, fullfile(data_dir, 'tcs-a-results-units.csv'));
fprintf('\nWritten: tcs-a-results-units.csv\n');

save(fullfile(data_dir, 'tcs-a-workspace.mat'), ...
     'results', 'Q_htr_total', 'Q_htr', ...
     'T_eq_cold', 'T_eq_hot', 'hot_ok', 'control_type', ...
     'units', 'n_units', ...
     'q_sun_cold', 'q_alb_cold', 'q_IR_cold', ...
     'q_sun_hot',  'q_alb_hot',  'q_IR_hot',  ...
     'sigma');
fprintf('Written: tcs-a-workspace.mat\n');
fprintf('\n=== Script A complete. Run maven_tcs_budgets.m next ===\n');