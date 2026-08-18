%% maven_stk_data_loader.m
%  =========================================================================
%  MAVEN EPS - STK Data Loader (full dataset)
%  =========================================================================
%  Loads and pre-processes all STK data needed for the EPS simulation:
%    1) Solar Panel Power       (P_solar, Solar Intensity @10s)
%    2) Eclipse Summary         (Penumbra/Umbra intervals)
%    3) Sunlit Intervals        (cross-validation)
%    4) Attitude Schedule       (pointing mode names)
%    5) Solar AU Range          (distance from Sun)
%    6) Beta Angle              (solar beta angle)
%    7) Panel-Sun Incidence     (theta angle @10s)
%    8) Mars Inertial State     (pos/vel J2000)
%    9) DSN/MSL Access Windows  (comm windows)
%
%  Output: struct 'maven_data' aligned on a uniform time grid (dt = 60 s).
%
%  Inputs: renamed STK exports in ../stk/ (kebab-case), attitude schedule
%          in ../../aocs/attitude-schedule.txt.
%  =========================================================================

clear; clc; close all;
fprintf('=== MAVEN STK Data Loader - Full Dataset ===\n\n');

%% -----------------------------------------------------------------------
%  0. PATHS AND FIGURE STYLE
%  -----------------------------------------------------------------------
this_dir = fileparts(mfilename('fullpath'));
if isempty(this_dir), this_dir = pwd; end
eps_dir  = fileparts(this_dir);                    % subsystems/eps
stk_dir  = fullfile(eps_dir, 'stk');
data_dir = fullfile(eps_dir, 'data');
fig_dir  = fullfile(eps_dir, 'figures');
aocs_dir = fullfile(eps_dir, '..', 'aocs');
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
%  1. CONFIGURATION
%  -----------------------------------------------------------------------
cfg.dt             = 60;          % [s] simulation sampling step
cfg.initial_SOC    = 0.85;        % [-] initial battery state of charge
cfg.orbit_period   = 4.5 * 3600;  % [s] nominal orbital period (~16200 s)

% --- Solar panel parameters ---
cfg.S0             = 1361;        % [W/m^2] solar constant at 1 AU
cfg.A_cell         = 12.0;        % [m^2] total active panel area
cfg.eta_BOL        = 0.295;       % [-] BOL efficiency (UTJ triple-junction)
cfg.eta_degradation= 0.97;        % [-] degradation factor (3% after ~1 year)
cfg.eta_eff        = cfg.eta_BOL * cfg.eta_degradation;

% --- STK file paths (renamed, kebab-case) ---
cfg.file_solar      = fullfile(stk_dir, 'maven-solar-panel-power.txt');
cfg.file_eclipse    = fullfile(stk_dir, 'maven-eclipse-summary.txt');
cfg.file_sunlit     = fullfile(stk_dir, 'maven-sunlit.txt');
cfg.file_attitude   = fullfile(aocs_dir, 'attitude-schedule.txt');
cfg.file_au_range   = fullfile(stk_dir, 'maven-solar-au-range.txt');
cfg.file_beta_angle = fullfile(stk_dir, 'maven-beta-angle.txt');
cfg.file_incidence  = fullfile(stk_dir, 'maven-panel-incidence.txt');
cfg.file_inertial   = fullfile(stk_dir, 'maven-mars-inertial-state.txt');
cfg.file_access     = fullfile(stk_dir, 'maven-access-earth-to-mars.txt');

%% -----------------------------------------------------------------------
%  2. SOLAR PANEL POWER
%  -----------------------------------------------------------------------
fprintf('[1/9] Loading Solar Panel Power...\n');

raw_solar = parse_stk_solar_power(cfg.file_solar);
fprintf('       %d samples loaded\n', length(raw_solar.time));

t_start = raw_solar.time(1);
t_end   = raw_solar.time(end);
fprintf('       Interval: %s  -->  %s\n', ...
        datestr(t_start, 'dd-mmm-yyyy HH:MM:SS'), ...
        datestr(t_end,   'dd-mmm-yyyy HH:MM:SS'));
fprintf('       Duration: %.2f days\n', t_end - t_start);

t_grid = (t_start : cfg.dt/86400 : t_end)';
N = length(t_grid);
fprintf('       Uniform grid: %d samples (dt = %d s)\n', N, cfg.dt);

P_solar = interp1(raw_solar.time, raw_solar.power, t_grid, 'linear', 0);
solar_intensity = interp1(raw_solar.time, raw_solar.intensity, t_grid, 'linear', 0);

P_solar(P_solar < 0) = 0;
solar_intensity(solar_intensity < 0) = 0;

fprintf('       Power: min=%.1f W, max=%.1f W, mean=%.1f W\n', ...
        min(P_solar), max(P_solar), mean(P_solar));

%% -----------------------------------------------------------------------
%  3. ECLIPSE
%  -----------------------------------------------------------------------
fprintf('\n[2/9] Loading Eclipse Summary...\n');

ecl = parse_stk_eclipse(cfg.file_eclipse);
n_ecl = length(ecl.pen_start);
fprintf('       %d eclipse events loaded\n', n_ecl);

eclipse_flag = zeros(N, 1);
eclipse_frac = ones(N, 1);

for k = 1:n_ecl
    idx_pen_in = (t_grid >= ecl.pen_start(k)) & (t_grid < ecl.umb_start(k));
    eclipse_flag(idx_pen_in) = 1;
    if any(idx_pen_in)
        dt_pen = (ecl.umb_start(k) - ecl.pen_start(k)) * 86400;
        t_local = (t_grid(idx_pen_in) - ecl.pen_start(k)) * 86400;
        eclipse_frac(idx_pen_in) = max(0, 1 - t_local / dt_pen);
    end

    idx_umb = (t_grid >= ecl.umb_start(k)) & (t_grid <= ecl.umb_stop(k));
    eclipse_flag(idx_umb) = 2;
    eclipse_frac(idx_umb) = 0;

    if ~isnan(ecl.pen_stop(k))
        idx_pen_out = (t_grid > ecl.umb_stop(k)) & (t_grid <= ecl.pen_stop(k));
        eclipse_flag(idx_pen_out) = 1;
        dt_pen = (ecl.pen_stop(k) - ecl.umb_stop(k)) * 86400;
        t_local = (t_grid(idx_pen_out) - ecl.umb_stop(k)) * 86400;
        eclipse_frac(idx_pen_out) = max(0, min(1, t_local / dt_pen));
    end
end

n_eclipse_samples = sum(eclipse_flag > 0);
fprintf('       Samples in eclipse: %d (%.1f%%)\n', ...
        n_eclipse_samples, 100*n_eclipse_samples/N);

%% -----------------------------------------------------------------------
%  4. SUNLIT (validation)
%  -----------------------------------------------------------------------
fprintf('\n[3/9] Loading Sunlit Intervals...\n');

sun = parse_stk_sunlit(cfg.file_sunlit);
fprintf('       %d sunlit intervals loaded\n', sun.n_intervals);

sunlit_from_flag = sum(eclipse_flag == 0) * cfg.dt;
fprintf('       Sunlit from eclipse_flag: %.1f h (vs STK: %.1f h)\n', ...
        sunlit_from_flag/3600, sun.total_duration/3600);

%% -----------------------------------------------------------------------
%  5. ATTITUDE SCHEDULE
%  -----------------------------------------------------------------------
fprintf('\n[4/9] Loading Attitude Schedule...\n');

att = parse_stk_attitude(cfg.file_attitude);
fprintf('       %d attitude segments loaded\n', att.n_segments);

pointing_mode = zeros(N, 1);
attitude_name = cell(N, 1);

for k = 1:att.n_segments
    idx = (t_grid >= att.start(k)) & (t_grid < att.stop(k));
    name_k = att.name{k};
    mode_k = classify_attitude_mode(name_k);
    pointing_mode(idx) = mode_k;
    attitude_name(idx) = {name_k};
end

idx_last = (t_grid >= att.stop(end));
if any(idx_last)
    pointing_mode(idx_last) = pointing_mode(find(~idx_last, 1, 'last'));
end

pointing_mode_with_eclipse = pointing_mode;
pointing_mode_with_eclipse(eclipse_flag == 2) = 6;

mode_names = {'Fly-Y','Fly-Z','Sun-Velocity','HGA_Comm','DeepDip/Maneuver',...
              'Eclipse','SafeMode','Slew','Relay'};
fprintf('\n       Pointing mode distribution:\n');
for m = 1:9
    n_m = sum(pointing_mode == m);
    if n_m > 0
        fprintf('         %d %-18s: %6d samples (%5.1f%%)\n', ...
                m, mode_names{m}, n_m, 100*n_m/N);
    end
end

%% -----------------------------------------------------------------------
%  6. SOLAR AU RANGE
%  -----------------------------------------------------------------------
fprintf('\n[5/9] Loading Solar AU Range...\n');

raw_au = parse_stk_au_range(cfg.file_au_range);
fprintf('       %d samples loaded\n', length(raw_au.time));

distance_AU = interp1(raw_au.time, raw_au.au, t_grid, 'linear', 'extrap');
fprintf('       AU range: %.6f - %.6f AU\n', min(distance_AU), max(distance_AU));

solar_flux = cfg.S0 ./ (distance_AU.^2);
fprintf('       Solar flux: %.1f - %.1f W/m^2\n', min(solar_flux), max(solar_flux));

%% -----------------------------------------------------------------------
%  7. BETA ANGLE
%  -----------------------------------------------------------------------
fprintf('\n[6/9] Loading Beta Angle...\n');

raw_beta = parse_stk_beta_angle(cfg.file_beta_angle);
fprintf('       %d samples loaded\n', length(raw_beta.time));

beta_angle = interp1(raw_beta.time, raw_beta.beta, t_grid, 'linear', 'extrap');
fprintf('       Beta angle range: %.2f to %.2f deg\n', min(beta_angle), max(beta_angle));

%% -----------------------------------------------------------------------
%  8. INCIDENCE ANGLE (theta)
%  -----------------------------------------------------------------------
fprintf('\n[7/9] Loading Panel-Sun Incidence Angle...\n');

raw_theta = parse_stk_incidence_angle(cfg.file_incidence);
fprintf('       %d samples loaded\n', length(raw_theta.time));

incidence_angle = interp1(raw_theta.time, raw_theta.angle, t_grid, 'linear', 'extrap');
fprintf('       Theta range: %.2f - %.2f deg\n', min(incidence_angle), max(incidence_angle));
fprintf('       Mean theta (sunlit): %.2f deg\n', ...
        mean(incidence_angle(eclipse_flag == 0)));

cos_theta = cosd(incidence_angle);
cos_theta(cos_theta < 0) = 0;
P_solar_model = cfg.eta_eff .* cfg.A_cell .* solar_flux .* cos_theta;
P_solar_model(eclipse_flag == 2) = 0;
P_solar_model(eclipse_flag == 1) = P_solar_model(eclipse_flag == 1) .* ...
                                    eclipse_frac(eclipse_flag == 1);

fprintf('       P_solar_model: mean=%.1f W, max=%.1f W\n', ...
        mean(P_solar_model), max(P_solar_model));
fprintf('       P_solar_STK:   mean=%.1f W, max=%.1f W\n', ...
        mean(P_solar), max(P_solar));

idx_sun = (eclipse_flag == 0) & (P_solar > 10);
if any(idx_sun)
    err_rel = abs(P_solar(idx_sun) - P_solar_model(idx_sun)) ./ P_solar(idx_sun) * 100;
    fprintf('       Mean relative error (sunlit): %.1f%%\n', mean(err_rel));
end

%% -----------------------------------------------------------------------
%  9. MARS INERTIAL STATE
%  -----------------------------------------------------------------------
fprintf('\n[8/9] Loading Mars Inertial State...\n');

raw_iner = parse_stk_inertial_state(cfg.file_inertial);
fprintf('       %d samples loaded\n', length(raw_iner.time));

pos_km = zeros(N, 3);
vel_kms = zeros(N, 3);
for ax_i = 1:3
    pos_km(:, ax_i)  = interp1(raw_iner.time, raw_iner.pos(:, ax_i), t_grid, 'linear', 'extrap');
    vel_kms(:, ax_i) = interp1(raw_iner.time, raw_iner.vel(:, ax_i), t_grid, 'linear', 'extrap');
end

altitude_km = sqrt(sum(pos_km.^2, 2)) - 3389.5;
fprintf('       Altitude: min=%.0f km, max=%.0f km\n', ...
        min(altitude_km), max(altitude_km));

%% -----------------------------------------------------------------------
%  10. ACCESS WINDOWS (DSN + MSL)
%  -----------------------------------------------------------------------
fprintf('\n[9/9] Loading Access Windows (DSN + MSL)...\n');

access = parse_stk_access(cfg.file_access);
fprintf('       Stations loaded:\n');
station_names = fieldnames(access);
for s = 1:length(station_names)
    st = access.(station_names{s});
    fprintf('         %-30s: %d passes, %.1f h total\n', ...
            station_names{s}, st.n_passes, st.total_duration/3600);
end

comm_flag = zeros(N, 1);
for s = 1:length(station_names)
    st = access.(station_names{s});
    is_msl = contains(station_names{s}, 'MSL') || contains(station_names{s}, 'Curiosity');
    for p = 1:st.n_passes
        idx = (t_grid >= st.start(p)) & (t_grid <= st.stop(p));
        if is_msl
            comm_flag(idx) = 2;
        else
            comm_flag(idx) = max(comm_flag(idx), 1);
        end
    end
end

fprintf('       Samples with DSN: %d (%.1f%%)\n', sum(comm_flag==1), 100*sum(comm_flag==1)/N);
fprintf('       Samples with MSL: %d (%.1f%%)\n', sum(comm_flag==2), 100*sum(comm_flag==2)/N);

%% -----------------------------------------------------------------------
%  11. OUTPUT STRUCT
%  -----------------------------------------------------------------------
fprintf('\n[OUTPUT] Assembling maven_data struct...\n');

maven_data.time              = t_grid;
maven_data.time_s            = (t_grid - t_grid(1)) * 86400;
maven_data.dt                = cfg.dt;
maven_data.N                 = N;
maven_data.t_start           = t_start;
maven_data.t_end             = t_end;

maven_data.P_solar           = P_solar;
maven_data.solar_intensity   = solar_intensity;
maven_data.P_solar_model     = P_solar_model;

maven_data.eclipse_flag      = eclipse_flag;
maven_data.eclipse_frac      = eclipse_frac;
maven_data.eclipse_table     = ecl;

maven_data.sunlit_table      = sun;

maven_data.pointing_mode     = pointing_mode;
maven_data.pointing_mode_eff = pointing_mode_with_eclipse;
maven_data.attitude_name     = attitude_name;
maven_data.attitude_table    = att;

maven_data.distance_AU       = distance_AU;
maven_data.solar_flux        = solar_flux;

maven_data.beta_angle        = beta_angle;

maven_data.incidence_angle   = incidence_angle;
maven_data.cos_theta         = cos_theta;

maven_data.pos_km            = pos_km;
maven_data.vel_kms           = vel_kms;
maven_data.altitude_km       = altitude_km;

maven_data.comm_flag         = comm_flag;
maven_data.access_table      = access;

maven_data.cfg               = cfg;

fprintf('       Struct maven_data with %d fields\n', length(fieldnames(maven_data)));
fprintf('       Samples: %d | Duration: %.2f days | dt: %d s\n', N, (t_end-t_start), cfg.dt);

%% -----------------------------------------------------------------------
%  12. SAVE
%  -----------------------------------------------------------------------
save(fullfile(data_dir, 'maven_stk_data.mat'), 'maven_data', '-v7.3');
fprintf('\n[SAVE] maven_stk_data.mat saved in %s.\n', data_dir);

%% -----------------------------------------------------------------------
%  13. VERIFICATION PLOTS
%  -----------------------------------------------------------------------
fprintf('\n[PLOT] Generating verification plots...\n');

t_hours = maven_data.time_s / 3600;

% === Plot 1: full overview ===
figure('Position', [50 50 1600 1100]);

subplot(7,1,1);
plot(t_hours, P_solar, 'Color', [1 0.6 0], 'LineWidth', 0.5); hold on;
plot(t_hours, P_solar_model, 'b--', 'LineWidth', 0.3);
ylabel('P_{solar} [W]'); title('MAVEN STK Data Loader - Overview');
legend('STK','Model','Location','best');
xlim([0 t_hours(end)]); grid on;

subplot(7,1,2);
plot(t_hours, eclipse_flag, 'r', 'LineWidth', 0.5);
ylabel('Eclipse'); yticks([0 1 2]); yticklabels({'Sun','Pen','Umbra'});
xlim([0 t_hours(end)]); grid on;

subplot(7,1,3);
plot(t_hours, pointing_mode_with_eclipse, 'Color', [0.2 0.6 0.2], 'LineWidth', 0.5);
ylabel('Mode'); yticks(1:9); yticklabels(mode_names);
xlim([0 t_hours(end)]); grid on;

subplot(7,1,4);
plot(t_hours, distance_AU, 'Color', [0.6 0.2 0.8], 'LineWidth', 1);
ylabel('r_{AU}'); xlim([0 t_hours(end)]); grid on;

subplot(7,1,5);
plot(t_hours, beta_angle, 'Color', [0 0.5 0.8], 'LineWidth', 1);
ylabel('\beta [deg]'); xlim([0 t_hours(end)]); grid on;

subplot(7,1,6);
plot(t_hours, incidence_angle, 'Color', [0.8 0.3 0.1], 'LineWidth', 0.5);
ylabel('\theta [deg]'); xlim([0 t_hours(end)]); grid on;

subplot(7,1,7);
plot(t_hours, altitude_km, 'Color', [0.4 0.4 0.4], 'LineWidth', 0.5);
ylabel('Alt [km]'); xlabel('Time [h]');
xlim([0 t_hours(end)]); grid on;

saveas(gcf, fullfile(fig_dir, 'maven-eps-stk-overview.png'));
fprintf('[PLOT] maven-eps-stk-overview.png saved.\n');

% === Plot 2: P_solar STK vs model validation ===
figure('Position', [50 50 1400 500]);
idx_plot = 1:min(5000, N);
plot(t_hours(idx_plot), P_solar(idx_plot), 'Color', [1 0.6 0], 'LineWidth', 0.8); hold on;
plot(t_hours(idx_plot), P_solar_model(idx_plot), 'b--', 'LineWidth', 0.8);
legend('P_{solar} STK', 'P_{solar} Model (\eta A S/r^2 cos\theta)');
xlabel('Time [h]'); ylabel('Power [W]');
title('Validation: P_{solar} STK vs Analytical Model');
grid on;
saveas(gcf, fullfile(fig_dir, 'maven-eps-stk-validation.png'));
fprintf('[PLOT] maven-eps-stk-validation.png saved.\n');

fprintf('\n=== Data Loader completed ===\n');

%% =======================================================================
%  PARSING FUNCTIONS
%  =======================================================================

function data = parse_stk_solar_power(filename)
    fid = fopen(filename, 'r');
    if fid == -1, error('File not found: %s', filename); end
    while true
        line = fgetl(fid);
        if contains(line, '------'), break; end
    end
    times = []; power = []; intensity = [];
    started = false;
    while ~feof(fid)
        line = fgetl(fid);
        if isempty(strtrim(line)), continue; end
        tokens = regexp(strtrim(line), ...
            '^(\d+ \w+ \d+ \d+:\d+:\d+\.\d+)\s+([\d.]+)\s+([\d.]+)$', 'tokens');
        if isempty(tokens)
            if started, break; end
            continue;
        end
        started = true;
        times(end+1,1)     = datenum(tokens{1}{1}, 'dd mmm yyyy HH:MM:SS.FFF');
        power(end+1,1)     = str2double(tokens{1}{2});
        intensity(end+1,1) = str2double(tokens{1}{3});
    end
    fclose(fid);
    data.time = times; data.power = power; data.intensity = intensity;
end


function ecl = parse_stk_eclipse(filename)
    fid = fopen(filename, 'r');
    if fid == -1, error('File not found: %s', filename); end
    while true
        line = fgetl(fid);
        if contains(line, '------'), break; end
    end
    pen_start=[]; umb_start=[]; umb_stop=[]; pen_stop=[];
    duration=[]; max_shadow=[];
    while ~feof(fid)
        line = fgetl(fid);
        if isempty(strtrim(line)), continue; end
        tokens = regexp(strtrim(line), ...
            '(\d+ \w+ \d+ \d+:\d+:\d+\.\d+)\s+(\d+ \w+ \d+ \d+:\d+:\d+\.\d+)\s+(\d+ \w+ \d+ \d+:\d+:\d+\.\d+)\s+((?:\d+ \w+ \d+ \d+:\d+:\d+\.\d+)|No Data)\s+\w+\s+([\d.]+)\s+([\d.]+)', ...
            'tokens');
        if isempty(tokens), continue; end
        pen_start(end+1,1) = datenum(tokens{1}{1}, 'dd mmm yyyy HH:MM:SS.FFF');
        umb_start(end+1,1) = datenum(tokens{1}{2}, 'dd mmm yyyy HH:MM:SS.FFF');
        umb_stop(end+1,1)  = datenum(tokens{1}{3}, 'dd mmm yyyy HH:MM:SS.FFF');
        if strcmp(tokens{1}{4}, 'No Data')
            pen_stop(end+1,1) = NaN;
        else
            pen_stop(end+1,1) = datenum(tokens{1}{4}, 'dd mmm yyyy HH:MM:SS.FFF');
        end
        duration(end+1,1)   = str2double(tokens{1}{5});
        max_shadow(end+1,1) = str2double(tokens{1}{6});
    end
    fclose(fid);
    ecl.pen_start=pen_start; ecl.umb_start=umb_start;
    ecl.umb_stop=umb_stop;   ecl.pen_stop=pen_stop;
    ecl.duration=duration;    ecl.max_shadow=max_shadow;
    ecl.n_events=length(pen_start);
end


function sun = parse_stk_sunlit(filename)
    fid = fopen(filename, 'r');
    if fid == -1, error('File not found: %s', filename); end
    while true
        line = fgetl(fid);
        if contains(line, '------'), break; end
    end
    starts=[]; stops=[]; durations=[];
    while ~feof(fid)
        line = fgetl(fid);
        if isempty(strtrim(line)), continue; end
        if contains(line, 'Statistics'), break; end
        tokens = regexp(strtrim(line), ...
            '(\d+ \w+ \d+ \d+:\d+:\d+\.\d+)\s+(\d+ \w+ \d+ \d+:\d+:\d+\.\d+)\s+([\d.]+)', ...
            'tokens');
        if isempty(tokens), continue; end
        starts(end+1,1)    = datenum(tokens{1}{1}, 'dd mmm yyyy HH:MM:SS.FFF');
        stops(end+1,1)     = datenum(tokens{1}{2}, 'dd mmm yyyy HH:MM:SS.FFF');
        durations(end+1,1) = str2double(tokens{1}{3});
    end
    fclose(fid);
    sun.start=starts; sun.stop=stops; sun.duration=durations;
    sun.total_duration=sum(durations); sun.mean_duration=mean(durations);
    sun.n_intervals=length(starts);
end


function att = parse_stk_attitude(filename)
    fid = fopen(filename, 'r');
    if fid == -1, error('File not found: %s', filename); end
    while true
        line = fgetl(fid);
        if contains(line, '------'), break; end
    end
    starts=[]; stops=[]; durations=[]; names={}; types={};
    while ~feof(fid)
        line = fgetl(fid);
        if isempty(strtrim(line)), continue; end
        tokens = regexp(strtrim(line), ...
            '(\d+ \w+ \d+ \d+:\d+:\d+\.\d+)\s+(\d+ \w+ \d+ \d+:\d+:\d+\.\d+)\s+([\d.]+)\s+(\S+)\s+(\S+)', ...
            'tokens');
        if isempty(tokens), continue; end
        starts(end+1,1)    = datenum(tokens{1}{1}, 'dd mmm yyyy HH:MM:SS.FFF');
        stops(end+1,1)     = datenum(tokens{1}{2}, 'dd mmm yyyy HH:MM:SS.FFF');
        durations(end+1,1) = str2double(tokens{1}{3});
        names{end+1,1}     = tokens{1}{4};
        types{end+1,1}     = tokens{1}{5};
    end
    fclose(fid);
    att.start=starts; att.stop=stops; att.duration=durations;
    att.name=names; att.type=types; att.n_segments=length(starts);
end


function data = parse_stk_au_range(filename)
%PARSE_STK_AU_RANGE Reads the STK Solar AU Range report
%  Format: Magnitude (Au)    Time (UTCG)
    fid = fopen(filename, 'r');
    if fid == -1, error('File not found: %s', filename); end
    while true
        line = fgetl(fid);
        if contains(line, '------'), break; end
    end
    times = []; au = [];
    while ~feof(fid)
        line = fgetl(fid);
        if isempty(strtrim(line)), continue; end
        tokens = regexp(strtrim(line), ...
            '^([\d.]+)\s+(\d+ \w+ \d+ \d+:\d+:\d+\.\d+)$', 'tokens');
        if isempty(tokens), continue; end
        au(end+1,1)    = str2double(tokens{1}{1});
        times(end+1,1) = datenum(tokens{1}{2}, 'dd mmm yyyy HH:MM:SS.FFF');
    end
    fclose(fid);
    data.time = times; data.au = au;
end


function data = parse_stk_beta_angle(filename)
%PARSE_STK_BETA_ANGLE Reads the STK Beta Angle report
%  Format: Time (UTCG)    Beta Angle (deg)
    fid = fopen(filename, 'r');
    if fid == -1, error('File not found: %s', filename); end
    while true
        line = fgetl(fid);
        if contains(line, '------'), break; end
    end
    times = []; beta = [];
    while ~feof(fid)
        line = fgetl(fid);
        if isempty(strtrim(line)), continue; end
        tokens = regexp(strtrim(line), ...
            '^(\d+ \w+ \d+ \d+:\d+:\d+\.\d+)\s+(-?[\d.]+)$', 'tokens');
        if isempty(tokens), continue; end
        times(end+1,1) = datenum(tokens{1}{1}, 'dd mmm yyyy HH:MM:SS.FFF');
        beta(end+1,1)  = str2double(tokens{1}{2});
    end
    fclose(fid);
    data.time = times; data.beta = beta;
end


function data = parse_stk_incidence_angle(filename)
%PARSE_STK_INCIDENCE_ANGLE Reads the STK normalPanelsVSsun report
%  Format: Time (UTCG)    Angle (deg)
    fid = fopen(filename, 'r');
    if fid == -1, error('File not found: %s', filename); end
    while true
        line = fgetl(fid);
        if contains(line, '------'), break; end
    end
    times = []; angle = [];
    while ~feof(fid)
        line = fgetl(fid);
        if isempty(strtrim(line)), continue; end
        tokens = regexp(strtrim(line), ...
            '^(\d+ \w+ \d+ \d+:\d+:\d+\.\d+)\s+([\d.]+)$', 'tokens');
        if isempty(tokens), continue; end
        times(end+1,1) = datenum(tokens{1}{1}, 'dd mmm yyyy HH:MM:SS.FFF');
        angle(end+1,1) = str2double(tokens{1}{2});
    end
    fclose(fid);
    data.time = times; data.angle = angle;
end


function data = parse_stk_inertial_state(filename)
%PARSE_STK_INERTIAL_STATE Reads the STK Mars Inertial Position & Velocity report
%  Format: Time    x(km)  y(km)  z(km)  vx(km/s)  vy(km/s)  vz(km/s)
    fid = fopen(filename, 'r');
    if fid == -1, error('File not found: %s', filename); end
    while true
        line = fgetl(fid);
        if contains(line, '------'), break; end
    end
    times = []; pos = []; vel = [];
    while ~feof(fid)
        line = fgetl(fid);
        if isempty(strtrim(line)), continue; end
        tokens = regexp(strtrim(line), ...
            '^(\d+ \w+ \d+ \d+:\d+:\d+\.\d+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)$', ...
            'tokens');
        if isempty(tokens), continue; end
        times(end+1,1) = datenum(tokens{1}{1}, 'dd mmm yyyy HH:MM:SS.FFF');
        pos(end+1,:)   = [str2double(tokens{1}{2}), str2double(tokens{1}{3}), str2double(tokens{1}{4})];
        vel(end+1,:)   = [str2double(tokens{1}{5}), str2double(tokens{1}{6}), str2double(tokens{1}{7})];
    end
    fclose(fid);
    data.time = times; data.pos = pos; data.vel = vel;
end


function access = parse_stk_access(filename)
%PARSE_STK_ACCESS Reads the STK Access Summary report (multi-station)
    fid = fopen(filename, 'r');
    if fid == -1, error('File not found: %s', filename); end

    access = struct();
    current_station = '';

    while ~feof(fid)
        line = fgetl(fid);
        if ~ischar(line), break; end

        match = regexp(line, 'Satellite-MAVEN1?-To-(Facility-\S+)', 'tokens');
        if ~isempty(match)
            current_station = strrep(match{1}{1}, '-', '_');
            current_station = strrep(current_station, ',', '');
            access.(current_station).start = [];
            access.(current_station).stop  = [];
            access.(current_station).duration = [];
            continue;
        end

        if isempty(current_station), continue; end
        if contains(line, 'Statistics')
            access.(current_station).n_passes = length(access.(current_station).start);
            access.(current_station).total_duration = sum(access.(current_station).duration);
            current_station = '';
            continue;
        end

        tokens = regexp(strtrim(line), ...
            '^\d+\s+(\d+ \w+ \d+ \d+:\d+:\d+\.\d+)\s+(\d+ \w+ \d+ \d+:\d+:\d+\.\d+)\s+([\d.]+)$', ...
            'tokens');
        if isempty(tokens), continue; end

        access.(current_station).start(end+1,1)    = datenum(tokens{1}{1}, 'dd mmm yyyy HH:MM:SS.FFF');
        access.(current_station).stop(end+1,1)     = datenum(tokens{1}{2}, 'dd mmm yyyy HH:MM:SS.FFF');
        access.(current_station).duration(end+1,1) = str2double(tokens{1}{3});
    end
    fclose(fid);

    if ~isempty(current_station)
        access.(current_station).n_passes = length(access.(current_station).start);
        access.(current_station).total_duration = sum(access.(current_station).duration);
    end
end


function mode = classify_attitude_mode(name)
%CLASSIFY_ATTITUDE_MODE Maps the STK name to the numeric mode code
    name_upper = upper(name);
    if contains(name_upper, 'FLYY') || contains(name_upper, 'FLY_Y')
        mode = 1;
    elseif contains(name_upper, 'FLYZ') || contains(name_upper, 'FLY_Z') || ...
           contains(name_upper, 'DRAG')
        mode = 2;
    elseif contains(name_upper, 'SUN_VELOCITY') || contains(name_upper, 'SUN_VEL')
        mode = 3;
    elseif contains(name_upper, 'COMM') || contains(name_upper, 'HGA')
        mode = 4;
    elseif contains(name_upper, 'DELTAV') || contains(name_upper, 'OTM') || ...
           contains(name_upper, 'PCM') || contains(name_upper, 'DEEP_DIP')
        mode = 5;
    elseif contains(name_upper, 'SAFE_MODE') || contains(name_upper, 'SAFE')
        mode = 7;
    elseif contains(name_upper, 'SLEW') || contains(name_upper, 'VARIABLETIME')
        mode = 8;
    elseif contains(name_upper, 'MSL') || contains(name_upper, 'CURIOSITY') || ...
           contains(name_upper, 'RELAY')
        mode = 9;
    else
        mode = 3;  % default: Sun-Velocity
    end
end
