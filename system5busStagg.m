% system5bus.m
% RESEAU DE STAGG & EL-ABIOD (5 nœuds)
% Référence: Exemple exch81

nbus = 5;
npq = 3;
npv = 1;
ns = 1;
nbr = 7;

basemva = 100;
accuracy = 0.0001;
accel = 1.8;
maxiter = 100;

% Données de nœuds
% Bus | Code | Vmag | Vdeg | Pg(MW) | Qg(Mvar) | Pl(MW) | Ql(Mvar) | Qmin | Qmax | Qinj
busdata = [
    1   1   1.06000    0.0    129.665   -7.480    0.00     0.00      0    0    0
    2   2   1.04621    0.0    40.00     30.00     20.00    10.00     0    0    0
    3   0   1.02032    0.0    0.00      0.00      45.00    15.00     0    0    0
    4   0   1.01917    0.0    0.00      0.00      40.00    5.00      0    0    0
    5   0   1.01209    0.0    0.00      0.00      60.00    10.00     0    0    0
];

% Données de lignes
% nl | nr | R | X | B/2 | tap
linedata = [
    1   2   0.02    0.06    0.030   1
    1   3   0.08    0.24    0.025   1
    2   3   0.06    0.18    0.020   1
    2   4   0.06    0.18    0.020   1
    2   5   0.04    0.12    0.015   1
    3   4   0.01    0.03    0.010   1
    4   5   0.08    0.24    0.025   1
];

% Données des générateurs
% Gen_bus | Ra | Xd' | H (s)
gendata = [
    1   0   0.25    50.0
    2   0   1.50    1.0
];

branch_fault=2;
T_max=0.9;
T_cr=0.1;
delta_t=0.02;
defaut_type='court_circuit_noeud_sans_ouverture';
impedance_defaut=0;