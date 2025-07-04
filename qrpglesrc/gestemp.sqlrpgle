**free
// =======================================================================================
// \brief Projet CONSO REST with JSON/SQL
// \author novy
// \date
// \warning No warning
// ---------------------------------------------------------------------------------------
// \info :
//      appelle de l'api rest https://fakerestapi.azurewebsites.net/index.html
//      liste des activités https://fakerestapi.azurewebsites.net/api/v1/Activities
// ---------------------------------------------------------------------------------------
// \info compilation :
//      CRTSQLRPGI OBJ(GNIVET/GESTEMP) SRCFILE(GNIVET/QRPGLESRC) CLOSQLCSR(*ENDMOD)
//        OPTION(*EVENTF) DBGVIEW(*SOURCE) TGTRLS(*CURRENT) RPGPPOPT(*LVL2)
//      .................................................................................
// ---------------------------------------------------------------------------------------
//
// \rev  dd.mm.ccyy
//      .................................................................................
//      .................................................................................
// =======================================================================================
/if defined(*CRTBNDRPG)
ctl-opt dftactgrp(*no)
         actgrp(*new);
/endif
ctl-opt option(*nodebugio:*srcstmt:*nounref)
        bnddir('QC2LE')
        main(main);
/include QPrtSrc,global
dcl-f gestemp workstn indds(Dspf) infds(fichierDS) sfile(F1E:SFRRN);
dcl-ds f2DS likerec(F2 :*all);
dcl-ds Dspf qualified ;
  exit ind pos(3) ;
  invite ind pos(4);
  refresh ind pos(5) ;
  add ind pos(6);
  confirm ind pos(9);
  abort ind pos(12);
  sflDsp ind pos(30);
  sflDspCtl ind pos(31);
  sflClr ind pos(32);
  sflEnd ind pos(33);
  sflNxtChg ind pos(34);
  sflRollup ind pos(35);
  protectF2 ind pos(38);
  protectSF ind pos(39);
  error ind pos(99);
end-ds;
dcl-ds fichierDS qualified;
  ligne    INT(3) POS(370); // curseur : ligne
  colonne  INT(3) POS(371); // curseur : colonne
  rang_sfl INT(5) POS(376);
  premier_rang_affiche INT(5) POS(378);
  nbrcd_sfl INT(5) POS(380);
  wlico     INT(5) POS(382); // position curseur, mais dans la fenêtre active
end-ds;
dcl-c GNBLIGNESOUSFICHIER  13;
dcl-c GBLUE x'3a';
dcl-c GBLUE_RI x'3b';
dcl-ds FMT_EMPLOYE ext extname('VEMP') qualified end-ds;
dcl-s FMTFIRSTNAME char(12);
dcl-s FMTLASTNAME char(15);
dcl-ds gSelectDS;
  // champs pour filtrer les items de la liste
  SLEMPNO like(FMT_EMPLOYE.EMPNO) inz;
  SLFIRSTNME like(FMTFIRSTNAME) inz;
  SLLASTNAME like(FMTLASTNAME) inz;
  SLMIDINIT like(FMT_EMPLOYE.MIDINIT) inz;
  SLWORKDEPT like(FMT_EMPLOYE.WORKDEPT) inz;
end-ds;
// le filtre t-il été modifié ?
dcl-ds gSaveSelectDS likeDS(gSelectDS);

dcl-ds gSFLDS;
  // champs pour afficher les items de la liste (sous-fichier)
  SFEMPNO like(FMT_EMPLOYE.EMPNO) inz;
  SFFIRSTNME like(FMTFIRSTNAME) inz;
  SFLASTNAME like(FMTLASTNAME) inz;
  SFMIDINIT like(FMT_EMPLOYE.MIDINIT) inz;
  SFWORKDEPT like(FMT_EMPLOYE.WORKDEPT) inz;
end-ds;
dcl-ds gSflListe template qualified;
  // une page du sous-fichier
  dcl-ds SflItem dim(gNBLIGNESOUSFICHIER) likeds(gSFLDS);
end-ds;

dcl-ds gF2DS;
  // champs pour mettre à jour ou détail d'un item de la liste (formulaire)
  F2EMPNO like(FMT_EMPLOYE.EMPNO) inz;
  F2FIRSTNME like(FMTFIRSTNAME) inz;
  F2LASTNAME like(FMTLASTNAME) inz;
  F2MIDINIT like(FMT_EMPLOYE.MIDINIT) inz;
  F2WORKDEPT like(FMT_EMPLOYE.WORKDEPT) inz;
end-ds;


dcl-s gInit ind;
dcl-s gFin_Sfl ind;
dcl-s gFin_Pgm ind;
dcl-s gFin_Pgm2 ind;
dcl-s gSflEnd ind;
dcl-c GQUOTE '''';
dcl-c GCREATION '***   CREATION   ***';
dcl-c GMODIFICATION '*** MODIFICATION ***';
dcl-c GCONSULTATION '*** CONSULTATION ***';


// pgm principal
dcl-pr main extpgm('GESTEMP')
end-pr;
dcl-proc  main;
  dcl-pi *N;
  end-pi;
  dcl-ds lError likeDS(errorItem);
  dcl-s ErrorHappened ind ;
  Exec sql
  SET OPTION DATFMT = *ISO, COMMIT = *NONE;
  // initailisation
  if not initTrt();
    return;
  endif;
  // traitement general
  // initialisation du sous-fichier.
  initSfl();
  // chargement du sous-fichier.
  ChgtSfl();
  Dow not gFin_Pgm;
    affSfl();
  EndDo;
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

dcl-proc userFeedBack;
  // affichage d'un message utilisateur (fenétre)
  dcl-pi *N;
    pError likeDS(errorItem) Const;
  end-pi;
  // TODO: ajouter un format d'ecran pour restituer l'erreur
  return;
end-proc;

dcl-proc initTrt;
  dcl-pi *N ind;
  end-pi;
  dcl-s ErrorHappened ind ;
  dcl-ds lError likeDS(errorItem);
  clear lError;
  clear gSelectDS;
  clear gSaveSelectDS;
  gFin_Pgm =*off;
  $NOMPGM = %trim(GLOBAL_Pgm.ProcPgm);
  Tfonctions = 'F3=Sortie F5=Réafficher                         '+
                      '   F12=Retour ' ;

  return *on;
  on-exit ErrorHappened;
    if ErrorHappened;
      snd-msg *escape ('Horreur ! dans ' + %trim(GLOBAL_Pgm.Proc));
      return *off;
    endif;
end-proc;

dcl-proc initSfl;
  dcl-pi *N;
  end-pi;
  dcl-s ErrorHappened ind ;
  dcl-ds lError likeDS(errorItem);

  clear lError;
  // Clear du sous fichier.
  clear SFRRN;
  Dspf.sflEnd = *on;
  Dspf.sflClr = *on;
  Dspf.sflDsp = *off;
  Dspf.sflDspctl = *off;
  Dspf.protectSF = *off;
  Write F1c ;
  Dspf.sflClr = *off;
  Dspf.sflDspctl = *on;
  gInit = *on;
  return;
  on-exit ErrorHappened;
    if ErrorHappened;
      snd-msg *escape ('Horreur ! dans ' + %trim(GLOBAL_Pgm.Proc));
      return;
    endif;
end-proc;
dcl-proc ChgtSfl;
  dcl-pi *N;
  end-pi;
  dcl-s ErrorHappened ind ;
  dcl-ds lError likeDS(errorItem);
  dcl-ds lListeSFL likeDs(gSflListe) inz;
  dcl-s lItem like(SFRRN);
  dcl-s lNbLigneSFL like(SFRRN);
  clear lError;
  // Initialisation des variables
  Dspf.SflDsp   = *on;
  clear lNbLigneSFL;

  // Positionnement saisi ?
  If gSelectDS <> gSaveSelectDS
       and not Dspf.sflRollup;
    // on recharge la liste cad le curseur
    gInit = *on;
  Endif ;
  // chargement de la liste
  clear lListeSFL;
  gFin_Sfl = getListeSousFichier(gSelectDS:gInit:lListeSFL);

  clear lItem;
  lItem = 1;
  SFRRN = fichierDS.nbrcd_sfl;
  Dow lNbLigneSFL < gNBLIGNESOUSFICHIER and
        lListeSFL.SflItem(lItem).SFEMPNO <> *blanks;
    SFRRN += 1;
    lNbLigneSFL += 1;

    SFCHOIX    = *blanks;
    clear gSFLDS;
    eval-corr gSFLDS = lListeSFL.SflItem(lItem);
    lItem += 1;

    Write F1E   ;
  EndDo;

  If lNbLigneSFL < gNBLIGNESOUSFICHIER;
    gFin_Sfl = *on;
  EndIf;
  // est ce qu'il y a des enregistrements ?
  Select;
    When fichierDS.nbrcd_sfl > *zeros and gFin_Sfl = *on;
      Dspf.sflEnd = *on;
    When fichierDS.nbrcd_sfl = *zeros;
      Dspf.sflDsp = *off;
      Write BAsPage  ;
      Write Fvide    ;
    Other;
      Dspf.sflEnd = *off;
  EndSl;

  gInit = *off;

  on-exit ErrorHappened;
    if ErrorHappened;
      snd-msg *escape ('Horreur ! dans ' + %trim(GLOBAL_Pgm.Proc));
      return;
    endif;

end-proc;
dcl-proc affSfl;
  dcl-pi *N;
  end-pi;
  dcl-s ErrorHappened ind ;
  dcl-ds lError likeDS(errorItem);
  clear lError;
  // Affichage de l'écran
  Write BasPage;
  ExFmt F1C;

  Select;
      // F3=Fin
    When Dspf.exit;
      gFin_Pgm = *on;

      // F05=Rafraichir
    When Dspf.refresh;
      clear gSelectDS;
      clear gSaveSelectDS;
      initSfl();
      ChgtSfl();

      // F6=Créer
    When Dspf.add;

      // F12=Annuler
    When Dspf.abort;
      gFin_Pgm = *on;

      // Rollup=pagination
    When Dspf.sflRollup;
      ChgtSfl();

      // Other
    Other;
      Dspf.error = *off;
      If Dspf.sflDsp;
        lectSfl();
      Endif;

      // Positionnement ?
      If gSelectDS <> gSaveSelectDS;
        initSfl();
        ChgtSfl();
      EndIf;

  EndSl;
  return;
  on-exit ErrorHappened;
    if ErrorHappened;
      snd-msg *escape ('Horreur ! dans ' + %trim(GLOBAL_Pgm.Proc));
      return;
    endif;

end-proc;

dcl-proc lectSfl;
  dcl-pi *N;
  end-pi;
  dcl-s ErrorHappened ind ;
  dcl-ds lError likeDS(errorItem);
  // Initialisation
  clear lError;
  Readc F1E  ;
  Dow not %eof();
    Select;
        // 2 = Modifier
        // -----------------------
      When SFCHOIX    = '2';
        gFin_Pgm    = *off;
        mode = gMODIFICATION;
        if Modification(SFEMPNO);
          // on recharge les zones modifiées.
          SFEMPNO = F2EMPNO;
          SFFIRSTNME = F2FIRSTNME;
          SFLASTNAME = F2LASTNAME;
          SFMIDINIT = F2MIDINIT;
          SFWORKDEPT = F2WORKDEPT;
          SFRRN = fichierDS.rang_SFL;
        endif;
        // 4 = Supprimer
        // -----------------------
      When SFCHOIX    = '4';
        mode = gCONSULTATION;
        //             Suppression(SFL96ID);
        // 5 = Consulter
        // -----------------------
      When SFCHOIX    = '5';
        mode = gCONSULTATION;
        Consultation(SFEMPNO);
    EndSl;
    clear SFCHOIX;
    Dspf.sflNxtChg = *on;

    Dspf.protectSF = *off;
    Update F1E ;
    Readc F1E  ;
  EndDo;

  return;
  on-exit ErrorHappened;
    if ErrorHappened;
      snd-msg *escape ('Horreur ! dans ' + %trim(GLOBAL_Pgm.Proc));
      return;
    endif;

end-proc;


dcl-proc Consultation;
  dcl-pi *N;
    uuid like(FMT_EMPLOYE.EMPNO);
  end-pi;
  dcl-s ErrorHappened ind ;
  dcl-ds lError likeDS(errorItem);

  // Initialisation
  clear lError;
  Dspf.protectF2 = *on;
  Tfonction2 = 'F3=Sortie  F12=Retour    ';

  Dspf.error = *off;
  // Chargement des zones de l'écran.
  clear gF2DS;
  chargementDetail(uuid);
  // Consultation
  Dow 1=1;
    Exfmt F2 ;
    // Exfmt F2 f2DS;

    select;
      when Dspf.exit;
        gFin_Pgm = *on;
        return;
      when Dspf.abort;
        return;
    Endsl;
  Enddo;
  return;
  on-exit ErrorHappened;
    if ErrorHappened;
      snd-msg *escape ('Horreur ! dans ' + %trim(GLOBAL_Pgm.Proc));
      return;
    endif;

end-proc;


dcl-proc Modification;
  dcl-pi *N ind;
    uuid like(FMT_EMPLOYE.EMPNO);
  end-pi;
  dcl-s ErrorHappened ind ;
  dcl-ds lError likeDS(errorItem);

  // Initialisation
  clear lError;
  Dspf.protectF2 = *off;
  Tfonction2 =
                 'F3=Sortie '+ gBlue_RI+'F9=VALIDER'+ gBlue + '       '
                    + '                F12=Retour ' ;

  Dspf.error = *off;
  // Chargement des zones de l'écran.
  clear gF2DS;
  chargementDetail(uuid);
  // Consultation
  Dow 1=1;
    Exfmt F2 ;
    select;
      when Dspf.invite;
        invite();
      when Dspf.exit;
        gFin_Pgm = *on;
        return *off;
      when Dspf.abort;
        return *off;
        // Validation Modification
      When Dspf.confirm And not dspf.error;
        // controle des infos.
        clear lError;
        Dspf.error = *off;
        if not isValid(lError);
          Dspf.error = *on;
          WMSG = lError.code;
          select;
            When lError.nomZone ='F2LASTNAME';
              row = 10;
              col = 10;
            When lError.nomZone ='F2FIRSTNME';
              row = 12;
              col = 13;
            When lError.nomZone ='F2MIDINIT';
              row = 14;
              col = 15;
            other;
          endsl;
          //                Msgerr2 = %trim(error);
          iter;
        endif;
        // Demande de confirmation  ?
        if isConfirm();
          // mise à jour.
          modifieVille();
          // retour ecran precedent.
          return *on;
        endif;
    Endsl;
  Enddo;
  return *off;
  on-exit ErrorHappened;
    if ErrorHappened;
      snd-msg *escape ('Horreur ! dans ' + %trim(GLOBAL_Pgm.Proc));
      return *off;
    endif;
end-proc;
dcl-proc invite;
  dcl-pi *N;
  end-pi;
  dcl-s ErrorHappened ind ;
  dcl-ds lError likeDS(errorItem);
  dcl-s lCodeDepartement like(FMT_EMPLOYE.WORKDEPT);
  dcl-s lNumerorEmploye like(FMT_EMPLOYE.EMPNO);
  dcl-pr getEmploye extpgm('INVITEEMP');
    pCodeDepartement like(FMT_EMPLOYE.WORKDEPT);
    pNumerorEmploye like(FMT_EMPLOYE.EMPNO);
  end-pr;
  clear lError;
  select;
    when rec= 'F2' and fld ='F2LASTNAME';
      clear lCodeDepartement;
      clear lNumerorEmploye;
      getEmploye(lCodeDepartement:lNumerorEmploye);
      if lNumerorEmploye <> *blanks;
        F2LASTNAME = lNumerorEmploye;
      endif;
    other;
  endsl;
  return;
  on-exit ErrorHappened;
    if ErrorHappened;
      snd-msg *escape ('Horreur ! dans ' + %trim(GLOBAL_Pgm.Proc));
      return;
    endif;

end-proc;

dcl-proc modifieVille;
  dcl-pi *N;
  end-pi;
  dcl-s ErrorHappened ind ;
  dcl-ds lError likeDS(errorItem);

  clear lError;
  exec sql
    update employee
    set (FIRSTNME, LASTNAME)
    =
    (:F2FIRSTNME,:F2LASTNAME)
    where EMPNO = :F2EMPNO;

  Select;
    When SqlCode < 0;
      clear lError;
      exec sql
           get diagnostics condition 1 :lError.text = MESSAGE_TEXT;
      snd-msg *escape ('Horreur ! dans ' + %trim(GLOBAL_Pgm.Proc));
      userFeedBack(lError);
    When SqlCode = 100;
      lError.text = '?? ligne non trouvée pour ID : ' +
                      %Trim(F2EMPNO) + ' .';

    other;
  Endsl;

  return;
  on-exit ErrorHappened;
    if ErrorHappened;
      snd-msg *escape ('Horreur ! dans ' + %trim(GLOBAL_Pgm.Proc));
      return;
    endif;

end-proc;

dcl-proc isValid;
  dcl-pi *N ind;
    Error likeDS(errorItem);
  end-pi;
  dcl-s ErrorHappened ind ;
  clear Error;
  if F2LASTNAME = *blanks;
    Error.text = 'bug bug!';
    Error.nomzone = 'F2LASTNAME';
    Error.code = 'DFN0281';
    return *off;
  endif;
  return *on;
  on-exit ErrorHappened;
    if ErrorHappened;
      snd-msg *escape ('Horreur ! dans ' + %trim(GLOBAL_Pgm.Proc));
      return *off;
    endif;
end-proc;


dcl-proc isConfirm;
  dcl-pi *N ind;
  end-pi;
  dcl-s ErrorHappened ind ;
  dcl-ds lError likeDS(errorItem);

  clear lError;
  return *on;
  on-exit ErrorHappened;
    if ErrorHappened;
      snd-msg *escape ('Horreur ! dans ' + %trim(GLOBAL_Pgm.Proc));
      return *off;
    endif;

end-proc;

dcl-proc chargementDetail;
  dcl-pi *N;
    uuid like(FMT_EMPLOYE.EMPNO) const;
  end-pi;
  dcl-s ErrorHappened ind ;
  dcl-ds lError likeDS(errorItem);
  dcl-ds lDetail likeds(gF2DS);
  // Initialisation
  clear lError;
  clear gF2DS;
  // Chargement des zones de l'écran.
  exec sql
    SELECT
    EMPNO,FIRSTNME, LASTNAME, MIDINIT,WORKDEPT
    into :lDetail
    FROM employee
    where EMPNO = :uuid;
  Select;
    When SqlCode < 0;
      clear lError;
      exec sql
           get diagnostics condition 1 :lError.text = MESSAGE_TEXT;
      userFeedBack(lError);
    When SqlCode = 100;
      WMSG = 'DFN0137';
      Dspf.error = *on;
      return;
    other;
      gF2DS  = lDetail;
  Endsl;

  return;
  on-exit ErrorHappened;
    if ErrorHappened;
      snd-msg *escape ('Horreur ! dans ' + %trim(GLOBAL_Pgm.Proc));
      return;
    endif;

end-proc;
dcl-proc getListeSousFichier;
  dcl-pi *N ind;
    selectDS likeds(gSelectDS) const;
    isInit like(gInit) const;
    listeSFL likeDs(gSflListe);
  end-pi;
  dcl-s ErrorHappened ind ;
  dcl-ds lError likeDS(errorItem);
  dcl-s lRequete varchar(5000) inz;
  dcl-s lFrom like(lRequete);
  dcl-s lGroupBy like(lRequete);
  dcl-s lOrderBy like(lRequete);
  dcl-s lSelect like(lRequete);
  dcl-s lWhere like(lRequete);
  dcl-s lFirst ind;
  dcl-s lEndOFList ind;
  dcl-s nbligne zoned(4:0)  inz(gNBLIGNESOUSFICHIER);
  dcl-ds lSflItem dim(gNBLIGNESOUSFICHIER) likeds(gSFLDS);

  clear lError;
  clear listeSFL;
  // Traitement
  if isInit;
    gSaveSelectDS = gSelectDS;
    // on reinitalise la requete
    clear lRequete;
    clear lSelect;
    clear lFrom;
    clear lGroupBy;
    clear lOrderBy;
    clear lWhere;
    // Select
    lSelect = 'select ' +
        'EMPNO, FIRSTNME,LASTNAME, MIDINIT,WORKDEPT' ;
    // From
    lFrom = 'from VEMP ';
    // Where
    lWhere = 'Where ';
    lFirst = *on;
    if selectDS.SLEMPNO <> *blanks;
      IF lFirst;
        lFirst = *off;
      ELSE;
        lWhere = %trim(lWhere) + ' and ';
      ENDIF;
      lWhere = %trim(lWhere) +
               ' EMPNO  like ' +  gQUOTE +
               '%' + %trim(selectDS.SLEMPNO) + '%' + gQUOTE;
    endif;

    if selectDS.SLFIRSTNME <> *blanks;
      IF lFirst;
        lFirst = *off;
      ELSE;
        lWhere = %trim(lWhere) + ' and ';
      ENDIF;
      lWhere = %trim(lWhere) +
               ' FIRSTNME  like ' +  gQUOTE +
               '%' + %trim(selectDS.SLFIRSTNME) + '%' + gQUOTE;
    endif;
    if selectDS.SLLASTNAME <> *blanks;
      IF lFirst;
        lFirst = *off;
      ELSE;
        lWhere = %trim(lWhere) + ' and ';
      ENDIF;
      lWhere = %trim(lWhere) +
               ' LASTNAME  like ' +  gQUOTE +
               '%' + %trim(selectDS.SLLASTNAME) + '%' + gQUOTE;
    endif;
    if selectDS.SLWORKDEPT <> *blanks;
      IF lFirst;
        lFirst = *off;
      ELSE;
        lWhere = %trim(lWhere) + ' and ';
      ENDIF;
      lWhere = %trim(lWhere) +
               ' WORKDEPT  like ' +  gQUOTE +
               '%' + %trim(selectDS.SLWORKDEPT) + '%' + gQUOTE;
    endif;

    IF lFirst;
      Clear lWhere;
    ENDIF;
    lOrderBy = ' Order by FIRSTNME, LASTNAME';
    // RequÃªte finale
    lRequete  = %trim(lSelect)  + ' ' +
                  %trim(lFrom)    + ' ' +
                  %trim(lWhere)   + ' ' +
                  %trim(lOrderBy) + ' for read only';
    // Clôture du curseur
    monitor;
      Exec Sql close cListTable;
    on-error;
    endmon;
    // Prepare
    Exec sql prepare SqlStmt3 From :lRequete;
    // PrÃ©paration du curseur
    Exec sql declare cListTable cursor for
               SqlStmt3  ;
    // Ouverture du curseur
    Exec SQL open cListTable;
  endif;
  clear lSflItem;
  // Lecture suivante du curseur
  Exec SQL Fetch Next
            From cListTable
                      For  :nbligne rows
                      Into :lSflItem;

  // Check SQLCODE:
  lEndOFList = *off;
  Select;
    When SqlCode < 0;
      clear lError;
      exec sql
           get diagnostics condition 1 :lError.text = MESSAGE_TEXT;
      userFeedBack(lError);
      Return *on;
    When SqlCode = 100;
      return *on;
    other;
      listeSFL.SflItem  = lSflItem;
    Endsl;
  // Finalisation
  Return *off;

  on-exit ErrorHappened;
    if ErrorHappened;
      snd-msg *escape ('Horreur ! dans ' + %trim(GLOBAL_Pgm.Proc));
      return *on;
    endif;

end-proc;