function [V, delta, iter, Ploss]=EP_FDLF(busdata, linedata, basemva, accuracy, maxiter)
    % 1. Initialisation et Paramètres
    nbus = size(busdata, 1);
    nligne = size(linedata, 1);
    
    % Identification des types de nœuds selon vos codes (1:Slack, 2:PV, 0:PQ)
    slack_idx = find(busdata(:, 2) == 1);
    pv_idx = find(busdata(:, 2) == 2);
    pq_idx = find(busdata(:, 2) == 0);
    non_slack = [pv_idx; pq_idx]; % Pour Delta P
    
    % Initialisation V et Delta
    V = busdata(:, 3);
    delta = deg2rad(busdata(:, 4));
    
    % Puissances spécifiées en pu : (Pgen - Pload) / base
    % busdata: 5:Pload, 6:Qload, 7:Pgen, 8:Qgen, 11:Qc
    Pspec = (busdata(:, 7) - busdata(:, 5)) / basemva;
    Qspec = (busdata(:, 8) - busdata(:, 6) + busdata(:, 11)) / basemva;

    % 2. Construction de la matrice Ybus (avec transformateurs)
    Ybus = zeros(nbus, nbus);
    for k = 1:nligne
        n1 = linedata(k, 1); n2 = linedata(k, 2);
        R = linedata(k, 3); X = linedata(k, 4);
        Bc = 1j * linedata(k, 5); % Susceptance shunt (B/2)
        a = linedata(k, 6);       % Tap ratio
        
        y_serie = 1 / (R + 1j*X);
        
        if a <= 0, a = 1; end % Sécurité
        
        % Modèle en Pi pour transformateur avec réglage en phase
        % (Ici traité comme transformateur de réglage de magnitude standard)
        Ybus(n1,n1) = Ybus(n1,n1) + (y_serie / (a^2)) + Bc;
        Ybus(n2,n2) = Ybus(n2,n2) + y_serie + Bc;
        Ybus(n1,n2) = Ybus(n1,n2) - (y_serie / a);
        Ybus(n2,n1) = Ybus(n1,n2);
    end
    G = real(Ybus); B = imag(Ybus);

    % 3. Matrices B' et B'' (FDLF - Stott & Alsac)
    % On ignore les résistances et les shunts pour B' et B'' selon la méthode pure
    % Mais l'implémentation standard utilise -imag(Ybus)
    B_prime = -B(non_slack, non_slack);
    B_double_prime = -B(pq_idx, pq_idx);

    % 4. Boucle de calcul
    iter = 0; converged = false;
    while iter < maxiter && ~converged
        iter = iter + 1;
        
        % --- Calcul des puissances injectées ---
        P = zeros(nbus, 1); Q = zeros(nbus, 1);
        for i = 1:nbus
            for j = 1:nbus
                d_ij = delta(i) - delta(j);
                P(i) = P(i) + V(i)*V(j)*(G(i,j)*cos(d_ij) + B(i,j)*sin(d_ij));
                Q(i) = Q(i) + V(i)*V(j)*(G(i,j)*sin(d_ij) - B(i,j)*cos(d_ij));
            end
        end
        
        % --- Écart P et Mise à jour des Angles ---
        dP = Pspec(non_slack) - P(non_slack);
        if max(abs(dP)) > accuracy
            dDelta = B_prime \ (dP ./ V(non_slack));
            delta(non_slack) = delta(non_slack) + dDelta;
        end
        
        % --- Recalcul de Q avec nouveaux angles ---
        Q_new = zeros(nbus, 1);
        for i = pq_idx'
            for j = 1:nbus
                d_ij = delta(i) - delta(j);
                Q_new(i) = Q_new(i) + V(i)*V(j)*(G(i,j)*sin(d_ij) - B(i,j)*cos(d_ij));
            end
        end
        
        % --- Écart Q et Mise à jour des Tensions ---
        dQ = Qspec(pq_idx) - Q_new(pq_idx);
        if max(abs(dQ)) > accuracy
            dV = B_double_prime \ (dQ ./ V(pq_idx));
            V(pq_idx) = V(pq_idx) + dV;
        end
        
        % --- Convergence ---
        if max(abs(dP)) < accuracy && max(abs(dQ)) < accuracy
            converged = true;
        end
    end

    % 5. Calcul des résultats finaux (Pgen, Qgen)
    V_complex = V .* exp(1j * delta);
    S_inj = V_complex .* conj(Ybus * V_complex) * basemva;
    Pgen = real(S_inj) + busdata(:, 5);
    Qgen = imag(S_inj) + busdata(:, 6) - busdata(:, 11);

    % 6. Affichage (Format demandé)
    fprintf("\n * * * * * * * * * * * * * * * * * Calcul de l'Ecoulement de puissance * * * * * * * * * * * * * * * * * \n");
    fprintf("                                             Methode de la FDLF \n");
    fprintf('\n------------------------------------------- RÉSULTATS FINAUX ------------------------------------------- \n');
    fprintf("                                       Le nombre d'iterations : %d \n", iter);
    fprintf('\nBus     Bus      Voltage       Angle              -------Load-------                --------Generator-------\n');
    fprintf('No      code       Amp          Deg                MW           Mvar                MW                  Mvar\n');
    fprintf('                                                  Pload         Qload              Pgen                 Qgen\n');
    fprintf('------------------------------------------------------------------------------------------------------------\n');

    for i = 1:nbus
        fprintf('%2d     %2d     %9.4f     %9.4f          %8.2f      %8.2f          %9.2f           %9.2f\n', ...
            busdata(i, 1), ...      % No
            busdata(i, 2), ...      % Code
            abs(V(i)), ...          % Amp
            rad2deg(delta(i)),...% Degree
            busdata(i, 5), ...      % Pload (MW)
            busdata(i, 6), ...      % Qload (Mvar)
            Pgen(i), ...            % Pgen (MW)
            Qgen(i));               % Qgen (Mvar)
    end
    fprintf('------------------------------------------------------------------------------------------------------------');
    SIGMA = char(931);
    fprintf('\n                                                 %sPload         %sQload             %sPgen               %sQgen\n', SIGMA, SIGMA, SIGMA, SIGMA);
    sum_Pload=0;
    sum_Qload=0;
    sum_Pgen=0;
    sum_Qgen=0;
    for i=1:nbus
        sum_Pload=sum_Pload + busdata(i, 5);
        sum_Qload=sum_Qload + busdata(i, 6);
        sum_Pgen=sum_Pgen + Pgen(i);
        sum_Qgen=sum_Qgen + Qgen(i);
    end
    fprintf('                                               %8.2f       %8.2f          %9.2f          %9.2f \n', sum_Pload, sum_Qload, sum_Pgen, sum_Qgen);
    fprintf('------------------------------------------------------------------------------------------------------------\n');
    Ploss= sum_Pgen - sum_Pload;
    Ploss_perc= (Ploss / sum_Pgen) * 100;
    Qloss= sum_Qgen - sum_Qload;
    fprintf('\n ------------------------------------------- CALCUL DES PERTES ------------------------------------------- \n');
    fprintf('\n *** Les pertes actives: *** \n');
    fprintf('Ploss = %sPgen - %sPload = %9.2f - %8.2f = %8.2f (MW)\n',SIGMA,SIGMA, sum_Pgen, sum_Pload, Ploss);
    fprintf('Ploss (%%) = (Ploss / %sPgen) x 100 = (%8.2f / %9.2f) x 100 = %.2f (%%) \n',SIGMA, Ploss, sum_Pgen, Ploss_perc');
    fprintf('\n *** Les pertes reactives: *** \n');
    fprintf('Qloss = %sQgen - %sQload = %9.2f - %8.2f = %8.2f (MVAR)\n',SIGMA,SIGMA, sum_Qgen, sum_Qload, Qloss);
end