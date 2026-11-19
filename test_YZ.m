function test_YZ(~, ~)
   
    Y = calcul_Ybus(handles.nbus, handles.linedata, handles.nbr);
    Z = construire_Zbus_direct(handles.nbus, handles.linedata);
    I_test = Y * Z;
    err = max(max(abs(I_test - eye(handles.nbus))));
    
    % Afficher la matrice Y*Z
    str = afficher_matrice('Y * Z (devrait être identité)', I_test);
    % Ajouter l'erreur en dernière ligne
    str{end+1} = sprintf('Erreur max par rapport à I : %e', err);
    
    set(handles.hResult, 'String', str);
end