function Zbus = construire_Zbus_direct(nbus, linedata)
    % Initialisation
    Zbus = zeros(nbus, nbus);
    bus_connecte = false(1, nbus); % Suivi des bus intégrés au réseau
    nbr = size(linedata, 1);
    
    % On crée une copie de travail pour pouvoir supprimer les lignes traitées
    nl_w = linedata(:,1);
    nr_w = linedata(:,2);
    R = linedata(:,3);
    X = linedata(:,4);
    tap = linedata(:,6);
    Z_branch = (R + 1j*X);
    B_total=linedata(:,5);

       for i = 1:nbr
            if B_total(i) ~= 0
            % Modèle PI : B/2 de chaque côté
            z_sh = 1 / (1j * B_total(i)); 
            Zbus = ajouter_lien_terre(Zbus, nl_w(i), z_sh, bus_connecte);
            bus_connecte(nl_w(i)) = true;
            Zbus = ajouter_lien_terre(Zbus, nr_w(i), z_sh, bus_connecte);
            bus_connecte(nr_w(i)) = true;
            end
        end

    % --- ÉTAPE 2 : BRANCHES SÉRIE (Lignes et Transfos) ---
    traitees = false(1, nbr);
    while sum(traitees) < nbr
        changement = false;
        for i = 1:nbr
            if traitees(i), continue; end
            
            nl = nl_w(i); nr = nr_w(i); a = tap(i);
            zb = Z_branch(i);
            
            % Ajustement de l'impédance série pour le transformateur
            if a ~= 0 && a ~= 1
                zb = zb * a; 
            end
            
            % CAS 1 : Connexion d'un NOUVEAU bus à la RÉFÉRENCE (Bus 0)
            % (Dans linedata, supposons que Bus 0 est indiqué par nl=0 ou nr=0)
            if (nl == 0 || nr == 0)
                n_new = max(nl, nr);
                if ~bus_connecte(n_new)
                    Zbus(n_new, n_new) = zb;
                    bus_connecte(n_new) = true;
                    traitees(i) = true; changement = true;
                else
                    % CAS 3 : Connexion d'un bus EXISTANT à la RÉFÉRENCE
                    V = Zbus(:, n_new);
                    Z_denom = zb + Zbus(n_new, n_new);
                    Zbus = Zbus - (V * V.') / Z_denom;
                    traitees(i) = true; changement = true;
                end

            % CAS 2 : Connexion d'un NOUVEAU bus (nr) à un bus EXISTANT (nl)
            elseif (bus_connecte(nl) || bus_connecte(nr))
                % Cas 2 ou 4
                if bus_connecte(nl) && ~bus_connecte(nr)
                    % Cas 2 : Extension vers nr
                    Zbus(:, nr) = Zbus(:, nl);
                    Zbus(nr, :) = Zbus(nl, :);
                    Zbus(nr, nr) = Zbus(nl, nl) + zb;
                    bus_connecte(nr) = true;
                elseif bus_connecte(nr) && ~bus_connecte(nl)
                    % Cas 2 : Extension vers nl
                    Zbus(:, nl) = Zbus(:, nr);
                    Zbus(nl, :) = Zbus(nr, :);
                    Zbus(nl, nl) = Zbus(nr, nr) + zb;
                    bus_connecte(nl) = true;
                else
                    % Cas 4 : Boucle entre deux bus connectés
                    V = Zbus(:, nl) - Zbus(:, nr);
                    Z_loop = zb + Zbus(nl, nl) + Zbus(nr, nr) - 2*Zbus(nl, nr);
                    Zbus = Zbus - (V * V.') / Z_loop;
                end
                
                % --- AJOUT IMMÉDIAT DES SHUNTS DU TRANSFORMATEUR ---
                % Si c'est un transfo, on ajoute ses shunts maintenant que les bus sont reliés
                if a ~= 0 && a ~= 1
                    y_sh1 = (1-a)/(a^2 * Z_branch(i));
                    y_sh2 = (a-1)/(a * Z_branch(i));
                    Zbus = ajouter_lien_terre(Zbus, nl, 1/y_sh1, bus_connecte);
                    Zbus = ajouter_lien_terre(Zbus, nr, 1/y_sh2, bus_connecte);
                end
                
                traitees(i) = true; changement = true;
            end
        end
        if ~changement && sum(traitees) < nbr, error('Réseau déconnecté'); end
    end
    function Z = ajouter_lien_terre(Z, bus, z_sh, connecte)
    if ~connecte(bus)
        Z(bus, bus) = z_sh;
    else
        % Cas d'un bus déjà existant qu'on relie à la terre (Réduction de Kron)
        V = Z(:, bus);
        Z = Z - (V * V.') / (z_sh + Z(bus, bus));
    end
    end
 end
