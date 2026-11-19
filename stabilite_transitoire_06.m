function results = stabilite_transitoire_06(appData, n_depart, n_arrivee, T_cr, T_max, dt)
% =========================================================================
%  ANALYSE DE STABILITE TRANSITOIRE AVEC OUVERTURE DE LIGNE
%  Version compatible avec l'interface MAIN
%  Methodes : 
%    - Predicateur-Correcteur (Euler explicite + trapeze) pour les angles
%    - Runge-Kutta d'ordre 2 (RK2) pour les angles relatifs (plus précis)
% =========================================================================
%
% ENTREES :
%   appData    - structure contenant toutes les donnees du systeme
%   n_depart   - noeud de depart de la ligne a ouvrir
%   n_arrivee  - noeud d'arrivee de la ligne a ouvrir
%   T_cr       - temps de declenchement (ouverture) [s]
%   T_max      - duree totale de simulation [s]
%   dt         - pas de temps [s]
%
% SORTIES :
%   results - structure contenant :
%     .t         - vecteur temps [s]
%     .delta     - angles rotoriques [deg] (temps en lignes, generateurs en colonnes)
%     .omega     - vitesses relatives [rad/s]
%     .delta_rel - angles relatifs RK2 [deg] (temps en lignes, generateurs en colonnes)
% =========================================================================

    % =====================================================================
    %% RECUPERATION DES DONNEES (comme dans l'original)
    % =====================================================================
    busdata = appData.busdata;
    linedata = appData.linedata;
    gendata = appData.gendata;
    nbus = appData.nbus;
    nbr = appData.nbr;
    basemva = appData.basemva;
    accuracy = appData.accuracy;
    maxiter = appData.maxiter;
    accel = appData.accel;
    
    % Frequence et pulsation synchrone
    f0 = 60;
    ws = 2*pi*f0;
    
    % =====================================================================
    %% VERIFICATION DE L'EXISTENCE DE LA LIGNE
    % =====================================================================
    idx_fm = find( (linedata(:,1)==n_depart & linedata(:,2)==n_arrivee) | ...
                   (linedata(:,1)==n_arrivee & linedata(:,2)==n_depart) );
    if isempty(idx_fm)
        error('La ligne %d-%d n''existe pas dans linedata.', n_depart, n_arrivee);
    end
    
    flt_bus = n_depart;
    rem_bus = n_arrivee;
    
    % =====================================================================
    %% 1. ECOULEMENT DE PUISSANCE (Gauss-Seidel)
    % =====================================================================
    Ybus = calcul_Ybus_06(nbus, linedata, nbr);
    [V, ~, iter, ~] = EP_Gauss_Seidel_06(busdata, linedata, basemva, accuracy, maxiter, nbr, accel);
    
    % =====================================================================
    %% 2. PARAMETRES DES GENERATEURS
    % =====================================================================
    ng = size(gendata, 1);
    gen_bus = (1:ng)';
    
    Xd_prime = gendata(:,3);
    H = gendata(:,4);
    M = 2*H / ws;
    
    Ic = Ybus * V;
    Scalc = V .* conj(Ic);
    
    E_prime = zeros(ng,1);
    delta0 = zeros(ng,1);
    
    for k = 1:ng
        n = gen_bus(k);
        Vn = V(n);
        PG = real(Scalc(n)) + busdata(n,5)/basemva;
        QG = imag(Scalc(n)) + busdata(n,6)/basemva;
        Ig = conj((PG + 1j*QG) / Vn);
        Ep = Vn + 1j*Xd_prime(k)*Ig;
        delta0(k) = angle(Ep);
        E_prime(k) = abs(Ep);
    end
    
    % =====================================================================
    %% 3. YBUS AUGMENTEE
    % =====================================================================
    Ybus_load = Ybus;
    for i = 1:nbus
        PL_i = busdata(i,5) / basemva;
        QL_i = busdata(i,6) / basemva;
        if PL_i ~= 0 || QL_i ~= 0
            Vi = abs(V(i));
            y_load_i = (PL_i - 1j*QL_i) / Vi^2;
            Ybus_load(i,i) = Ybus_load(i,i) + y_load_i;
        end
    end
    
    gen_nodes = (nbus+1 : nbus+ng)';
    all_nodes = (1 : nbus+ng)';
    elim_nodes = setdiff(all_nodes, gen_nodes);
    
    % --- Matrices réduites ---
    Ybus_pre_aug = buildYbusAugmented_06(nbus, ng, gen_bus, Ybus_load, Xd_prime);
    Yred_pre = kronReduction_06(Ybus_pre_aug, gen_nodes, elim_nodes);
    
    Y_infini = 1e10;
    Ybus_fault = Ybus_load;
    Ybus_fault(flt_bus, flt_bus) = Ybus_fault(flt_bus, flt_bus) + Y_infini;
    Ybus_fault_aug = buildYbusAugmented_06(nbus, ng, gen_bus, Ybus_fault, Xd_prime);
    Yred_fault = kronReduction_06(Ybus_fault_aug, gen_nodes, elim_nodes);
    
    R_fm = linedata(idx_fm, 3);
    X_fm = linedata(idx_fm, 4);
    B2_fm = linedata(idx_fm, 5);
    y_fm = 1 / (R_fm + 1j*X_fm);
    
    Ybus_post = Ybus_load;
    Ybus_post(flt_bus, flt_bus) = Ybus_load(flt_bus, flt_bus) - y_fm - 1j*B2_fm;
    Ybus_post(rem_bus, rem_bus) = Ybus_load(rem_bus, rem_bus) - y_fm - 1j*B2_fm;
    Ybus_post(flt_bus, rem_bus) = 0;
    Ybus_post(rem_bus, flt_bus) = 0;
    Ybus_post_aug = buildYbusAugmented_06(nbus, ng, gen_bus, Ybus_post, Xd_prime);
    Yred_post = kronReduction_06(Ybus_post_aug, gen_nodes, elim_nodes);
    
    % =====================================================================
    %% 4. PUISSANCE MECANIQUE Pm
    % =====================================================================
    Pm = zeros(ng,1);
    for k = 1:ng
        n = gen_bus(k);
        Pm(k) = busdata(n,7) / basemva;
    end
    
    % Generateur slack : Pm = Pe calculee en pre-defaut
    Pe0_slack = 0;
    for m = 1:ng
        Gkm = real(Yred_pre(1,m));
        Bkm = imag(Yred_pre(1,m));
        dkm = delta0(1) - delta0(m);
        Pe0_slack = Pe0_slack + E_prime(1)*E_prime(m)*(Gkm*cos(dkm)+Bkm*sin(dkm));
    end
    Pm(1) = Pe0_slack;
    
    % =====================================================================
    %% 5. SIMULATION PRINCIPALE (Euler modifié - pour les angles de base)
    % =====================================================================
    % Les équations du mouvement du rotor s'écrivent :
    %   d(delta)/dt = delta_omega          (écart de vitesse par rapport à ws)
    %   d(delta_omega)/dt = (Pm-Pe)*pi*f0/H
    % Conditions initiales : delta = delta0, delta_omega = 0 (synchronisme)
    % =====================================================================
    t = 0 : dt : T_max;
    nt = length(t);

    delta = delta0;
    delta_omega = zeros(ng,1);  % Écart de vitesse initiale = 0 (synchronisme)

    DELTA = zeros(ng, nt);
    OMEGA = zeros(ng, nt);
    DELTA(:,1) = delta;
    OMEGA(:,1) = delta_omega;   % Stockage de l'écart de vitesse (normalisé après)

    for ti = 2:nt
        t_cur = t(ti-1);
        
        if t_cur < T_cr
            Yr = Yred_fault;
        else
            Yr = Yred_post;
        end
        
        Pe = calcPe_06(delta, E_prime, Yr, ng);
        acc = (Pm - Pe) * (pi * f0) ./ H;
        
        % Prédicteur (Euler explicite)
        delta_p       = delta       + dt * delta_omega;
        delta_omega_p = delta_omega + dt * acc;
        
        if t(ti) < T_cr
            Yr_next = Yred_fault;
        else
            Yr_next = Yred_post;
        end
        
        Pe_p  = calcPe_06(delta_p, E_prime, Yr_next, ng);
        acc_p = (Pm - Pe_p) * (pi * f0) ./ H;
        
        % Correcteur (trapèze)
        delta       = delta       + (dt/2)*(delta_omega   + delta_omega_p);
        delta_omega = delta_omega + (dt/2)*(acc            + acc_p);
        
        DELTA(:,ti) = delta;
        OMEGA(:,ti) = delta_omega;
    end
    
    % =====================================================================
    %% 6. SIMULATION PRÉCISE POUR ANGLES RELATIFS (Runge-Kutta d'ordre 2)
    %%    Pas fixe dt_fine = 0.01s pour un rendu très fluide
    % =====================================================================
    dt_fine = 0.01;  % Pas fixe pour les angles relatifs
    t_fine = 0 : dt_fine : T_max;
    nt_fine = length(t_fine);

    delta_rk       = delta0;
    delta_omega_rk = zeros(ng,1);  % Écart de vitesse initiale = 0 (synchronisme)
    DELTA_RK = zeros(ng, nt_fine);
    DELTA_RK(:,1) = delta_rk;

    for ti = 2:nt_fine
        t_cur = t_fine(ti-1);
        
        % Choix de la matrice selon l'état du réseau
        if t_cur < T_cr
            Yr = Yred_fault;
        else
            Yr = Yred_post;
        end
        
        % ---- ETAPE 1 : Dérivées au début du pas ----
        Pe1  = calcPe_06(delta_rk, E_prime, Yr, ng);
        dd1  = delta_omega_rk;                          % d(delta)/dt = delta_omega
        dw1  = (Pm - Pe1) * (pi * f0) ./ H;            % d(delta_omega)/dt
        
        % ---- ETAPE 2 : Prédiction au milieu du pas ----
        delta_mid       = delta_rk       + (dt_fine/2) * dd1;
        delta_omega_mid = delta_omega_rk + (dt_fine/2) * dw1;
        
        % Choix de la matrice au milieu du pas
        t_mid = t_cur + dt_fine/2;
        if t_mid < T_cr
            Yr_mid = Yred_fault;
        else
            Yr_mid = Yred_post;
        end
        
        % ---- ETAPE 3 : Dérivées au milieu du pas ----
        Pe2  = calcPe_06(delta_mid, E_prime, Yr_mid, ng);
        dd2  = delta_omega_mid;                         % d(delta)/dt au milieu
        dw2  = (Pm - Pe2) * (pi * f0) ./ H;
        
        % ---- ETAPE 4 : Correction sur le pas entier ----
        delta_rk       = delta_rk       + dt_fine * dd2;
        delta_omega_rk = delta_omega_rk + dt_fine * dw2;
        
        DELTA_RK(:,ti) = delta_rk;
    end
    
    % =====================================================================
    %% PREPARATION DES RESULTATS POUR L'INTERFACE
    % =====================================================================
    results.t = t;
    results.delta = (DELTA * 180/pi)';           % Angles rotoriques [deg], (nt x ng)
    results.omega = (1 + OMEGA / ws)';           % Vitesse normalisée omega/omegas, (nt x ng)
    results.delta_rel = (DELTA_RK * 180/pi)';   % Angles absolus RK2 [deg], (nt_fine x ng)
    results.t_rel = t_fine;
    results.ng = ng;

end


% =========================================================================
%% FONCTIONS LOCALES
% =========================================================================

function Yb = calcul_Ybus_06(nbus, linedata, nbr)
    Yb = zeros(nbus, nbus);
    for k = 1:nbr
        nl = linedata(k,1);
        nr = linedata(k,2);
        R = linedata(k,3);
        X = linedata(k,4);
        B2 = linedata(k,5);
        tap = linedata(k,6);
        y = 1/(R + 1j*X);
        if tap == 1.0
            Yb(nl,nl) = Yb(nl,nl) + y + 1j*B2;
            Yb(nr,nr) = Yb(nr,nr) + y + 1j*B2;
            Yb(nl,nr) = Yb(nl,nr) - y;
            Yb(nr,nl) = Yb(nr,nl) - y;
        else
            Yb(nl,nl) = Yb(nl,nl) + y/tap^2;
            Yb(nr,nr) = Yb(nr,nr) + y;
            Yb(nl,nr) = Yb(nl,nr) - y/tap;
            Yb(nr,nl) = Yb(nr,nl) - y/tap;
        end
    end
end

function [V, S, iter, Ploss] = EP_Gauss_Seidel_06(busdata, linedata, basemva, accuracy, maxiter, nbr, accel)
    nbus = size(busdata,1);
    V = busdata(:,3) .* exp(1j * busdata(:,4) * pi/180);
    Ybus = calcul_Ybus_06(nbus, linedata, nbr);
    
    Psp = (busdata(:,7) - busdata(:,5)) / basemva;
    Qsp = (busdata(:,8) - busdata(:,6)) / basemva;
    
    Qmin = busdata(:,9) / basemva;
    Qmax = busdata(:,10) / basemva;
    
    iter = 0;
    tol = accuracy + 1;
    
    while tol > accuracy && iter < maxiter
        iter = iter + 1;
        V_old = V;
        
        for i = 1:nbus
            type = busdata(i,2);
            if type == 1, continue; end
            
            Iinj = 0;
            for j = 1:nbus
                if j ~= i
                    Iinj = Iinj + Ybus(i,j)*V(j);
                end
            end
            
            if type == 0
                V_new = (1/Ybus(i,i)) * (conj((Psp(i)+1j*Qsp(i))/V(i)) - Iinj);
                V(i) = V_old(i) + accel*(V_new - V_old(i));
            elseif type == 2
                Q_calc = imag(conj(V(i)) * (Ybus(i,:)*V));
                Q_calc = max(Qmin(i), min(Qmax(i), Q_calc));
                V_new = (1/Ybus(i,i)) * (conj((Psp(i)+1j*Q_calc)/V(i)) - Iinj);
                V_new = busdata(i,3) * V_new / abs(V_new);
                V(i) = V_old(i) + accel*(V_new - V_old(i));
            end
        end
        
        tol = max(abs(abs(V) - abs(V_old)));
    end
    
    I = Ybus * V;
    S = V .* conj(I);
    Ploss = sum(real(S)) * basemva;
end

function Yaug = buildYbusAugmented_06(nbus, ng, gen_bus, Ybus, Xd_prime)
    N = nbus + ng;
    Yaug = zeros(N, N);
    Yaug(1:nbus, 1:nbus) = Ybus;
    for k = 1:ng
        n = gen_bus(k);
        yg = 1 / (1j * Xd_prime(k));
        ni = nbus + k;
        Yaug(n, n) = Yaug(n, n) + yg;
        Yaug(ni, ni) = Yaug(ni, ni) + yg;
        Yaug(n, ni) = Yaug(n, ni) - yg;
        Yaug(ni, n) = Yaug(ni, n) - yg;
    end
end

function Yr = kronReduction_06(Y, keep_nodes, elim_nodes)
    order = [keep_nodes(:); elim_nodes(:)];
    Y_ord = Y(order, order);
    nk = length(keep_nodes);
    ne = length(elim_nodes);
    n = nk + ne;
    Y11 = Y_ord(1:nk, 1:nk);
    Y12 = Y_ord(1:nk, nk+1:n);
    Y21 = Y_ord(nk+1:n, 1:nk);
    Y22 = Y_ord(nk+1:n, nk+1:n);
    Yr = Y11 - Y12 * (Y22 \ Y21);
end

function Pe = calcPe_06(delta, E, Yr, ng)
    Pe = zeros(ng,1);
    for k = 1:ng
        for m = 1:ng
            Gkm = real(Yr(k,m));
            Bkm = imag(Yr(k,m));
            dkm = delta(k) - delta(m);
            Pe(k) = Pe(k) + E(k)*E(m)*(Gkm*cos(dkm) + Bkm*sin(dkm));
        end
    end
end