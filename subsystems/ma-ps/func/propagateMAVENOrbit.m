function ds = propagateMAVENOrbit(t, s, par)
% PROPAGATEMAVENORBIT Numerical Mars orbit propagator with optional J2, J3, SRP and drag.
% Example:
%   [T,S] = ode113(@(t,s) propagateMAVENOrbit(t,s,par), tEval, y0, opts);
% Inputs:
%   t   Propagation time from par.epoch [s]
%   s   State [rx; ry; rz; vx; vy; vz] in km and km/s
%   par Parameter struct
% Output:
%   ds  State derivative in km/s and km/s^2
% Created:
%   30-Mar-2026

r = s(1:3);
v = s(4:6);

x = r(1);
y = r(2);
z = r(3);

r2 = dot(r, r);
rnorm = sqrt(r2);

a = -par.mu / rnorm^3 * r;

if par.useJ2
    z2 = z^2;
    facJ2 = 1.5 * par.J2 * par.mu * par.R^2 / rnorm^5;
    aJ2 = facJ2 * [ ...
        x * (5*z2/r2 - 1);
        y * (5*z2/r2 - 1);
        z * (5*z2/r2 - 3)];
    a = a + aJ2;
end

if par.useJ3
    zr = z / rnorm;
    facJ3 = 0.5 * par.J3 * par.mu * par.R^3 / rnorm^5;
    aJ3 = facJ3 * [ ...
        5 * (x / rnorm) * (7*zr^3 - 3*zr);
        5 * (y / rnorm) * (7*zr^3 - 3*zr);
        (35*zr^4 - 30*zr^2 + 3)];
    a = a + aJ3;
end

if par.useSRP
    sunHat = par.sun.sunHat_MCI(:) / norm(par.sun.sunHat_MCI);
    aSrpMag = par.Psr_1AU * (par.Cr * par.A_srp_m2 / par.mass_kg) / par.sun.d_MarsSun_AU^2 * 1e-3;
    aSRP = -aSrpMag * sunHat;
    a = a + aSRP;
end

if par.useDrag
    h_km = rnorm - par.R;
    rho = densityMarsSimple(par.epoch + seconds(t), h_km, par.atm);
    vAtm = cross(par.omegaPlanet(:), r);
    vRel = v - vAtm;
    A_drag_km2 = par.A_drag_m2 * 1e-6;
    aDrag = -0.5 * rho * (par.Cd * A_drag_km2 / par.mass_kg) * norm(vRel) * vRel;
    a = a + aDrag;
end

ds = [v; a];

end

function rho = densityMarsSimple(tUTC, h_km, atm)

dt11 = days(tUTC - atm.t11yr);
dtAN = days(tUTC - atm.tANN);

D = 10^( atm.A11yr*sin(2*pi*dt11/atm.T11yr) ...
       - atm.AANN*sin(2*pi*dtAN/atm.TANN) );

rho = atm.rho0_kgkm3 * exp(-(h_km - atm.h0_km)/atm.H_km) * D;

end