function [rr,vv] = kep2car(a,e,i,OM,om,th,mu)

%{
DESCRIPTION: This function convert keplerian elements into cartesian
             coordinates

INPUT:
    - a Semi-major axis [km]
    - e Eccentricity [adimensionale]
    - i Inclination [rad]
    - OM Right ascension of ascending node (RAAN) [rad]
    - om Anomaly of pericentre [rad]
    - th True anomaly [rad]
    - mu Planetary constant of planet [km^3/s^2]

OUTPUT:
    - rr [3x1] position vector [km]
    - vv [3x1] velocity vector [km/s]

CONTRIBUTORS:
- Matteo Falautano
- Camilla Berlingieri
- Saverio Aprile
- Mafrici Matteo

VERSIONS
  2025-09-30: First version

%}

%semilato retto 
p=a*(1-e^2);

%modulo della posizione
r=p/(1+e*cos(th));

%vettore di stato in PF 
r_s=r*[cos(th); sin(th);0];
v_s=(sqrt(mu/p))*[(-sin(th)); e+cos(th); 0];

%vettore [rr,vv]:

%rotazione di OM intorno a k:
R_OM=[cos(OM) sin(OM) 0; (-sin(OM)) cos(OM) 0; 0 0 1];

%rotazione di i intorno a i' (coincidente con N):
R_i=[1 0 0; 0 cos(i) sin(i); 0 (-sin(i)) cos(i)];

%rotazione di om intorno a k'' (coincidente con h):
R_om = [cos(om) sin(om) 0; (-sin(om)) cos(om) 0; 0 0 1];

%matrice T di rotazione (ECI->PF) totale:
T = R_om * R_i * R_OM;

rr= T' * r_s;
vv=T' * v_s;


end