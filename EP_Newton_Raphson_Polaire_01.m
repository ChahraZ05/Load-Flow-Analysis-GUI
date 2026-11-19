function [V, delta, iter, Ploss]=EP_Newton_Raphson_Polaire_01(nbus, busdata, accuracy, maxiter, nbr, npq, linedata, basemva)
    % --- Initialisation des variables (Coordonnées Polaires) ---
    Ybus = calcul_Ybus(nbus, linedata, nbr);
    V = busdata(:, 3);        % Module de tension (Colonne 3 selon votre hs05bus.m)
    delta = busdata(:, 4);    % Angle en Degrés (Colonne 4)
    delta = deg2rad(delta);   % Conversion en Radians pour les calculs
    type = busdata(:, 2);     % Code Bus (1=Slack, 2=PV, 0=PQ)
    
    % Puissances spécifiées (Pload/Qload sont aux colonnes 5/6 ou 7/8 selon le fichier)
    % On adapte ici aux colonnes standard ENP : 5=Pload, 6=Qload, 7=Pgen, 8=Qgen
    P_spec = (busdata(:, 7) - busdata(:, 5)) / basemva; 
    Q_spec = (busdata(:, 8) - busdata(:, 6) + busdata(:,11)) / basemva; 
    
    pq = find(type == 0); % Nœuds PQ
    
    G = real(Ybus);
    B = -imag(Ybus);
    theta = -angle(Ybus);
    Y_abs = abs(Ybus);
    
    dim = nbus - 1; % Dimension pour (n-1) angles et (n-1) modules

    for iter = 1:maxiter
        % 1. Calcul des puissances injectées (P_cal, Q_cal)
        P_cal = zeros(nbus, 1);
        Q_cal = zeros(nbus, 1);
        for i = 1:nbus
            for j = 1:nbus
                arg = theta(i,j) + delta(i) - delta(j); %
                P_cal(i) = P_cal(i) + V(i)*V(j)*Y_abs(i,j)*cos(arg);
                Q_cal(i) = Q_cal(i) + V(i)*V(j)*Y_abs(i,j)*sin(arg);
            end
        end

        % 2. Calcul des résidus (Mismatches)
        dP = P_spec(2:end) - P_cal(2:end);
        dQ_all = Q_spec(2:end) - Q_cal(2:end); % On prend tous les dQ pour la matrice augmentée
        
        % Critère de convergence (Uniquement sur P et Q des nœuds PQ)
        % On extrait les indices PQ relatifs (i-1)
        idx_pq_rel = pq - 1;
        if max([abs(dP); abs(dQ_all(idx_pq_rel))]) < accuracy
            break;
        end

        % 3. Construction de la Matrice Jacobienne (Forme Augmentée 2n-2)
        Jac = zeros(2*dim, 2*dim);

        for i = 2:nbus
            for j = 2:nbus
                ii = i - 1;
                jj = j - 1;
                arg = theta(i,j) + delta(i) - delta(j);
                
                if i == j
                    % J1 : dP/ddelta
                    Jac(ii, jj) = -Q_cal(i) + V(i)^2 * B(i,i);
                    % J2 : dP/dV
                    Jac(ii, jj+dim) = P_cal(i)/V(i) + 2*V(i)*G(i,i);
                    % J3 : dQ/ddelta
                    Jac(ii+dim, jj) = Q_cal(i) - V(i)^2 * G(i,i);
                    % J4 : dQ/dV
                    Jac(ii+dim, jj+dim) = Q_cal(i)/V(i) + 2*V(i)*B(i,i);
                else
                    % Hors-diagonale
                    Jac(ii, jj) = V(i)*V(j)*Y_abs(i,j)*sin(arg);           % J1
                    Jac(ii, jj+dim) = V(i)*Y_abs(i,j)*cos(arg);            % J2
                    Jac(ii+dim, jj) = -V(i)*V(j)*Y_abs(i,j)*cos(arg);      % J3
                    Jac(ii+dim, jj+dim) = V(i)*Y_abs(i,j)*sin(arg);       % J4
                end
            end
        end

        % --- APPLICATION DES CONTRAINTES PV (J5 et J6) ---
        dQ_mod = dQ_all;
        for i = 2:nbus
            if type(i) == 2 % Nœud PV
                idx_row = (i-1) + dim;
                
                % J5 : d|Vi|/ddelta = 0
                Jac(idx_row, 1:dim) = 0;
                
                % J6 : d|Vi|/d|Vj| = 1 si i=j
                Jac(idx_row, dim+1:end) = 0;
                Jac(idx_row, idx_row) = 1;
                
                % Mismatch : dV = 0 pour les nœuds PV
                dQ_mod(i-1) = 0;
            end
        end

        % 4. Résolution et Mise à jour
        dX = Jac \ [dP; dQ_mod];
        
        delta(2:end) = delta(2:end) + dX(1:dim);
        V(2:end) = V(2:end) + dX(dim+1:end);
    end

    % --- CALCUL DES PUISSANCES GÉNÉRÉES ET PERTES ---
    % Re-calcul final des injections
    P_final = zeros(nbus, 1); Q_final = zeros(nbus, 1);
    for i = 1:nbus
        for j = 1:nbus
            arg = theta(i,j) + delta(i) - delta(j);
            P_final(i) = P_final(i) + V(i)*V(j)*Y_abs(i,j)*cos(arg);
            Q_final(i) = Q_final(i) + V(i)*V(j)*Y_abs(i,j)*sin(arg);
        end
    end

    Pload = busdata(:, 5); Qload = busdata(:, 6);
    Pgen = (P_final * basemva) + Pload;
    Qgen = (Q_final * basemva) + Qload - busdata(:,11);

    % --- AFFICHAGE DES RÉSULTATS ---
    fprintf("\n * * * * * * * * * * * * * * * * * Calcul de l'Ecoulement de puissance * * * * * * * * * * * * * * * * * \n");
    fprintf("                            Methode de Newton - Raphson en Coordonnées polaires 01 \n");
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