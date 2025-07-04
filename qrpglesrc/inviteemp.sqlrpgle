**free
/if defined(*CRTBNDRPG)
ctl-opt dftactgrp(*no)
         actgrp(*new);
/endif
Ctl-Opt BndDir('QC2LE')
        Option(*nodebugio:*srcstmt:*nounref)
         main(main);
/include QPrtSrc,global
dcl-f INVITEEMP workstn indds(Dspf) infds(fichierDs) sfile(SFL01:SFRRN);

dcl-ds Dspf qualified ;
  refresh ind pos(5) ;
  abort ind pos(12);
  sflDsp ind pos(30);
  sflDspCtl ind pos(31);
  sflClr ind pos(32);
  sflEnd ind pos(33);
  sflRollup ind pos(35);
  error ind pos(99);
end-ds;
dcl-ds fichierDS qualified;
  ligne    INT(3) POS(370); // curseur : ligne
  colonne  INT(3) POS(371); // curseur : colonne
  rang_sfl INT(5) POS(376);
  premier_rang_affiche INT(5) POS(378); // placé dans SFLRCNBR on réaffiche même page !
  nbrcd_sfl INT(5) POS(380);
  // position curseur, mais dans la fenêtre active
  posCurseur  INT(5) POS(382);
end-ds;
dcl-ds CTLDS likerec(CTL01 :*all) template;
dcl-c gNBLIGNESOUSFICHIER  12; // SLFSIZE du sous-fichier
dcl-ds gSFLDS;
  SFID;
  SFLIB;
end-ds;
dcl-ds gSflListe template qualified;
  dcl-ds SflItem dim(gNBLIGNESOUSFICHIER) likeds(gSFLDS);
end-ds;
dcl-ds FMT_VUE ext extname('VEMP') qualified end-ds;
dcl-ds gIN qualified;
  codeDepartement like(FMT_VUE.WORKDEPT);
end-ds;
dcl-ds gOut qualified;
  numeroEmploye like(FMT_VUE.EMPNO);
end-ds;
dcl-s gRechargeCurseur ind;
dcl-s gCreateCurseur ind;
dcl-s gFinPgm ind;
dcl-s gFinListe ind;
dcl-ds gFiltreListe;
   SLLIB like(CTLDS.SLLIB) inz;
end-ds;
dcl-ds gSaveFiltreListe likeDS(gFiltreListe);
 //------------------------------------------------------------- *
dcl-proc  main;
  dcl-pi *N;
    pIn likeDS(gIN) const;
    pOut likeDS(gOut);
  end-pi;
  dcl-s ErrorHappened ind ;
  dcl-ds lError likeDS(errorItem);
  dcl-ds lIn likeDs(gIN);
  Exec sql
  SET OPTION DATFMT = *ISO, COMMIT = *NONE;
    // initialilisation
  clear pOut;
  lIn =pIn;
  if not initTrt(lIn);
    clear lError;
    lError.textUser = 'horreur !';
    userFeedBack(lError);
    snd-msg *escape (lError.textUser + %trim(%proc()));
    return;
  endif;
  // traitement general
  // initialisation du sous-fichier.
  if not initSfl();
    // horreur à gérer.
  endif;
  // chargement du sous-fichier.
  if not ChgtSfl();
    // horreur à gérer.
  endif;

  Dow not gFinPgm;
    if not AffSfl();
      leave;
    endif;
  EndDo;
  pOut = gOut;
  snd-msg *INFO %char(pOut);
  on-exit ErrorHappened;
    if ErrorHappened;
      snd-msg *escape ('Horreur ! dans ' +
                 %trim(GLOBAL_Pgm.ProcPgm) + '.' +
                 %trim(GLOBAL_Pgm.Proc));
    else;
    // cKool
    endif;
  return;
end-proc;

dcl-proc initTrt;
  dcl-pi *N ind;
    pIn likeDS(gIN);
  end-pi;
  dcl-s ErrorHappened ind ;
  dcl-ds lError likeDS(errorItem);
  // initialisation des variables
  clear lError;
  $NOMPGM = %trim(GLOBAL_Pgm.ProcPgm);
  gFinPgm = *off;
  clear gSaveFiltreListe;
  clear gFiltreListe;
  gCreateCurseur = *on;
  if pIn.codeDepartement = *blanks;
    // erreur eventuelle à gérer mais là non !
    pIn.codeDepartement = 'A00';
  endif;
  gIN = pIn;
  clear SLLIB;
  return *on;
  on-exit ErrorHappened;
    if ErrorHappened;
      snd-msg *escape ('Horreur ! dans ' + %trim(GLOBAL_Pgm.Proc));
      return *off;
    else;
      return *on;
    endif;
end-proc;

// FeedBack to the endUser.
dcl-proc userFeedBack;
  dcl-pi *N;
    pError likeDS(errorItem) Const;
  end-pi;
  // TODO: ajouter un format d'ecran pour restituer l'erreur
  return;
end-proc;

dcl-proc initSfl;
  dcl-pi *N ind;
  end-pi;
  dcl-s ErrorHappened ind ;
  dcl-ds lError likeDS(errorItem);
  // initialisation
  clear lError;
  // traitement
  // Clear du sous fichier.
  clear SFRRN;
  Dspf.sflEnd = *on;
  Dspf.sflClr = *on;
  Dspf.sflDsp = *off;
  Dspf.sflDspctl = *off;
  Write CTL01;
  Dspf.sflClr = *off;
  Dspf.sflDspctl = *on;
  gRechargeCurseur = *on;

  return *on;
  on-exit ErrorHappened;
    if ErrorHappened;
      snd-msg *escape ('Horreur ! dans ' + %trim(GLOBAL_Pgm.Proc));
      return *off;
    else;
      return *on;
    endif;
end-proc;

dcl-proc ChgtSfl;
  dcl-pi *N ind;
  end-pi;
  dcl-ds lError likeDS(errorItem);
  dcl-ds lListeSFL likeDs(gSflListe) inz;
  dcl-s ErrorHappened ind ;
  dcl-ds lItem likeDS(gSflListe.SflItem);
  // Initialisation
  Dspf.SflDsp   = *on;
  // Positionnement saisi ?
  If gFiltreListe <> gSaveFiltreListe
       and not dspf.sflRollup;
    // on recharge le curseur
    gRechargeCurseur = *on;
  Endif ;
  // chargement de la liste
  clear lListeSFL;
  gFinListe = getListeSousFichier(gFiltreListe
                    :gRechargeCurseur:lListeSFL);
  // chargement du sous-fichier
  SFRRN = fichierDS.nbrcd_sfl;
  for-each lItem in lListeSFL.SflItem;
    if lItem.SFID = *blanks;
      gFinListe = *on;
      leave;
    endif;
    SFRRN += 1;
    $CHOIX   = *blanks;
    clear gSFLDS;
    eval-corr gSFLDS = lItem;
    Write SFL01;
  endfor;
  // est ce qu'il y a des enregistrements ?
  if fichierDS.nbrcd_sfl > *zeros;
    pospage = fichierDS.nbrcd_sfl;
  endif;
  Select;
    When fichierDS.nbrcd_sfl > *zeros and gFinListe = *on;
         Dspf.sflEnd = *on;
    When fichierDS.nbrcd_sfl = *zeros;
      dspf.sflDsp = *off;
        Write WIN01;
        Write CVIDE;
    Other;
        dspf.sflEnd = *off;
  EndSl;
  return *on;
  on-exit ErrorHappened;
    if ErrorHappened;
      snd-msg *escape ('Horreur ! dans ' + %trim(GLOBAL_Pgm.Proc));
      return *off;
    else;
      return *on;
    endif;
end-proc;
dcl-proc affSfl;
  dcl-pi *N ind;
  end-pi;
  dcl-s ErrorHappened ind ;
  dcl-ds lError likeDS(errorItem);

  clear lError;
    //Affichage de l'écran
    Write WIN01;
    ExFmt CTL01;

    //Sauvegarde de la page visualisée

           Select;
           //F05=Rafraichir
           When dspf.refresh;
                clear gFiltreListe;
                clear gSaveFiltreListe;
                InitSfl();
                ChgtSfl();

           //F12=Annuler
           When dspf.abort;
                gFinPgm = *on;

           //Rollup=pagination
           When dspf.sflRollup;
                ChgtSfl();

           //Other
           Other;
           // selection d'un enreg...
            If Dspf.sflDsp;
                lectSfl();
                if gFinPgm;
                  return *on;
                endif;
            Endif;

           //Positionnement ?
            If gFiltreListe <> gSaveFiltreListe;
                initSfl();
                ChgtSfl();
            EndIf;
           EndSl;
  return *on;
  on-exit ErrorHappened;
    if ErrorHappened;
      snd-msg *escape ('Horreur ! dans ' + %trim(GLOBAL_Pgm.Proc));
      return *off;
    else;
      return *on;
    endif;
end-proc;
dcl-proc getListeSousFichier;
  dcl-pi *N ind;
    pFiltreListe likeds(gFiltreListe) const;
    pRechargeCurseur like(gRechargeCurseur) const;
    pListe likeDs(gSflListe);
  end-pi;
  dcl-s ErrorHappened ind ;
  dcl-ds lError likeDS(errorItem);
  // dcl-s lFiltreLib like(CTLDS.SLLIB);
  dcl-s lFiltreLib char(32);
  dcl-ds item template qualified;
    empno char(6);
    lib char(32);
  end-ds;
  dcl-ds listeItem likeds(item) dim(gNBLIGNESOUSFICHIER);
  dcl-s lNbligne zoned(4:0)  inz(gNBLIGNESOUSFICHIER);
    // initialisation
    clear lError;
    clear pListe;
    clear lFiltreLib;
    lFiltreLib = '%' + %trim(pFiltreListe.SLLIB) + '%';
    // Traitement
    if gCreateCurseur;
      exec sql
        DECLARE C_listeEmploye CURSOR FOR
        SELECT empno,
        cast (trim(FIRSTNME) concat ' ' concat  trim(LASTNAME) as char(32)) libelle
        FROM vemp
        where workdept = :gIN.codeDepartement
        and (trim(FIRSTNME) concat ' ' concat  trim(LASTNAME))
        like trim(:lFiltreLib)
        order by 2
        for fetch only;


      // TODO: testerle sqlstate ou sqlcode et workdept via pIN
      gCreateCurseur = *off;
    endif;
    if pRechargeCurseur;
      gSaveFiltreListe = gFiltreListe;
      //on relance la requete
      Exec Sql
        close C_listeEmploye;
      Exec Sql
        open C_listeEmploye;
      gRechargeCurseur = *off;
    endif;
    clear listeItem;
    //Lecture suivante du curseur
    Exec SQL
      Fetch next
      From C_listeEmploye
      For  :lNbligne rows
      Into :listeItem;

    // Check SQLCODE:
    Select;
      When SqlCode < 0;
            clear lError;
          exec sql
           get diagnostics condition 1 :LError.text = MESSAGE_TEXT;
          userFeedBack(lError);
          Return *on;
      When SqlCode = 100;
          return *on;
      other;
        pListe.SflItem  = listeItem;
      Endsl;
    // Finalisation
      Return *off;

  on-exit ErrorHappened;
    if ErrorHappened;
      snd-msg *escape ('Horreur ! dans ' + %trim(GLOBAL_Pgm.Proc));
      return *on;
    endif;

end-proc;
dcl-proc lectSfl;
  dcl-pi *N ind;
  end-pi;
   dcl-s ErrorHappened ind ;
  dcl-ds lError likeDS(errorItem);
  dcl-s lLignePageModif like(SFRRN) inz;

    // Initialisation
    clear lError;
    clear lLignePageModif;
    Readc SFL01  ;
    Dow not %eof();
      Select;
        //1 = Sélectionner
        //-----------------------
        When $CHOIX    = '1';
          gFinPgm    = *on;
          gOut.numeroEmploye = SFID;
          leave;
        EndSl;
      clear $CHOIX;
      Update SFL01 ;
      Readc SFL01  ;
    EndDo;

    return *on;
   on-exit ErrorHappened;
    if ErrorHappened;
      snd-msg *escape ('Horreur ! dans ' + %trim(GLOBAL_Pgm.Proc));
      return *off;
    else;
      return *on;
    endif;

end-proc;

