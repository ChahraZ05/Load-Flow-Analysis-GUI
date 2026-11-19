function Ybus = calcul_Ybus(nbus, linedata, nbr)
% calcul_Ybus  Calcule la matrice admittance Ybus
%   Ybus = calcul_Ybus(Nbus, linedata)
y_serie=zeros(nbus,nbus);
y_shunt=zeros(nbus,nbus);
y_transfo=zeros(nbus,nbus);
Ybus = zeros(nbus, nbus);
i=1;

while i<=nbr
    nl = linedata(i,1);
    nr = linedata(i,2);
    R = linedata(i,3);
    X = linedata(i,4);
    B2 = linedata(i,5);
    tap = linedata(i,6);
    
    % etape 01: calcul de l'element serie de la ligne
    if tap==1
        y_serie(nl,nr)=1/(R+1j*X);
    else
        y_serie(nl,nr)=1/(tap*(R+1j*X));
    end

    y_serie(nr,nl)=y_serie(nl,nr);

    % etape 02: calcul des elements shunt de la ligne
    y_shunt(nl,nr)=1j*B2;
    y_shunt(nr,nl)=1j*B2;

    % etape 03: calcul des elements shunt apres modelisation des
    % transformateurs
    y_transfo(nl,nr)=(1/(tap*(R+1j*X)))*(-1+1/tap);
    y_transfo(nr,nl)=(1/(R+1j*X))*(1-1/tap);

    i=i+1;
end

    % etape 04: l'expression des elements diagonaux
    Y_diag=y_serie + y_shunt + y_transfo;

    %etape 05: remplissage de la matrice Ybus
    for i=1:nbus
        for j=1:nbus
            % (05-a): remplissage de la diagonale
            if i==j
                k=1;
                while k<=nbus
                    Ybus(i,j)=Ybus(i,j)+Y_diag(i,k);

                    k=k+1;
                end
            else
            % (05-b): remplissage des elements non diagonaux
            Ybus(i,j)=-y_serie(i,j);
            end
        end
    end
end