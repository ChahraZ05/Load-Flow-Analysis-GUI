function [V, delta, iter, Ploss]= EP_Gauss_Seidel(busdata, linedata, basemva, accuracy, maxiter, nbr, accel)
    % 1. PRÉPARATION DES DONNÉES
    nbus = size(busdata, 1);
    accuracy=accuracy/1000;
    delta= deg2rad(busdata(:,4));
    V = busdata(:, 3) .* exp(1j * deg2rad(busdata(:, 4))); 
    
    Pspec = (busdata(:, 7) - busdata(:, 5)) ./ basemva;
    Qspec = (busdata(:, 8) - busdata(:, 6) + busdata(:,11)) ./ basemva;

    Pload= busdata(:,5)./basemva;
    Qload= busdata(:,6)./basemva;
    Pgen= busdata(:,7)./basemva;
    Qgen= busdata(:,8)./basemva;
    Qmin= busdata(:,9)./basemva;
    Qmax= busdata(:,10)./basemva;
    Qcap= busdata(:,11)./basemva;
    
    
    % 2. CONSTRUCTION DE LA MATRICE YBUS
    Ybus = calcul_Ybus(nbus, linedata, nbr);

    % 3. BOUCLE ITÉRATIVE
    iter = 0;
    converged = false;
    while ~converged && iter < maxiter
        V_old = V;
        for i = 1:nbus
            type = busdata(i, 2); 
            if type == 1, continue; end
            
            sum_YV = Ybus(i, :) * V - Ybus(i, i) * V(i);

            if type == 0 % Nœud PQ
                V(i) = (1 / Ybus(i, i)) * ((Pspec(i) - 1j * Qspec(i)) / conj(V(i)) - sum_YV);
                V(i)= V_old(i) + accel*(V(i)-V_old(i));
            else % Nœud PV
                Qi_calc = -imag(conj(V(i)) * (sum_YV + Ybus(i,i)*V(i)));
                V_temp = (1 / Ybus(i, i)) * ((Pspec(i) - 1j * Qi_calc) / conj(V(i)) - sum_YV);
                V(i) = abs(busdata(i, 3)) * (V_temp / abs(V_temp));
            end
        end
        if max(abs(V - V_old)) < accuracy, converged = true; end
        iter = iter + 1;
    end

    % --- NOUVELLE PARTIE : CALCULS DES PUISSANCES ET AFFICHAGE DU TABLEAU ---
    % Calcul de l'injection de puissance complexe à chaque nœud : S = V * conj(I)
    % I = Ybus * V
    S_net_pu = V .* conj(Ybus * V);
    P_net_mw = real(S_net_pu) * basemva;
    Q_net_mvar = imag(S_net_pu) * basemva;

    % Initialisation des colonnes de génération (Pgen, Qgen)
    % Pgen = Pcalc + Pload | Qgen = Qcalc + Qload - Qcap
    Pgen=zeros(nbus,1);
    Qgen=zeros(nbus,1);
    for i=1:nbus
        type = busdata(i,2);
        if type==1
            S1=0;
            for j=1:nbus
                S1= S1+ Ybus(1,j)*V(j)*conj(V(1));
            end
            Pgen(i)= P_net_mw(i) + Pload(i)*basemva;
            Qgen(i)= Q_net_mvar(i) + Qload(i)*basemva; 
        end

        if type==2
            Pgen(i) = P_net_mw(i) + Pload(i)*basemva;
            Qgen(i) = Q_net_mvar(i) + Qload(i)*basemva - Qcap(i)*basemva;
        end

        if type==0
            Pgen(i) = busdata(i,7);
            Qgen(i)=busdata(i,8);
        end
    end

    % Affichage de l'en-tête du tableau
    fprintf("\n * * * * * * * * * * * * * * * * * Calcul de l'Ecoulement de puissance * * * * * * * * * * * * * * * * * \n");
    fprintf("                                        Methode de Gauss - Seidel \n");
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
            rad2deg(angle(V(i))),...% Degree
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