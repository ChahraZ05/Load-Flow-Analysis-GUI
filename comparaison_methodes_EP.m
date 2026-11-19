function comparaison_methodes_EP(donnees_systeme, parent_panel)
% comparaison_methodes_EP - Compare les 3 méthodes d'écoulement de puissance
%
% USAGE :
%   comparaison_methodes_EP(donnees_systeme)              % fenêtre externe
%   comparaison_methodes_EP(donnees_systeme, parent_panel) % intégré dans l'interface

    methodes = {'Gauss-Seidel', 'Newton-Raphson', 'FDLF'};
    
    iters    = nan(1,3);
    temps    = nan(1,3);
    pertes   = nan(1,3);
    tensions = nan(donnees_systeme.nbus, 3);

    set(0, 'DefaultFigureVisible', 'off');

    % A. GAUSS-SEIDEL
    try
        tic;
        [V_gs, ~, it_gs, Pl_gs] = EP_Gauss_Seidel(donnees_systeme.busdata, donnees_systeme.linedata, ...
            donnees_systeme.basemva, donnees_systeme.accuracy, donnees_systeme.maxiter, ...
            donnees_systeme.nbr, donnees_systeme.accel);
        temps(1)      = toc;
        iters(1)      = it_gs;
        tensions(:,1) = abs(V_gs);
        pertes(1)     = Pl_gs;
        fprintf('GS   -> iters=%d | temps=%.4f | pertes=%.4f\n', iters(1), temps(1), pertes(1));
    catch ME
        fprintf('Erreur Gauss-Seidel : %s\n', ME.message);
    end

    % B. NEWTON-RAPHSON
    try
        tic;
        [V_nr, ~, it_nr, Pl_nr] = EP_Newton_Raphson_Polaire_01(donnees_systeme.nbus, donnees_systeme.busdata, ...
            donnees_systeme.accuracy, donnees_systeme.maxiter, donnees_systeme.nbr, ...
            donnees_systeme.npq, donnees_systeme.linedata, donnees_systeme.basemva);
        temps(2)      = toc;
        iters(2)      = it_nr;
        tensions(:,2) = abs(V_nr);
        pertes(2)     = Pl_nr;
        fprintf('NR   -> iters=%d | temps=%.4f | pertes=%.4f\n', iters(2), temps(2), pertes(2));
    catch ME
        fprintf('Erreur Newton-Raphson : %s\n', ME.message);
    end

    % C. FDLF
    try
        tic;
        [V_fd, ~, it_fd, Pl_fd] = EP_FDLF(donnees_systeme.busdata, donnees_systeme.linedata, ...
            donnees_systeme.basemva, donnees_systeme.accuracy, donnees_systeme.maxiter);
        temps(3)      = toc;
        iters(3)      = it_fd;
        tensions(:,3) = abs(V_fd);
        pertes(3)     = Pl_fd;
        fprintf('FDLF -> iters=%d | temps=%.4f | pertes=%.4f\n', iters(3), temps(3), pertes(3));
    catch ME
        fprintf('Erreur FDLF : %s\n', ME.message);
    end

    fprintf('\n=== VÉRIFICATION DES DONNÉES AVANT TRACÉ ===\n');
    fprintf('Itérations : GS=%s | NR=%s | FDLF=%s\n', num2str(iters(1)), num2str(iters(2)), num2str(iters(3)));
    fprintf('Temps      : GS=%s | NR=%s | FDLF=%s\n', num2str(temps(1)), num2str(temps(2)), num2str(temps(3)));
    fprintf('Pertes     : GS=%s | NR=%s | FDLF=%s\n', num2str(pertes(1)), num2str(pertes(2)), num2str(pertes(3)));

    % --- COULEURS ---
    couleurs = [31/255  119/255  180/255;   % Bleu profond      -> GS
            44/255  160/255  44/255;    % Vert forêt        -> NR
            214/255 39/255   40/255];   % Rouge brique      -> FDLF

    if nargin >= 2 && ~isempty(parent_panel)

        % --- MODE INTÉGRÉ : affichage dans l'interface ---
        set(0, 'DefaultFigureVisible', 'on');

        % Supprimer les anciens axes s'ils existent (rafraîchissement)
        delete(parent_panel.Children);

        % ✅ Utiliser getpixelposition pour avoir la vraie taille en pixels
        ppos = getpixelposition(parent_panel);
        W = ppos(3);
        H = ppos(4);

        % Marges et dimensions de chaque sous-graphique
        marge_x = 60;
        marge_y = 55;
        espace_x = 40;
        espace_y = 50;
        ax_w = (W - 2*marge_x - espace_x) / 2;
        ax_h = (H - 2*marge_y - espace_y) / 2;

        % Positions [x y w h] des 4 uiaxes dans le panel
        positions = [
            marge_x,                   marge_y + ax_h + espace_y, ax_w, ax_h;
            marge_x + ax_w + espace_x, marge_y + ax_h + espace_y, ax_w, ax_h;
            marge_x,                   marge_y,                   ax_w, ax_h;
            marge_x + ax_w + espace_x, marge_y,                   ax_w, ax_h;
        ];

        % --- Titre général ---
        uilabel(parent_panel, ...
            'Text', 'COMPARAISON DES MÉTHODES D''ÉCOULEMENT DE PUISSANCE', ...
            'Position', [0, H-45, W, 30], ...
            'HorizontalAlignment', 'center', ...
            'FontWeight', 'bold', ...
            'FontSize', 20, ...
            'FontColor', [0.1 0.1 0.4]);

        % ---- Subplot 1 : Itérations (échelle log) ----
        ax1 = uiaxes(parent_panel, 'Position', positions(1,:));
        b1 = bar(ax1, iters, 'FaceColor', 'flat');
        for k = 1:3, b1.CData(k,:) = couleurs(k,:); end
        set(ax1, 'XTick', 1:3, 'XTickLabel', methodes, 'YScale', 'log');
        title(ax1, 'Nombre d''itérations');
        ylabel(ax1, 'Itérations');
        grid(ax1, 'on');
        ylim(ax1, [0.5, max(iters, [], 'omitnan') * 2]);
        text(ax1, 1:3, iters, arrayfun(@(x) num2str(x), iters, 'UniformOutput', false), ...
             'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');

        % ---- Subplot 2 : Temps ----
        ax2 = uiaxes(parent_panel, 'Position', positions(2,:));
        b2 = bar(ax2, temps, 'FaceColor', 'flat');
        for k = 1:3, b2.CData(k,:) = couleurs(k,:); end
        set(ax2, 'XTick', 1:3, 'XTickLabel', methodes);
        title(ax2, 'Temps d''exécution (secondes)');
        ylabel(ax2, 'Temps (s)');
        grid(ax2, 'on');
        ylim(ax2, [0, max(temps, [], 'omitnan') * 1.2 + 0.001]);
        text(ax2, 1:3, temps, arrayfun(@(x) sprintf('%.4f', x), temps, 'UniformOutput', false), ...
             'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');

        % ---- Subplot 3 : Pertes (échelle log) ----
        ax3 = uiaxes(parent_panel, 'Position', positions(3,:));
        b3 = bar(ax3, pertes, 'FaceColor', 'flat');
        for k = 1:3, b3.CData(k,:) = couleurs(k,:); end
        set(ax3, 'XTick', 1:3, 'XTickLabel', methodes, 'YScale', 'log');
        title(ax3, 'Pertes actives totales (MW)');
        ylabel(ax3, 'Pertes (MW)');
        grid(ax3, 'on');
        ylim(ax3, [0.01, max(pertes, [], 'omitnan') * 2]);
        text(ax3, 1:3, pertes, arrayfun(@(x) sprintf('%.2f', x), pertes, 'UniformOutput', false), ...
             'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');

        % ---- Subplot 4 : Tensions par Bus ----
        ax4 = uiaxes(parent_panel, 'Position', positions(4,:));
        b4 = bar(ax4, tensions);
        for k = 1:3, b4(k).FaceColor = couleurs(k,:); end
        set(ax4, 'XTick', 1:donnees_systeme.nbus);
        title(ax4, 'Amplitudes de tension par bus (pu)');
        xlabel(ax4, 'Numéro du bus');
        ylabel(ax4, 'Tension (pu)');
        grid(ax4, 'on');
        legend(ax4, methodes, 'Location', 'best');

    else

        % --- MODE EXTERNE : fenêtre figure classique ---
        set(0, 'DefaultFigureVisible', 'on');

        figure('Name', 'Comparaison des méthodes d''écoulement de puissance', ...
               'NumberTitle', 'off', 'Color', 'w', 'Units', 'normalized', 'Position', [0.1 0.1 0.8 0.7]);

        subplot(2,2,1);
        b1 = bar(iters, 'FaceColor', 'flat');
        for k = 1:3, b1.CData(k,:) = couleurs(k,:); end
        set(gca, 'XTick', 1:3, 'XTickLabel', methodes, 'YScale', 'log');
        title('Nombre d''itérations'); ylabel('Itérations'); grid on;
        ylim([0.5, max(iters, [], 'omitnan') * 2]);
        text(1:3, iters, arrayfun(@(x) num2str(x), iters, 'UniformOutput', false), ...
             'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');

        subplot(2,2,2);
        b2 = bar(temps, 'FaceColor', 'flat');
        for k = 1:3, b2.CData(k,:) = couleurs(k,:); end
        set(gca, 'XTick', 1:3, 'XTickLabel', methodes);
        title('Temps d''exécution (secondes)'); ylabel('Temps (s)'); grid on;
        ylim([0, max(temps, [], 'omitnan') * 1.2 + 0.001]);
        text(1:3, temps, arrayfun(@(x) sprintf('%.4f', x), temps, 'UniformOutput', false), ...
             'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');

        subplot(2,2,3);
        b3 = bar(pertes, 'FaceColor', 'flat');
        for k = 1:3, b3.CData(k,:) = couleurs(k,:); end
        set(gca, 'XTick', 1:3, 'XTickLabel', methodes, 'YScale', 'log');
        title('Pertes actives totales (MW)'); ylabel('Pertes (MW)'); grid on;
        ylim([0.01, max(pertes, [], 'omitnan') * 2]);
        text(1:3, pertes, arrayfun(@(x) sprintf('%.2f', x), pertes, 'UniformOutput', false), ...
             'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');

        subplot(2,2,4);
        b4 = bar(tensions);
        for k = 1:3, b4(k).FaceColor = couleurs(k,:); end
        set(gca, 'XTick', 1:donnees_systeme.nbus);
        title('Amplitudes de tension par bus (pu)');
        xlabel('Numéro du bus'); ylabel('Tension (pu)'); grid on;
        legend(methodes, 'Location', 'best');

    end
end

% =========================================================
