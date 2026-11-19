function results = stabilite_transitoire_04(appData, noeud_defaut, T_clear, T_final, dt)
% =========================================================================
%  ANALYSE DE LA STABILITE TRANSITOIRE DES MACHINES SYNCHRONES
%  Version compatible avec l'interface MAIN
%  Methode : Euler modifiee + Reduction de Kron
% =========================================================================
%
% ENTREES :
%   appData       - structure contenant toutes les donnees du systeme
%   noeud_defaut  - numero du noeud en court-circuit
%   T_clear       - temps d'elimination du defaut [s]
%   T_final       - duree totale de simulation [s]
%   dt            - pas de temps [s]
%
% SORTIES :
%   results - structure contenant :
%     .t      - vecteur temps [s]
%     .delta  - angles rotoriques [deg]
%     .omega  - vitesses relatives [rad/s]
%     .Pe     - puissances electriques [p.u.]
% =========================================================================

    % =====================================================================
    %% RECUPERATION DES DONNEES
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
    
    % Parametres du systeme
    if isfield(appData, 'f0')
        f0 = appData.f0;
    else
        f0 = 60;  % Frequence nominale par defaut
    end
    ws = 2*pi*f0;   % vitesse synchrone electrique [rad/s]

    % =====================================================================
    %% PREPARATION DES DONNEES DE BUS
    % =====================================================================
    % Trier les noeuds par numero croissant
    [~, idx_sort] = sort(busdata(:,1));
    busdata = busdata(idx_sort,:);

    bus_no   = busdata(:,1);
    bus_type = busdata(:,2);   % 1=slack, 2=PV, 0=PQ
    Vmag0    = busdata(:,3);
    Vang0    = busdata(:,4) * pi/180;
    Pg_mw    = busdata(:,5);
    Qg_mvar  = busdata(:,6);
    Pl_mw    = busdata(:,7);
    Ql_mvar  = busdata(:,8);

    % Conversion en p.u.
    Pg = Pg_mw  / basemva;
    Qg = Qg_mvar / basemva;
    Pl = Pl_mw  / basemva;
    Ql = Ql_mvar / basemva;

    % Puissances nettes injectees (generation - charge)
    Psch = Pg - Pl;
    Qsch = Qg - Ql;

    % =====================================================================
    %% CONSTRUCTION DE Ybus
    % =====================================================================
    Ybus = construire_Ybus_04(bus_no, linedata, nbus);

    % =====================================================================
    %% ECOULEMENT DE PUISSANCE (Gauss-Seidel)
    % =====================================================================
    [V_pf, ~, ~] = gauss_seidel_EP_04(Ybus, Vmag0, Vang0, Psch, Qsch,...
                                       bus_type, nbus, accuracy, maxiter, accel);

    % =====================================================================
    %% CALCUL DES TENSIONS INTERNES E' ET ANGLES INITIAUX
    % =====================================================================
    ng = size(gendata, 1);
    gen_bus = gendata(:,1);
    gen_Xdp = gendata(:,3);
    gen_H = gendata(:,4);

    % Indices internes des noeuds generateurs
    gen_idx = zeros(ng,1);
    for i = 1:ng
        idx = find(bus_no == gen_bus(i));
        if isempty(idx)
            error('Generateur %d : noeud %d introuvable dans busdata.', i, gen_bus(i));
        end
        gen_idx(i) = idx;
    end

    % Tensions terminales apres ecoulement de puissance
    Et = V_pf(gen_idx);

    % Puissances generees
    Pg_gen = zeros(ng,1);
    Qg_gen = zeros(ng,1);
    for i = 1:ng
        gi = gen_idx(i);
        Pg_gen(i) = Pg(gi);
        Qg_gen(i) = Qg(gi);
    end

    % Courant terminal
    It = (Pg_gen - 1j*Qg_gen) ./ conj(Et);

    % Tension interne
    E_prime = Et + 1j * gen_Xdp .* It;
    Eprime_amp = abs(E_prime);
    delta0 = angle(E_prime);
    Pm = real(Et .* conj(It));

    % =====================================================================
    %% CONSTRUCTION DE LA YBUS AUGMENTEE
    % =====================================================================
    Ybus_aug = construire_Ybus_augmentee_04(Ybus, V_pf, busdata, bus_no,...
                                             gen_idx, gen_Xdp, ng, nbus, basemva);

    % Indices des noeuds generateurs internes
    gen_int_idx = (nbus + 1 : nbus + ng)';
    elim_idx = setdiff(1:(nbus+ng), gen_int_idx)';

    % Matrice reduite pre-defaut
    Ybus_reduit_prefault = reduction_kron_04(Ybus_aug, elim_idx, gen_int_idx);

    % =====================================================================
    %% MATRICES PENDANT DEFAUT
    % =====================================================================
    fault_idx = find(bus_no == noeud_defaut);
    if isempty(fault_idx)
        error('Noeud de defaut %d introuvable.', noeud_defaut);
    end

    % Pendant le defaut : mise en court-circuit
    Ybus_aug_fault = Ybus_aug;
    Y_cc = 1e8 + 1j*0;
    Ybus_aug_fault(fault_idx, fault_idx) = Ybus_aug_fault(fault_idx, fault_idx) + Y_cc;
    Ybus_reduit_fault = reduction_kron_04(Ybus_aug_fault, elim_idx, gen_int_idx);

    % =====================================================================
    %% PUISSANCES INITIALES
    % =====================================================================
    Pe_init = calc_Pe_reduit_04(Ybus_reduit_prefault, E_prime, delta0, Eprime_amp, ng);
    Pa_init = Pm - Pe_init;

    % =====================================================================
    %% SIMULATION TEMPORELLE
    % =====================================================================
    t_vec = 0 : dt : T_final;
    Nt = length(t_vec);
    M_gen = 2 * gen_H / ws;

    delta = zeros(ng, Nt);
    omega = zeros(ng, Nt);
    Pe = zeros(ng, Nt);
    
    delta(:,1) = delta0;
    omega(:,1) = ws * ones(ng,1);
    Pe(:,1) = Pe_init;
    
    Pa_cur = Pa_init;
    
    % Premiere etape speciale
    Pe_fault0 = calc_Pe_reduit_04(Ybus_reduit_fault, E_prime, delta0, Eprime_amp, ng);
    Pa_fault0 = Pm - Pe_fault0;
    Pa_cur = 0.5 * (Pa_init + Pa_fault0);
    
    % Boucle principale
    for k = 2 : Nt
        t_cur = t_vec(k);
        in_fault = (t_cur <= T_clear + dt/2);
        
        if in_fault
            Yr = Ybus_reduit_fault;
        else
            Yr = Ybus_reduit_prefault;
        end
        
        % Prediction
        dw_prev = (pi * f0 ./ gen_H) .* Pa_cur;
        dd_prev = omega(:,k-1) - ws;
        
        omega_pred = omega(:,k-1) + dw_prev * dt;
        delta_pred = delta(:,k-1) + dd_prev * dt;
        
        % Correction
        E_pred = Eprime_amp .* exp(1j * delta_pred);
        Pe_pred = calc_Pe_reduit_04(Yr, E_pred, delta_pred, Eprime_amp, ng);
        Pa_pred = Pm - Pe_pred;
        
        dw_pred = (pi * f0 ./ gen_H) .* Pa_pred;
        dd_pred = omega_pred - ws;
        
        omega(:,k) = omega(:,k-1) + 0.5 * (dw_prev + dw_pred) * dt;
        delta(:,k) = delta(:,k-1) + 0.5 * (dd_prev + dd_pred) * dt;
        
        % Valeurs finales
        E_cur = Eprime_amp .* exp(1j * delta(:,k));
        Pe(:,k) = calc_Pe_reduit_04(Yr, E_cur, delta(:,k), Eprime_amp, ng);
        Pa_cur = Pm - Pe(:,k);
    end

    % =====================================================================
    %% PREPARATION DES RESULTATS
    % =====================================================================
    results.t = t_vec(:)';  % Force en vecteur ligne
    results.delta = (delta * 180/pi)';  % Transpose: temps en lignes, generateurs en colonnes
    results.omega = (omega / ws)';       % Transpose: temps en lignes, generateurs en colonnes
    results.Pe = Pe';

end  % Fin de la fonction principale


% =========================================================================
%% FONCTIONS LOCALES
% =========================================================================

function Ybus = construire_Ybus_04(bus_no, linedata, nbus)
    Ybus = zeros(nbus, nbus);
    for k = 1 : size(linedata, 1)
        nl   = linedata(k,1);
        nr   = linedata(k,2);
        R    = linedata(k,3);
        X    = linedata(k,4);
        Bc2  = linedata(k,5);
        tap  = linedata(k,6);
        
        y_ser = 1 / (R + 1j*X);
        
        i = find(bus_no == nl);
        j = find(bus_no == nr);
        if isempty(i) || isempty(j), continue; end
        
        if abs(tap - 1.0) < 1e-6
            Ybus(i,i) = Ybus(i,i) + y_ser + 1j*Bc2;
            Ybus(j,j) = Ybus(j,j) + y_ser + 1j*Bc2;
            Ybus(i,j) = Ybus(i,j) - y_ser;
            Ybus(j,i) = Ybus(j,i) - y_ser;
        else
            Ybus(i,i) = Ybus(i,i) + y_ser / tap^2;
            Ybus(j,j) = Ybus(j,j) + y_ser;
            Ybus(i,j) = Ybus(i,j) - y_ser / tap;
            Ybus(j,i) = Ybus(j,i) - y_ser / tap;
        end
    end
end

function [V, iter, converged] = gauss_seidel_EP_04(Ybus, Vmag0, Vang0,...
                                                     Psch, Qsch, bus_type,...
                                                     nbus, tol, maxiter, accel)
    V = Vmag0 .* exp(1j * Vang0);
    converged = false;
    iter = 0;
    
    for it = 1 : maxiter
        V_old = V;
        
        for i = 1 : nbus
            if bus_type(i) == 1, continue; end
            
            if bus_type(i) == 2
                Q_calc = -imag(conj(V(i)) * (Ybus(i,:) * V));
                S_i = Psch(i) - 1j * Q_calc;
            else
                S_i = Psch(i) - 1j * Qsch(i);
            end
            I_inj = conj(S_i / V(i));
            
            sum_YV = Ybus(i,:) * V - Ybus(i,i) * V(i);
            V_new = (I_inj - sum_YV) / Ybus(i,i);
            
            if bus_type(i) == 2
                V_new = abs(V_old(i)) * V_new / abs(V_new);
            end
            
            V(i) = V_old(i) + accel * (V_new - V_old(i));
            if bus_type(i) == 2
                V(i) = abs(V_old(i)) * V(i) / abs(V(i));
            end
        end
        
        iter = it;
        if max(abs(V - V_old)) < tol
            converged = true;
            break;
        end
    end
end

function Ybus_aug = construire_Ybus_augmentee_04(Ybus, V_pf, busdata, bus_no,...
                                                  gen_idx, gen_Xdp, ng, nbus, basemva)
    Ntot = nbus + ng;
    Ybus_aug = zeros(Ntot, Ntot);
    Ybus_aug(1:nbus, 1:nbus) = Ybus;
    
    % Conversion des charges en admittances shunt
    for k = 1 : nbus
        Pl_k = busdata(k, 7) / basemva;
        Ql_k = busdata(k, 8) / basemva;
        if abs(Pl_k) + abs(Ql_k) < 1e-10, continue; end
        Vk_sq = abs(V_pf(k))^2;
        if Vk_sq < 1e-10, Vk_sq = 1.0; end
        Y_load = (Pl_k - 1j*Ql_k) / Vk_sq;
        Ybus_aug(k, k) = Ybus_aug(k, k) + Y_load;
    end
    
    % Ajout des noeuds internes generateurs
    for i = 1 : ng
        gi = gen_idx(i);
        ni = nbus + i;
        Yd = 1 / (1j * gen_Xdp(i));
        
        Ybus_aug(ni, ni) = Yd;
        Ybus_aug(gi, gi) = Ybus_aug(gi, gi) + Yd;
        Ybus_aug(ni, gi) = -Yd;
        Ybus_aug(gi, ni) = -Yd;
    end
end

function Yr = reduction_kron_04(Y, elim_idx, keep_idx)
    Yr = Y;
    remaining = 1 : size(Y, 1);
    
    for p = elim_idx'
        pos_p = find(remaining == p);
        if isempty(pos_p), continue; end
        
        Ypp = Yr(p, p);
        if abs(Ypp) < 1e-12, continue; end
        
        indices = remaining(remaining ~= p);
        for ii = indices
            for jj = indices
                Yr(ii, jj) = Yr(ii, jj) - Yr(ii, p) * Yr(p, jj) / Ypp;
            end
        end
    end
    
    Yr = Yr(keep_idx, keep_idx);
end

function Pe = calc_Pe_reduit_04(Yr, E_gen, delta_gen, Eprime_amp, ng)
    E_vec = Eprime_amp .* exp(1j * delta_gen);
    Pe = zeros(ng, 1);
    for i = 1 : ng
        S_i = E_vec(i) * conj(Yr(i,:) * E_vec);
        Pe(i) = real(S_i);
    end
end