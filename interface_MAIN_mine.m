function interface_MAIN_mine()
    set(0, 'DefaultFigureVisible', 'on');
    
    BASE_DIR = fileparts(mfilename('fullpath'));

    largeur_fig = 1400; hauteur_fig = 800;
    screen_size = get(0, 'ScreenSize');
    pos_x = (screen_size(3)-largeur_fig)/2;
    pos_y = (screen_size(4)-hauteur_fig)/2;
    
    f = uifigure('Name', 'LOGICIEL DE CALCUL DE RESEAU ELECTRIQUES - ENP', ...
                 'Position', [pos_x, pos_y, largeur_fig, hauteur_fig], ...
                 'Color', [1 1 1], ...
                 'Resize', 'off');
    movegui(f, 'center');
             
    appData = struct('isLoaded', false);

    % --- PANNEAU DE CONTRÔLE (GAUCHE) ---
    pMenu = uipanel(f, 'Position', [0 0 350 800], 'BackgroundColor', [0.98 0.97 0.95], 'BorderType', 'none');
    
    % --- CHARGEMENT ---
    uilabel(pMenu, 'Text', 'CHARGER LE SYSTEME', ...
            'Position', [20 730 310 30], 'FontWeight', 'bold', 'FontSize', 15);
    uilabel(pMenu, 'Text', 'Sélectionner le système :', ...
            'Position', [20 707 310 22], 'FontSize', 13);

     try
        fichiers_disponibles = scanner_dossier(BASE_DIR);
    catch
        fichiers_disponibles = {};
    end
    
    % Ajouter un placeholder "-- Sélectionner un système --" en premier élément
    if isempty(fichiers_disponibles)
        fichiers_disponibles = {'-- Aucun fichier trouvé --'};
    else
        fichiers_disponibles = ['-- Sélectionner un système --', fichiers_disponibles];
    end

    ddSystem = uidropdown(pMenu, ...
        'Items', fichiers_disponibles, ...
        'Position', [20 670 310 30], ...
        'FontSize', 10, ...
        'Value', fichiers_disponibles{1}, ...  % Sélectionne le placeholder par défaut
        'ValueChangedFcn', @cbAutoLoadSystem);  % Chargement auto à la sélection

    % --- CALCUL DES MATRICES ---
    uilabel(pMenu, 'Text', 'CALCUL DES MATRICES', ...
            'Position', [20 600 310 30], 'FontWeight', 'bold');
    uibutton(pMenu, 'Text', 'Ybus',        'Position', [20 563 310 33],'BackgroundColor', [0.7 0.9 0.7], 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) runMatrix('Ybus'));
    uibutton(pMenu, 'Text', 'Zbus',        'Position', [20 523 310 33],'BackgroundColor', [0.7 0.9 0.7], 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) runMatrix('Zbus'));
    uibutton(pMenu, 'Text', 'Ybus * Zbus', 'Position', [20 483 310 33],'BackgroundColor', [0.7 0.9 0.7], 'FontWeight', 'bold', 'ButtonPushedFcn', @cbTestYZ);
    
    % --- ECOULEMENT DE PUISSANCE ---
    uilabel(pMenu, 'Text', 'ECOULEMENT DE PUISSANCE', ...
            'Position', [20 412 310 30], 'FontWeight', 'bold');

    uibutton(pMenu, 'Text', 'Gauss-Seidel', ...
             'Position', [20 375 310 33], ...
             'BackgroundColor', [0.8 0.9 1], ...
             'FontWeight', 'bold', ...
             'ButtonPushedFcn', @(~,~) runEP('Gauss-Seidel'));

    uibutton(pMenu, 'Text', 'Newton-Raphson', ...
             'Position', [20 338 310 33], ...
             'BackgroundColor', [0.8 0.9 1], ...
             'FontWeight', 'bold', ...
             'ButtonPushedFcn', @(~,~) runEP('Newton-Raphson'));

    uibutton(pMenu, 'Text', 'FDLF', ...
             'Position', [20 301 310 33], ...
             'BackgroundColor', [0.8 0.9 1], ...
             'FontWeight', 'bold', ...
             'ButtonPushedFcn', @(~,~) runEP('FDLF'));

    uibutton(pMenu, 'Text', '📊 Comparaison', ...
             'Position', [20 260 310 33], ...
             'BackgroundColor', [0.9 0.8 1], ...
             'FontWeight', 'bold', ...
             'ButtonPushedFcn', @cbRunComparison);

    % --- STABILITE ---
    uilabel(pMenu, 'Text', 'STABILITE DES SYSTEMES', ...
            'Position', [20 180 310 33], 'FontWeight', 'bold');
    uibutton(pMenu, 'Text', '⚡ Stabilité Transitoire', ...
             'Position', [20 143 310 33], ...
             'BackgroundColor', [1 0.9 0.7], ...
             'FontWeight', 'bold', ...
             'ButtonPushedFcn', @cbOuvrirStabilite);
    
    % --- RETOUR / QUITTER ---
    uibutton(pMenu, 'Text', '↩ Retour',   'Position', [20  70 150 40], 'ButtonPushedFcn', @cbReset);
    uibutton(pMenu, 'Text', '❌ Quitter', 'Position', [180 70 150 40], ...
             'BackgroundColor', [1 0.8 0.8], 'ButtonPushedFcn', @(~,~) close(f));

    % --- ZONE D'AFFICHAGE (DROITE) ---
    pDisplay = uipanel(f, 'Position', [350 0 1050 800], 'BackgroundColor', [0.9 0.9 0.9], 'BorderType', 'none');
    txtArea = uitextarea(pDisplay, 'Position', [40 40 970 720], 'Visible', 'on', ...
                         'FontName', 'Consolas', 'FontSize', 15, ...  % ← Changé de 10 à 13
                         'Value', {'Veuillez sélectionner un système et cliquer sur Charger.'});
    axContainer = uipanel(pDisplay, 'Position', [0 0 1050 800], 'Visible', 'off', ...
                          'BackgroundColor', [0.9 0.9 0.9], 'BorderType', 'none');

    % =========================================================
    % --- CALLBACKS D'ORIGINE ---
    % =========================================================

            function cbAutoLoadSystem(~, ~)
        selected = ddSystem.Value;
        % Ignorer le placeholder et les messages d'erreur
        if strcmp(selected, '-- Sélectionner un système --') || ...
           strcmp(selected, '-- Aucun fichier trouvé --') || ...
           isempty(selected)
            return;
        end
        full_path = fullfile(BASE_DIR, selected);
        if ~isfile(full_path)
            showInGrayZone(sprintf('❌ Fichier introuvable :\n%s', full_path), 'err');
            return;
        end
        try
            data = charger_donnees_systeme(full_path);
            appData = data;
            appData.isLoaded = true;
            appData.fileName = selected;
            showInGrayZone(sprintf(['✅ Système chargé : %s\n\n' ...
                                    '📊 Nombre de nœuds : %d\n' ...
                                    '🔗 Nombre de branches : %d'], ...
                                    selected, data.nbus, data.nbr), 'success');
        catch ME
            showInGrayZone(['❌ Erreur de chargement : ' ME.message], 'err');
        end
    end

        function runMatrix(type)
        if ~appData.isLoaded
            showInGrayZone('Erreur : Aucun système chargé.', 'err');
            return;
        end
        try
            if strcmp(type, 'Ybus')
                res      = calcul_Ybus(appData.nbus, appData.linedata, appData.nbr);
                titleStr = sprintf('MATRICE ADMITTANCE NODALE (Ybus)   %d × %d nœuds', ...
                                   appData.nbus, appData.nbus);
                ttype    = 'complex';
            else
                res      = construire_Zbus_direct(appData.nbus, appData.linedata);
                titleStr = sprintf('MATRICE IMPEDANCE NODALE (Zbus)   %d × %d nœuds', ...
                                   appData.nbus, appData.nbus);
                ttype    = 'complex';   % ← Changé de 'real' à 'complex'
            end

            resetRightZone();
            axContainer.Visible = 'on';
            afficher_matrice_uitable(axContainer, res, titleStr, ttype);

        catch ME
            showInGrayZone(['Erreur lors du calcul : ' ME.message], 'err');
        end
        end  

    function cbTestYZ(~, ~)
        if ~appData.isLoaded
            showInGrayZone('Erreur : Aucun système chargé.', 'err');
            return;
        end
        try
            Y    = calcul_Ybus(appData.nbus, appData.linedata, appData.nbr);
            Z    = construire_Zbus_direct(appData.nbus, appData.linedata);
            prod = Y * Z;
            err  = max(max(abs(prod - eye(appData.nbus))));

            status_txt = 'RESULTAT TEST Ybus x Zbus | ';
            titleStr = sprintf('%s  (erreur max = %.2e)  |  Y × Z  doit être = Identité', ...
                               status_txt, err);

            resetRightZone();
            axContainer.Visible = 'on';
            afficher_matrice_uitable(axContainer, prod, titleStr, 'real');

        catch ME
            showInGrayZone(['Erreur test YZ : ' ME.message], 'err');
        end
    end

        function runEP(method)
        if ~appData.isLoaded
            showInGrayZone('Erreur : Aucun système chargé.', 'err');
            return;
        end
        resetRightZone();
        txtArea.Visible = 'on';
        txtArea.Value = {['⏳ Calcul en cours avec la méthode : ' method ' ...']};
        drawnow;
        try
            % Créer un fichier temporaire pour capturer la sortie
            tempFile = [tempname '.txt'];
            diary(tempFile);
            
            switch method
                case 'Gauss-Seidel'
                    EP_Gauss_Seidel(appData.busdata, appData.linedata, appData.basemva, appData.accuracy, appData.maxiter, appData.nbr, appData.accel);
                case 'Newton-Raphson'
                    EP_Newton_Raphson_Polaire_01(appData.nbus, appData.busdata, appData.accuracy, appData.maxiter, appData.nbr, appData.npq, appData.linedata, appData.basemva);
                case 'FDLF'
                    EP_FDLF(appData.busdata, appData.linedata, appData.basemva, appData.accuracy, appData.maxiter);
            end
            
            diary off;
            
            % Lire le fichier temporaire
            fid = fopen(tempFile, 'r');
            out = fread(fid, '*char')';
            fclose(fid);
            delete(tempFile);
            
            txtArea.Value = splitlines(out);
        catch ME
            diary off;
            txtArea.Value = {['❌ Erreur ' method ' : ' ME.message]};
        end
    end

    function cbRunComparison(~, ~)
        if ~appData.isLoaded
            showInGrayZone('Erreur : Aucun système chargé.', 'err');
            return;
        end
        try
            resetRightZone();
            txtArea.Visible = 'off';
            axContainer.Visible = 'on';
            drawnow;
            comparaison_methodes_EP(appData, axContainer);
        catch ME
            msg = ME.message;
            if ~isempty(ME.stack)
                msg = sprintf('%s\n\nFichier : %s\nLigne : %d', ...
                    msg, ME.stack(1).file, ME.stack(1).line);
            end
            showInGrayZone({'❌ Erreur lors de la comparaison :'; msg}, 'err');
        end
    end

    function showInGrayZone(content, ~)
        resetRightZone();
        txtArea.Visible = 'on';
        if iscell(content)
            txtArea.Value = content;
        else
            txtArea.Value = {content};
        end
    end

    function resetRightZone()
        txtArea.Visible    = 'off';
        axContainer.Visible = 'off';
        txtArea.Position   = [40 40 970 720];
        delete(findall(f, 'Tag', 'epDyn'));
        delete(axContainer.Children);
    end

    function cbReset(~, ~)
        resetRightZone();
        txtArea.Visible = 'on';
        txtArea.Value   = {''};
    end

    f.CloseRequestFcn = @(~,~) cleanup();
    function cleanup()
        set(0, 'DefaultFigureVisible', 'off');
        delete(f);
    end

    % =========================================================================
    % --- FONCTIONS DYNAMIQUES DE STABILITÉ ---
    % =========================================================================

    function cbOuvrirStabilite(~, ~)
        if ~appData.isLoaded
            showInGrayZone('❌ Erreur : Veuillez d''abord charger un système avant d''accéder à l''analyse de stabilité.', 'err');
            return;
        end
        ecranSelectionDefaut();
    end

        function ecranSelectionDefaut()
        resetRightZone();
        axContainer.Visible = 'on';
        
        % Titre
        uilabel(axContainer, 'Text', 'ANALYSE DE STABILITÉ TRANSITOIRE - TYPE DE DÉFAUT', ...
                'Position', [125 700 800 40], 'FontWeight', 'bold', 'FontSize', 25, ...
                'FontColor', [0.2 0.2 0.2], 'HorizontalAlignment', 'center');
        
        % Boutons
        uibutton(axContainer, 'Text', '🔴 Court-circuit sur nœud (sans ouverture de ligne)', ...
                 'Position', [170 190 650 60], 'FontSize', 20, 'FontWeight', 'bold', ...
                 'BackgroundColor', [0.95 0.85 0.85], ...
                 'ButtonPushedFcn', @(~,~) ecranInterfaceNoeud());
             
        uibutton(axContainer, 'Text', '🟠 Court-circuit sur ligne (avec ouverture)', ...
                 'Position', [170 90 650 60], 'FontSize', 20, 'FontWeight', 'bold', ...
                 'BackgroundColor', [0.95 0.90 0.80], ...
                 'ButtonPushedFcn', @(~,~) ecranInterfaceLigne());
        
        % --- AJOUT DE LA PHOTO ---
        try
            % Charger l'image (à adapter selon votre chemin)
            img = imread('stabilite_illustration.png');  % Nom de votre fichier image
            
            % Créer un axe pour afficher l'image
            axImage = uiaxes(axContainer, 'Position', [100 120 800 700]);
            
            % Afficher l'image
            imshow(img, 'Parent', axImage);
            axImage.Box = 'on';
            axImage.XColor = [0.5 0.5 0.5];
            axImage.YColor = [0.5 0.5 0.5];
            
        catch ME
            % Si l'image n'est pas trouvée, afficher un message
            uilabel(axContainer, 'Text', '📷 Image non trouvée', ...
                    'Position', [425 380 200 30], 'FontSize', 12, ...
                    'FontColor', [0.5 0.5 0.5], 'HorizontalAlignment', 'center');
        end
    end

    function ecranInterfaceNoeud()
    resetRightZone();
    axContainer.Visible = 'on';
    
    % Dimensions de la zone
    zone_width = 1050;
    zone_height = 800;
    
    % Bouton retour
    uibutton(axContainer, 'Text', '↩ Retour', 'Position', [20 740 100 35], ...
             'FontSize', 12, 'FontWeight', 'bold', ...
             'ButtonPushedFcn', @(~,~) ecranSelectionDefaut());
    
    % Titre
    uilabel(axContainer, 'Text', 'Court-circuit triphasé sur un nœud', ...
            'Position', [250 745 500 30], 'FontWeight', 'bold', 'FontSize', 16, ...
            'FontColor', [0.2 0.2 0.2]);
    
    % === ZONE DES PARAMÈTRES ===
    % Panel agrandi pour 2 lignes bien espacées
    pForm = uipanel(axContainer, 'Position', [20 595 1010 140], ...
                    'BackgroundColor', [0.95 0.95 0.95], ...
                    'BorderType', 'line', 'Title', 'Paramètres du défaut', ...
                    'FontSize', 12, 'FontWeight', 'bold');

    % Définition de la liste des nœuds
    listeNoeuds = cellstr(num2str((1:appData.nbus)'));

    % --- Dimensions communes ---
    lbl_w   = 140;   % largeur label
    fld_w   = 160;   % largeur champ
    col_gap = 30;    % espace entre colonnes
    x0      = 25;    % marge gauche

    % --- Positions verticales (2 lignes) ---
    % Ligne 1 : y_lbl1 / y_fld1   (haut du panel)
    % Ligne 2 : y_lbl2 / y_fld2   (bas du panel)
    y_lbl1 = 88;   y_fld1 = 84;
    y_lbl2 = 45;   y_fld2 = 41;

    % === LIGNE 1 : Nœud en défaut | T_clear/Tcr | T_final/Tmax ===
    % -- Colonne 1 : Nœud en défaut --
    xc1 = x0;
    uilabel(pForm, 'Text', 'Nœud en défaut :', ...
            'Position', [xc1, y_lbl1, lbl_w, 22], 'FontSize', 11, 'FontWeight', 'bold');
    ddBus = uidropdown(pForm, 'Items', listeNoeuds, 'Value', listeNoeuds{1}, ...
                       'Position', [xc1 + lbl_w + 5, y_fld1, fld_w, 28], 'FontSize', 11);

    % -- Colonne 2 : T_clear / Tcr --
    xc2 = xc1 + lbl_w + fld_w + col_gap + 5;
    uilabel(pForm, 'Text', 'T_clear / Tcr (s) :', ...
            'Position', [xc2, y_lbl1, lbl_w, 22], 'FontSize', 11, 'FontWeight', 'bold');
    efTclear = uieditfield(pForm, 'numeric', 'Value', 0.1, ...
                           'Position', [xc2 + lbl_w + 5, y_fld1, fld_w, 28], 'FontSize', 11);

    % -- Colonne 3 : T_final / Tmax --
    xc3 = xc2 + lbl_w + fld_w + col_gap + 5;
    uilabel(pForm, 'Text', 'T_final / Tmax (s) :', ...
            'Position', [xc3, y_lbl1, lbl_w, 22], 'FontSize', 11, 'FontWeight', 'bold');
    efTmax = uieditfield(pForm, 'numeric', 'Value', 1.0, ...
                         'Position', [xc3 + lbl_w + 5, y_fld1, fld_w, 28], 'FontSize', 11);

    % === LIGNE 2 : Pas de temps dt ===
    uilabel(pForm, 'Text', 'Pas de temps dt (s) :', ...
            'Position', [xc1, y_lbl2, lbl_w, 22], 'FontSize', 11, 'FontWeight', 'bold');
    efDt = uieditfield(pForm, 'numeric', 'Value', 0.005, ...
                       'Position', [xc1 + lbl_w + 5, y_fld2, fld_w, 28], 'FontSize', 11);

    % === BOUTON LANCER : colonne droite, centré verticalement ===
    btnWidth  = 300;
    btnHeight = 35;
    btnX = pForm.Position(3) - btnWidth - 20;
    btnY = (pForm.Position(4) - btnHeight) / 2 - 40;

    uibutton(pForm, 'Text', '▶ LANCER LA SIMULATION', ...
             'Position', [btnX, btnY, btnWidth, btnHeight], ...
             'FontWeight', 'bold', 'FontSize', 13, ...
             'BackgroundColor', [0.25 0.65 0.25], 'FontColor', [1 1 1], ...
             'ButtonPushedFcn', @(~,~) executerSimulationNoeud(ddBus.Value, ...
                                efTclear.Value, efTmax.Value, efDt.Value));
    
    % === ZONE DES GRAPHIQUES (AGRANDIE) ===
    pGraphContainer = uipanel(axContainer, 'Position', [20 50 1010 530], ...
                              'BackgroundColor', [1 1 1], 'BorderType', 'line', ...
                              'Title', 'Résultats de la simulation', ...
                              'FontSize', 12, 'FontWeight', 'bold');
    
    % Figure 1 : Angles rotoriques (gauche, agrandie)
    ax1 = uiaxes(pGraphContainer, 'Position', [40 75 450 400]);
    title(ax1, 'Angles rotoriques \delta (degrés)', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel(ax1, 'Temps (s)');
    ylabel(ax1, '\delta (°)');
    grid(ax1, 'on');
    hold(ax1, 'on');
    
    % Figure 2 : Vitesses relatives (droite, agrandie)
    ax2 = uiaxes(pGraphContainer, 'Position', [530 75 450 400]);
    title(ax2, 'Vitesses relatives \omega / \omega_s', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel(ax2, 'Temps (s)');
    ylabel(ax2, '\omega / \omega_s');
    grid(ax2, 'on');
    hold(ax2, 'on');
    
    % Zone de texte d'information
    lblInfo = uilabel(pGraphContainer, 'Text', 'Les courbes apparaîtront après avoir lancé la simulation.', ...
                      'Position', [280 20 500 25], 'FontSize', 11, ...
                      'FontColor', [0.5 0.5 0.5], 'HorizontalAlignment', 'center');
    
    % Stockage des axes
    setappdata(pGraphContainer, 'ax1', ax1);
    setappdata(pGraphContainer, 'ax2', ax2);
    setappdata(pGraphContainer, 'lblInfo', lblInfo);
    setappdata(pGraphContainer, 'isLigneMode', false);
end

    function ecranInterfaceLigne()
    resetRightZone();
    axContainer.Visible = 'on';
    
    % Dimensions de la zone
    zone_width = 1050;
    zone_height = 800;
    
    % Bouton retour
    uibutton(axContainer, 'Text', '↩ Retour', 'Position', [20 740 100 35], ...
             'FontSize', 12, 'FontWeight', 'bold', ...
             'ButtonPushedFcn', @(~,~) ecranSelectionDefaut());
    
    % Titre
    uilabel(axContainer, 'Text', 'Court-circuit sur ligne avec ouverture', ...
            'Position', [140 745 500 30], 'FontWeight', 'bold', 'FontSize', 16, ...
            'FontColor', [0.2 0.2 0.2]);
    
    % === ZONE DES PARAMÈTRES (GRILLE 2 LIGNES x 3 COLONNES) ===
    pForm = uipanel(axContainer, 'Position', [20 590 1010 140], ...
                    'BackgroundColor', [0.95 0.95 0.95], ...
                    'BorderType', 'line', 'Title', 'Paramètres du défaut', ...
                    'FontSize', 12, 'FontWeight', 'bold');

    % --- Dimensions communes ---
    lbl_w   = 135;   % largeur label
    fld_w   = 155;   % largeur champ
    col_gap = 28;    % espace entre colonnes
    x0      = 25;    % marge gauche

    % --- Positions verticales ---
    y_lbl1 = 88;  y_fld1 = 84;   % ligne 1 (haut)
    y_lbl2 = 45;  y_fld2 = 41;   % ligne 2 (bas)

    % === LIGNE 1 : T_cr | T_max | dt ===
    % -- Colonne 1 : T_cr --
    xc1 = x0;
    uilabel(pForm, 'Text', 'T_cr (ouverture) :', ...
            'Position', [xc1, y_lbl1, lbl_w, 22], 'FontSize', 11, 'FontWeight', 'bold');
    efTcr = uieditfield(pForm, 'numeric', 'Value', 0.15, ...
                        'Position', [xc1 + lbl_w + 5, y_fld1, fld_w, 28], 'FontSize', 11);

    % -- Colonne 2 : T_max --
    xc2 = xc1 + lbl_w + fld_w + col_gap + 5;
    uilabel(pForm, 'Text', 'T_max (durée) :', ...
            'Position', [xc2, y_lbl1, lbl_w, 22], 'FontSize', 11, 'FontWeight', 'bold');
    efTmax = uieditfield(pForm, 'numeric', 'Value', 1.5, ...
                         'Position', [xc2 + lbl_w + 5, y_fld1, fld_w, 28], 'FontSize', 11);

    % -- Colonne 3 : dt --
    xc3 = xc2 + lbl_w + fld_w + col_gap + 5;
    uilabel(pForm, 'Text', 'Pas de temps dt (s) :', ...
            'Position', [xc3, y_lbl1, lbl_w, 22], 'FontSize', 11, 'FontWeight', 'bold');
    efDt = uieditfield(pForm, 'numeric', 'Value', 0.005, ...
                       'Position', [xc3 + lbl_w + 5, y_fld1, fld_w, 28], 'FontSize', 11);

    % === LIGNE 2 : Nœud de Départ | Nœud d'Arrivée ===
    listeNoeuds = cellstr(num2str((1:appData.nbus)'));

    % -- Colonne 1 : Nœud de Départ (court-circuité) --
    uilabel(pForm, 'Text', 'Nœud court-circuité :', ...
            'Position', [xc1, y_lbl2, lbl_w, 22], 'FontSize', 11, 'FontWeight', 'bold');
    
    % Création du premier dropdown
    ddFrom = uidropdown(pForm, 'Items', listeNoeuds, 'Value', listeNoeuds{1}, ...
                        'Position', [xc1 + lbl_w + 5, y_fld2, fld_w, 28], 'FontSize', 11);
    
    % -- Colonne 2 : Nœud d'Arrivée (2ème extrémité) --
    uilabel(pForm, 'Text', '2ème extrémité ligne :', ...
            'Position', [xc2, y_lbl2, lbl_w, 22], 'FontSize', 11, 'FontWeight', 'bold');
    
    % Création du deuxième dropdown (vide au départ)
    ddTo = uidropdown(pForm, 'Items', {}, ...
                      'Position', [xc2 + lbl_w + 5, y_fld2, fld_w, 28], 'FontSize', 11);
    
    % Fonction pour mettre à jour la liste des voisins
    function updateVoisins()
        nd = str2double(ddFrom.Value);
        ld = appData.linedata;
        voisins = [];
        for idxL = 1:size(ld, 1)
            if ld(idxL, 1) == nd
                voisins = [voisins, ld(idxL, 2)];
            end
            if ld(idxL, 2) == nd
                voisins = [voisins, ld(idxL, 1)];
            end
        end
        voisins = unique(voisins);
        if isempty(voisins)
            ddTo.Items = {'(Aucun nœud relié)'};
        else
            ddTo.Items = cellstr(num2str(voisins'));
            ddTo.Value = ddTo.Items{1};
        end
    end
    
    % Appel initial pour remplir ddTo
    updateVoisins();
    
    % Callback pour le changement de nœud de départ
    ddFrom.ValueChangedFcn = @(~,~) updateVoisins();

    % === BOUTON LANCER : droite, centré verticalement ===
    btnWidth  = 300;
    btnHeight = 35;
    btnX = pForm.Position(3) - btnWidth - 20;
    btnY = (pForm.Position(4) - btnHeight) / 2 - 40;
    
    uibutton(pForm, 'Text', '▶ LANCER LA SIMULATION', ...
             'Position', [btnX, btnY, btnWidth, btnHeight], ...
             'FontWeight', 'bold', 'FontSize', 13, ...
             'BackgroundColor', [0.3 0.7 0.3], 'FontColor', [1 1 1], ...
             'ButtonPushedFcn', @(~,~) executerSimulationLigne(ddFrom.Value, ...
                                ddTo.Value, efTcr.Value, efTmax.Value, efDt.Value));
    
    % === ZONE DES GRAPHIQUES ===
    pGraphContainer = uipanel(axContainer, 'Position', [20 50 1010 530], ...
                              'BackgroundColor', [1 1 1], 'BorderType', 'line', ...
                              'Title', 'Résultats de la simulation', ...
                              'FontSize', 12, 'FontWeight', 'bold');
    
    % Figure 1 : Angles rotoriques (haut GAUCHE)
    ax1 = uiaxes(pGraphContainer, 'Position', [40 280 450 220]);
    title(ax1, 'Angles rotoriques \delta (degrés)', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel(ax1, 'Temps (s)');
    ylabel(ax1, '\delta (°)');
    grid(ax1, 'on');
    hold(ax1, 'on');
    
    % Figure 2 : Vitesses relatives (haut DROITE)
    ax2 = uiaxes(pGraphContainer, 'Position', [530 280 450 220]);
    title(ax2, 'Vitesses relatives \omega / \omega_s', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel(ax2, 'Temps (s)');
    ylabel(ax2, '\omega / \omega_s');
    grid(ax2, 'on');
    hold(ax2, 'on');
    
    % Figure 3 : Angles relatifs (bas, centrée)
    ax3 = uiaxes(pGraphContainer, 'Position', [230 40 580 200]);
    title(ax3, 'Angles rotoriques relatifs (Réf : Machine 1)', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel(ax3, 'Temps (s)');
    ylabel(ax3, '\Delta\delta (°)');
    grid(ax3, 'on');
    hold(ax3, 'on');
    
    % Zone de texte d'information (définition de lblInfo)
    lblInfo = uilabel(pGraphContainer, 'Text', 'Les courbes apparaîtront après avoir lancé la simulation.', ...
                      'Position', [280 10 500 25], 'FontSize', 11, ...
                      'FontColor', [0.5 0.5 0.5], 'HorizontalAlignment', 'center');
    
    % Stockage des axes et du label
    setappdata(pGraphContainer, 'ax1', ax1);
    setappdata(pGraphContainer, 'ax2', ax2);
    setappdata(pGraphContainer, 'ax3', ax3);
    setappdata(pGraphContainer, 'lblInfo', lblInfo);
    setappdata(pGraphContainer, 'isLigneMode', true);
end

    function cbChangementNoeudDepart(src, ddTo)
    nd = str2double(src.Value);
    ld = appData.linedata;
    voisins = [];
    for idxL = 1:size(ld, 1)
        if ld(idxL, 1) == nd, voisins = [voisins, ld(idxL, 2)]; end
        if ld(idxL, 2) == nd, voisins = [voisins, ld(idxL, 1)]; end
    end
    voisins = unique(voisins);
    if isempty(voisins)
        ddTo.Items = {'(Aucun nœud relié)'};
    else
        ddTo.Items = cellstr(num2str(voisins'));
        ddTo.Value = ddTo.Items{1};
    end
end

    function majDropdownArrivee(noeudDepStr, ddCible)
        nd = str2double(noeudDepStr);
        ld = appData.linedata;
        voisins = [];
        for idxL = 1:size(ld, 1)
            if ld(idxL, 1) == nd, voisins = [voisins, ld(idxL, 2)]; end
            if ld(idxL, 2) == nd, voisins = [voisins, ld(idxL, 1)]; end
        end
        voisins = unique(voisins);
        if isempty(voisins)
            ddCible.Items = {'(Aucun nœud relié)'};
        else
            ddCible.Items = cellstr(num2str(voisins'));
        end
    end

    function executerSimulationNoeud(busFaultStr, tc, tmax, dt)
    noeudDefaut = str2double(busFaultStr);
    
    % Récupérer le conteneur des graphiques
    pGraphContainer = findobj(axContainer, 'Type', 'uipanel', 'Title', 'Résultats de la simulation');
    if isempty(pGraphContainer)
        uialert(f, 'Conteneur de graphiques introuvable.', 'Erreur');
        return;
    end
    
    % Récupérer les axes
    ax1 = getappdata(pGraphContainer, 'ax1');
    ax2 = getappdata(pGraphContainer, 'ax2');
    lblInfo = getappdata(pGraphContainer, 'lblInfo');
    
    % Nettoyer les axes
    cla(ax1);
    cla(ax2);
    
    drawnow;
    
    try
        res = stabilite_transitoire_04(appData, noeudDefaut, tc, tmax, dt);
        
        t_data = res.t(:)';
        
        % Tracer sur ax1 (Angles rotoriques)
        hold(ax1, 'on');
        for idxG = 1:size(res.delta, 2)
            plot(ax1, t_data, res.delta(:, idxG), 'LineWidth', 1.5, ...
                 'DisplayName', sprintf('Gen %d', idxG));
        end
        grid(ax1, 'on');
        legend(ax1, 'show', 'Location', 'best');
        
        % Tracer sur ax2 (Vitesses relatives)
        hold(ax2, 'on');
        for idxG = 1:size(res.omega, 2)
            plot(ax2, t_data, res.omega(:, idxG), 'LineWidth', 1.5, ...
                 'DisplayName', sprintf('Gen %d', idxG));
        end
        grid(ax2, 'on');
        legend(ax2, 'show', 'Location', 'best');
        
        % === CALCUL ET AFFICHAGE DE LA STABILITÉ ===
        % Calcul de l'écart angulaire final entre les générateurs
        delta_final = res.delta(end, :);  % Derniers angles en degrés
        delta_spread = max(delta_final) - min(delta_final);
        
        % Critère de stabilité (écart angulaire < 120°)
        if delta_spread < 120
            stability_status = 'STABLE';
            stability_color = [0, 0.6, 0];  % Vert
            stability_icon = '✅';
        else
            stability_status = 'INSTABLE';
            stability_color = [0.8, 0, 0];   % Rouge
            stability_icon = '❌';
        end
        
        % Ajouter l'information de stabilité dans lblInfo
        lblInfo.Text = sprintf('%s Simulation terminée avec succès.\n📊 État du système : %s %s (Écart angulaire final = %.1f°)', ...
                               stability_icon, stability_status, stability_icon, delta_spread);
        lblInfo.FontColor = stability_color;
        lblInfo.FontWeight = 'bold';
        
    catch ME
        lblInfo.Text = ['❌ Erreur : ' ME.message];
        lblInfo.FontColor = [1 0 0];
        lblInfo.FontWeight = 'normal';
    end
end

    function executerSimulationLigne(fromStr, toStr, tcr, tmax, dt)
    if strcmp(toStr, '(Aucun nœud relié)')
        uialert(f, 'Sélection de ligne invalide.', 'Erreur');
        return;
    end
    nDep = str2double(fromStr);
    nArr = str2double(toStr);
    
    % Récupérer le conteneur des graphiques
    pGraphContainer = findobj(axContainer, 'Type', 'uipanel', 'Title', 'Résultats de la simulation');
    if isempty(pGraphContainer)
        uialert(f, 'Conteneur de graphiques introuvable.', 'Erreur');
        return;
    end
    
    % Récupérer les axes
    ax1 = getappdata(pGraphContainer, 'ax1');
    ax2 = getappdata(pGraphContainer, 'ax2');
    ax3 = getappdata(pGraphContainer, 'ax3');
    lblInfo = getappdata(pGraphContainer, 'lblInfo');
    
    % Nettoyer les axes
    cla(ax1);
    cla(ax2);
    cla(ax3);
    
    drawnow;
    
    try
        res = stabilite_transitoire_06(appData, nDep, nArr, tcr, tmax, dt);
        
        t_data = res.t(:)';
        delta_correct = res.delta;   % (nt x ng) angles en degrés
        
        % Figure 1 : Angles rotoriques (valeurs absolues en degrés)
        hold(ax1, 'on');
        for idxG = 1:size(delta_correct, 2)
            plot(ax1, t_data, delta_correct(:, idxG), 'LineWidth', 1.5, ...
                 'DisplayName', sprintf('Gen %d', idxG));
        end
        grid(ax1, 'on');
        legend(ax1, 'show', 'Location', 'best');
        
        % Figure 2 : Vitesses relatives omega/omegas
        hold(ax2, 'on');
        for idxG = 1:size(res.omega, 2)
            plot(ax2, t_data, res.omega(:, idxG), 'LineWidth', 1.5, ...
                 'DisplayName', sprintf('Gen %d', idxG));
        end
        grid(ax2, 'on');
        legend(ax2, 'show', 'Location', 'best');
        
        % Figure 3 : Angles relatifs (avec RK2 pour plus de précision)
        hold(ax3, 'on');
        if isfield(res, 'delta_rel') && ~isempty(res.delta_rel)
            % Utiliser les résultats précis de RK2
            t_rel = res.t_rel;
            for idxG = 2:res.ng
                delta_rel = res.delta_rel(:, idxG) - res.delta_rel(:, 1);
                plot(ax3, t_rel, delta_rel, 'LineWidth', 2, ...
                     'DisplayName', sprintf('\\delta_{%d} - \\delta_1 (RK2)', idxG));
            end
        else
            % Fallback sur la méthode standard
            for idxG = 2:size(delta_correct, 2)
                delta_rel = delta_correct(:, idxG) - delta_correct(:, 1);
                plot(ax3, t_data, delta_rel, 'LineWidth', 1.5, ...
                     'DisplayName', sprintf('\\delta_{%d} - \\delta_1', idxG));
            end
        end
        grid(ax3, 'on');
        legend(ax3, 'show', 'Location', 'best');
        
        % === CALCUL ET AFFICHAGE DE LA STABILITÉ ===
        % Critère basé sur l'écart angulaire relatif final (plus physique)
        if isfield(res, 'delta_rel') && size(res.delta_rel, 2) > 1
            delta_rel_final = res.delta_rel(end, 2:end) - res.delta_rel(end, 1);
            delta_spread = max(abs(delta_rel_final));
        else
            delta_final  = delta_correct(end, :);
            delta_spread = max(delta_final) - min(delta_final);
        end
        
        % Critère de stabilité (écart angulaire relatif < 120°)
        if delta_spread < 120
            stability_status = '✅ STABLE';
            stability_color = [0, 0.6, 0];   % Vert
            
        else
            stability_status = '❌ INSTABLE';
            stability_color = [0.8, 0, 0];   % Rouge
            
        end
        
        % Ajouter l'information de stabilité dans lblInfo
        lblInfo.Text = sprintf('Etat du systeme : %s (Ecart angulaire final = %.2f deg)', ...
                       stability_status, delta_spread);
        lblInfo.FontColor = stability_color;
        lblInfo.FontWeight = 'bold';
        
    catch ME
        lblInfo.Text = ['❌ Erreur : ' ME.message];
        lblInfo.FontColor = [1 0 0];
        lblInfo.FontWeight = 'normal';
    end
end

end  % Fin de la fonction interface_MAIN (UN SEUL end ici)


% =========================================================================
% --- FONCTIONS UTILITAIRES EXTERNES (en dehors de la fonction principale)
% =========================================================================

function liste_fichiers = scanner_dossier(repertoire)
    liste_fichiers = {};
    fichiers = dir(fullfile(repertoire, 'system*.m'));
    if isempty(fichiers), return; end
    noms = {fichiers.name};
    exclusions = {'interface_MAIN.m', 'stabilite_transitoire_04.m', 'stabilite_transitoire_06.m'};
    masque = ~ismember(noms, exclusions);
    liste_fichiers = noms(masque);
    if isempty(liste_fichiers), liste_fichiers = {}; else liste_fichiers = sort(liste_fichiers); end
end

function data = charger_donnees_systeme(chemin_fichier)
    [dossier, nom_f, ~] = fileparts(chemin_fichier);
    path_initial = addpath(dossier);
    clear(nom_f);
    
    try
        run(chemin_fichier);
        
        vars_required = {'busdata', 'linedata', 'nbus', 'nbr'};
        vars_optional = {'basemva', 'accuracy', 'maxiter', 'accel', 'npq', 'npv', 'ns', 'gendata', 'f0'};
        
        for idxV = 1:numel(vars_required)
            if ~exist(vars_required{idxV}, 'var')
                error('Variable critique absente : %s dans %s', vars_required{idxV}, nom_f);
            end
            data.(vars_required{idxV}) = eval(vars_required{idxV});
        end
        
        for idxV = 1:numel(vars_optional)
            if exist(vars_optional{idxV}, 'var')
                data.(vars_optional{idxV}) = eval(vars_optional{idxV});
            else
                switch vars_optional{idxV}
                    case 'basemva', data.basemva = 100;
                    case 'accuracy', data.accuracy = 0.0001;
                    case 'maxiter', data.maxiter = 100;
                    case 'accel', data.accel = 1.6;
                    case 'npq', data.npq = 0;
                    case 'npv', data.npv = 0;
                    case 'ns', data.ns = 1;
                    case 'f0', data.f0 = 60;
                    case 'gendata'
                        if exist('busdata', 'var')
                            busdata_local = eval('busdata');
                            slack_idx = find(busdata_local(:,2) == 1);
                            pv_idx = find(busdata_local(:,2) == 2);
                            gen_buses = [slack_idx; pv_idx];
                            
                            if ~isempty(gen_buses)
                                ng = length(gen_buses);
                                data.gendata = zeros(ng, 4);
                                for g = 1:ng
                                    data.gendata(g,1) = busdata_local(gen_buses(g), 1);
                                    data.gendata(g,2) = 0;
                                    data.gendata(g,3) = 0.25;
                                    data.gendata(g,4) = 50;
                                end
                            else
                                data.gendata = [];
                            end
                        else
                            data.gendata = [];
                        end
                end
            end
        end
        
        path(path_initial);
    catch ME
        path(path_initial);
        rethrow(ME);
    end
end

function afficher_matrice_uitable(parent, M, titre, type_mat)
    n = size(M, 1);
    delete(findall(parent, 'Tag', 'matDisplay'));

    ppos    = parent.Position;
    MARGIN  = 20;
    HDR_H   = 28;
    INFO_H  = 20;
    
    table_w = ppos(3) - 2*MARGIN;
    table_h = ppos(4) - HDR_H - INFO_H - 4*MARGIN;
    ty      = MARGIN + INFO_H + MARGIN;

    uilabel(parent, 'Text', titre, 'Position', [MARGIN, ppos(4)-MARGIN-HDR_H, table_w, HDR_H], ...
            'FontWeight', 'bold', 'FontSize', 13, 'Tag', 'matDisplay');

    cell_data = preparer_donnees_mat(M, n, type_mat);
    noms_indices = cellstr(num2str((1:n)')); 

    couleur_impaire = [232, 249, 255] / 255;
    couleur_paire   = [251, 251, 251] / 255;

    colors = repmat([couleur_impaire; couleur_paire], ceil(n/2), 1);
    row_colors = colors(1:n, :); 

    uitable(parent, ...
        'Data', cell_data, ...               
        'ColumnName', noms_indices', ...     
        'RowName', noms_indices, ...        
        'ColumnWidth', repmat({112}, 1, n), ... 
        'Position', [MARGIN, ty, table_w, table_h], ...
        'FontName', 'Consolas', ...
        'FontSize', 11, ...  % ← Changé de 9 à 11
        'BackgroundColor', row_colors, ...
        'Tag', 'matDisplay');

    uilabel(parent, 'Text', sprintf('Matrice %d × %d | Alternance de couleurs active (Bleu)', n, n), ...
            'Position', [MARGIN, MARGIN, table_w, INFO_H], 'FontSize', 9, 'FontColor', [0.4 0.4 0.4], 'Tag', 'matDisplay');
end

function cell_data = preparer_donnees_mat(M, n, type_mat)
    cell_data = cell(n, n);
    is_complex = strcmp(type_mat, 'complex');
    for i = 1:n
        for j = 1:n
            if is_complex
                cell_data{i,j} = format_complexe_mat(M(i,j));
            else
                v = real(M(i,j));
                if abs(v) < 1e-10
                    cell_data{i,j} = '0';
                else
                    cell_data{i,j} = sprintf('%.5f', v);
                end
            end
        end
    end
end

function str = format_complexe_mat(z)
    re = real(z); im = imag(z); tol = 1e-8;
    if abs(re) < tol && abs(im) < tol
        str = '0';
    elseif abs(im) < tol
        str = sprintf('%.4f', re);
    elseif abs(re) < tol
        if im >= 0
            str = sprintf('j%.4f', im);
        else
            str = sprintf('-j%.4f', abs(im));
        end
    else
        if im >= 0
            str = sprintf('%.4f+j%.4f', re, im);
        else
            str = sprintf('%.4f-j%.4f', re, abs(im));
        end
    end
end