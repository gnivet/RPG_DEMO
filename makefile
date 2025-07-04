BIN_LIB=CMPSYS
LIBLIST=$(BIN_LIB) SAMPLE
SHELL=/QOopenSys/usr/bin/qsh

ALL:gestemp.sqlrpgle invitemp.sqlrpgle 

gestemp.sqlrpgle : gestemp.dspf
invitemp.sqlrpgle : invitemp.dspf


%.sqlrpgle:

system -s "CHGATR OBJ('.qrpglesrc/$*.sqlrpgle')" ATR(*CCSID) VALUE(1252)"
liblist -a $(LIBLIST);\
system "CRTSQLRPGI OBJ ($(BIN_LIB)/$*) SRCSTMF('./qrpglesrc/$*.sqlrpgle') COMMIT(*SOURCE) OPTION(*EVENT)"

%.dspf:

-system -qi "CRTSRCPF FILE ($(BIN_LIB)/QDDSSRC) RCDLEN(112)" 
system "CPYFRMSMTF FROMSMTF('./QDDSSRC/$*.dspf') TOMBR('/QSYS.lib/$(BIN_LIB).lib'/QDDSSRC.file/$*.mbr') MBROPT(*REPLACE)"
system "-s CRTDSPF FILE ($(BIN_LIB)/$*) SRCFILE($(BIN_LIB)/QDDSSRC) SRCMBR($*)"