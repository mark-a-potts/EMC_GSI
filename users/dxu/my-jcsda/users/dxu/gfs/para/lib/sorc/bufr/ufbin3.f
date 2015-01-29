      SUBROUTINE UFBIN3(LUNIT,USR,I1,I2,I3,IRET,JRET,STR)

C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM:    UFBIN3
C   PRGMMR: WOOLLEN          ORG: NP20       DATE: 2003-11-04
C
C ABSTRACT: THIS SUBROUTINE READS SPECIFIED VALUES FROM THE CURRENT
C   BUFR DATA SUBSET WITHIN INTERNAL ARRAYS.  THE DATA VALUES
C   CORRESPOND TO MNEMONICS WHICH ARE PART OF A MULTIPLE-REPLICATION
C   SEQUENCE WITHIN ANOTHER MULTIPLE-REPLICATION SEQUENCE.  THE INNER
C   SEQUENCE IS USUALLY ASSOCIATED WITH DATA "LEVELS" AND THE OUTER
C   SEQUENCE WITH DATA "EVENTS".  THE BUFR FILE IN LOGICAL UNIT LUNIT
C   MUST HAVE BEEN OPENED FOR INPUT VIA A PREVIOUS CALL TO BUFR ARCHIVE
C   LIBRARY SUBROUTINE OPENBF.  IN ADDITION, THE DATA SUBSET MUST HAVE
C   SUBSEQUENTLY BEEN READ INTO THE INTERNAL BUFR ARCHIVE LIBRARY
C   ARRAYS VIA CALLS TO BUFR ARCHIVE LIBRARY SUBROUTINE READMG OR
C   READERME FOLLOWED BY A CALL TO BUFR ARCHIVE LIBRARY SUBROUTINE
C   READSB (OR VIA A SINGLE CALL TO BUFR ARCHIVE LIBRARY
C   SUBROUTINE READNS).  THIS SUBROUTINE IS DESIGNED TO READ EVENT
C   INFORMATION FROM "PREPFITS" TYPE BUFR FILES (BUT NOT FROM
C   "PREPBUFR" TYPE FILES!!).  PREPFITS FILES HAVE THE FOLLOWING BUFR
C   TABLE EVENT STRUCTURE (NOTE SIXTEEN CHARACTERS HAVE BEEN REMOVED
C   FROM THE LAST COLUMN TO ALLOW THE TABLE TO FIT IN THIS DOCBLOCK):
C
C   | ADPUPA   | HEADR  {PLEVL}                                    |
C   | HEADR    | SID XOB YOB DHR ELV TYP T29 ITP                   |
C   | PLEVL    | CAT PRC PQM QQM TQM ZQM WQM CDTP_QM [OBLVL]       |
C   | OBLVL    | SRC FHR <PEVN> <QEVN> <TEVN> <ZEVN> <WEVN> <CEVN> |
C   | OBLVL    | <CTPEVN>                                          |
C   | PEVN     | POB  PMO                                          |
C   | QEVN     | QOB                                               |
C   | TEVN     | TOB                                               |
C   | ZEVN     | ZOB                                               |
C   | WEVN     | UOB  VOB                                          |
C   | CEVN     | CAPE CINH LI                                      |
C   | CTPEVN   | CDTP GCDTT TOCC                                   |
C
C   NOTE THAT THE ONE-BIT DELAYED REPLICATED SEQUENCES "<xxxx>" ARE
C   NESTED INSIDE THE EIGHT-BIT DELAYED REPLIATION EVENT SEQUENCES
C   "[yyyy]".  THE ANALOGOUS BUFR ARCHIVE LIBRARY SUBROUTINE UFBEVN
C   DOES NOT WORK PROPERLY ON THIS TYPE OF EVENT STRUCTURE.  IT WORKS
C   ONLY ON THE EVENT STRUCTURE FOUND IN "PREPBUFR" TYPE BUFR FILES
C   (SEE UFBEVN FOR MORE DETAILS).  IN TURN, UFBIN3 DOES NOT WORK
C   PROPERLY ON THE EVENT STRUCTURE FOUND IN PREPBUFR FILES (ALWAYS USE
C   UFBEVN IN THIS CASE).  ONE OTHER DIFFERENCE BETWEEN UFBIN3 AND
C   UFBEVN IS THAT UFBIN3 RETURNS THE MAXIMUM NUMBER OF EVENTS FOUND
C   FOR ALL DATA VALUES SPECIFIED AS AN OUTPUT ARGUMENT (JRET).  UFBEVN
C   DOES NOT DO THIS, BUT RATHER IT STORES THIS VALUE INTERNALLY IN
C   COMMON BLOCK /UFBN3C/.
C
C PROGRAM HISTORY LOG:
C 2003-11-04  J. WOOLLEN -- ORIGINAL AUTHOR (WAS IN VERIFICATION
C                           VERSION)
C 2003-11-04  D. KEYSER  -- UNIFIED/PORTABLE FOR WRF; ADDED
C                           DOCUMENTATION; OUTPUTS MORE COMPLETE
C                           DIAGNOSTIC INFO WHEN ROUTINE TERMINATES
C                           ABNORMALLY OR UNUSUAL THINGS HAPPEN
C 2009-04-21  J. ATOR    -- USE ERRWRT
C
C USAGE:    CALL UFBIN3 (LUNIT, USR, I1, I2, I3, IRET, JRET, STR)
C   INPUT ARGUMENT LIST:
C     LUNIT    - INTEGER: FORTRAN LOGICAL UNIT NUMBER FOR BUFR FILE
C     I1       - INTEGER: LENGTH OF FIRST DIMENSION OF USR OR THE
C                NUMBER OF BLANK-SEPARATED MNEMONICS IN STR (FORMER
C                MUST BE .GE. LATTER)
C     I2       - INTEGER: LENGTH OF SECOND DIMENSION OF USR
C     I3       - INTEGER: LENGTH OF THIRD DIMENSION OF USR (MAXIMUM
C                VALUE IS 255)
C     STR      - CHARACTER*(*): STRING OF BLANK-SEPARATED TABLE B
C                MNEMONICS IN ONE-TO-ONE CORRESPONDENCE WITH FIRST
C                DIMENSION OF USR
C                  - THERE ARE THREE "GENERIC" MNEMONICS NOT RELATED
C                     TO TABLE B, THESE RETURN THE FOLLOWING
C                     INFORMATION IN CORRESPONDING USR LOCATION:
C                     'NUL'  WHICH ALWAYS RETURNS MISSING (10E10)
C                     'IREC' WHICH ALWAYS RETURNS THE CURRENT BUFR
C                            MESSAGE (RECORD) NUMBER IN WHICH THIS
C                            SUBSET RESIDES
C                     'ISUB' WHICH ALWAYS RETURNS THE CURRENT SUBSET
C                            NUMBER OF THIS SUBSET WITHIN THE BUFR
C                            MESSAGE (RECORD) NUMBER 'IREC'
C
C   OUTPUT ARGUMENT LIST:
C     USR      - REAL*8: (I1,I2,I3) STARTING ADDRESS OF DATA VALUES
C                READ FROM DATA SUBSET
C     IRET     - INTEGER: NUMBER OF "LEVELS" OF DATA VALUES READ FROM
C                DATA SUBSET (MUST BE NO LARGER THAN I2)
C     JRET     - INTEGER: MAXIMUM NUMBER OF "EVENTS" FOUND FOR ALL DATA
C                VALUES SPECIFIED AMONGST ALL LEVELS READ FROM DATA
C                SUBSET (MUST BE NO LARGER THAN I3)
C
C REMARKS:
C    IMPORTANT: THIS ROUTINE SHOULD ONLY BE CALLED BY THE VERIFICATION
C               APPLICATION PROGRAM "GRIDTOBS", WHERE IT WAS PREVIOUSLY
C               AN IN-LINE SUBROUTINE.  IN GENERAL, UFBIN3 DOES NOT
C               WORK PROPERLY IN OTHER APPLICATION PROGRAMS (I.E, THOSE
C               THAT ARE READING PREPBUFR FILES) AT THIS TIME.  ALWAYS
C               USE UFBEVN INSTEAD!!
C
C    THIS ROUTINE CALLS:        BORT     CONWIN   ERRWRT   GETWIN
C                               NEVN     NXTWIN   STATUS   STRING
C    THIS ROUTINE IS CALLED BY: None
C                               SHOULD NOT BE CALLED BY ANY APPLICATION
C                               PROGRAMS EXCEPT GRIDTOBS!!
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 77
C   MACHINE:  PORTABLE TO ALL PLATFORMS
C
C$$$

      INCLUDE 'bufrlib.prm'

      COMMON /MSGCWD/ NMSG(NFILES),NSUB(NFILES),MSUB(NFILES),
     .                INODE(NFILES),IDATE(NFILES)
      COMMON /USRINT/ NVAL(NFILES),INV(MAXSS,NFILES),VAL(MAXSS,NFILES)
      COMMON /USRSTR/ NNOD,NCON,NODS(20),NODC(10),IVLS(10),KONS(10)
      COMMON /QUIET / IPRT

      CHARACTER*(*) STR
      CHARACTER*128 ERRSTR
      REAL*8        VAL,USR(I1,I2,I3)

C----------------------------------------------------------------------
C----------------------------------------------------------------------

      IRET = 0
      JRET = 0

C  CHECK THE FILE STATUS AND I-NODE
C  --------------------------------

      CALL STATUS(LUNIT,LUN,IL,IM)
      IF(IL.EQ.0) GOTO 900
      IF(IL.GT.0) GOTO 901
      IF(IM.EQ.0) GOTO 902
      IF(INODE(LUN).NE.INV(1,LUN)) GOTO 903

      IF(I1.LE.0) THEN
         IF(IPRT.GE.0) THEN
      CALL ERRWRT('+++++++++++++++++++++WARNING+++++++++++++++++++++++')
      ERRSTR = 'BUFRLIB: UFBIN3 - 3rd ARG. (INPUT) IS .LE. 0, ' //
     .   'SO RETURN WITH 6th AND 7th ARGS. (IRET, JRET) = 0; ' //
     .   '8th ARG. (STR) ='
      CALL ERRWRT(ERRSTR)
      CALL ERRWRT(STR)
      CALL ERRWRT('+++++++++++++++++++++WARNING+++++++++++++++++++++++')
      CALL ERRWRT(' ')
         ENDIF
         GOTO 100
      ELSEIF(I2.LE.0) THEN
         IF(IPRT.GE.0) THEN
      CALL ERRWRT('+++++++++++++++++++++WARNING+++++++++++++++++++++++')
      ERRSTR = 'BUFRLIB: UFBIN3 - 4th ARG. (INPUT) IS .LE. 0, ' //
     .   'SO RETURN WITH 6th AND 7th ARGS. (IRET, JRET) = 0; ' //
     .   '8th ARG. (STR) ='
      CALL ERRWRT(ERRSTR)
      CALL ERRWRT(STR)
      CALL ERRWRT('+++++++++++++++++++++WARNING+++++++++++++++++++++++')
      CALL ERRWRT(' ')
         ENDIF
         GOTO 100
      ELSEIF(I3.LE.0) THEN
         IF(IPRT.GE.0) THEN
      CALL ERRWRT('+++++++++++++++++++++WARNING+++++++++++++++++++++++')
      ERRSTR = 'BUFRLIB: UFBIN3 - 5th ARG. (INPUT) IS .LE. 0, ' //
     .   'SO RETURN WITH 6th AND 7th ARGS. (IRET, JRET) = 0; ' //
     .   '8th ARG. (STR) ='
      CALL ERRWRT(ERRSTR)
      CALL ERRWRT(STR)
      CALL ERRWRT('+++++++++++++++++++++WARNING+++++++++++++++++++++++')
      CALL ERRWRT(' ')
         ENDIF
         GOTO 100
      ENDIF

C  PARSE OR RECALL THE INPUT STRING
C  --------------------------------

      CALL STRING(STR,LUN,I1,0)

C  INITIALIZE USR ARRAY
C  --------------------

      DO K=1,I3
      DO J=1,I2
      DO I=1,I1
      USR(I,J,K) = BMISS
      ENDDO
      ENDDO
      ENDDO

C  LOOP OVER COND WINDOWS
C  ----------------------

      INC1 = 1
      INC2 = 1

1     CALL CONWIN(LUN,INC1,INC2,I2)
      IF(NNOD.EQ.0) THEN
        IRET = I2
        GOTO 100
      ELSEIF(INC1.EQ.0) THEN
        GOTO 100
      ELSE
        DO I=1,NNOD
        IF(NODS(I).GT.0) THEN
           INS2 = INC1
           CALL GETWIN(NODS(I),LUN,INS1,INS2)
           IF(INS1.EQ.0) GOTO 100
           GOTO 2
        ENDIF
        ENDDO
        INS1 = INC1
        INS2 = INC2
      ENDIF

C  READ PUSH DOWN STACK DATA INTO 3D ARRAYS
C  ----------------------------------------

2     IRET = IRET+1
      IF(IRET.LE.I2) THEN
         DO I=1,NNOD
            NNVN = NEVN(NODS(I),LUN,INS1,INS2,I1,I2,I3,USR(I,IRET,1))
            JRET = MAX(JRET,NNVN)
         ENDDO
      ENDIF

C  DECIDE WHAT TO DO NEXT
C  ----------------------

      CALL NXTWIN(LUN,INS1,INS2)
      IF(INS1.GT.0 .AND. INS1.LT.INC2) GOTO 2
      IF(NCON.GT.0) GOTO 1

      IF(IRET.EQ.0 .OR. JRET.EQ.0)  THEN
         IF(IPRT.GE.1)  THEN
      CALL ERRWRT('+++++++++++++++++++++WARNING+++++++++++++++++++++++')
      ERRSTR = 'BUFRLIB: UFBIN3 - NO SPECIFIED VALUES READ IN, ' //
     .   'SO RETURN WITH 6th AND/OR 7th ARGS. (IRET, JRET) = 0; ' //
     .   '8th ARG. (STR) ='
      CALL ERRWRT(ERRSTR)
      CALL ERRWRT(STR)
      CALL ERRWRT('+++++++++++++++++++++WARNING+++++++++++++++++++++++')
      CALL ERRWRT(' ')
         ENDIF
      ENDIF

C  EXITS
C  -----

100   RETURN
900   CALL BORT('BUFRLIB: UFBIN3 - INPUT BUFR FILE IS CLOSED, IT MUST'//
     . ' BE OPEN FOR INPUT')
901   CALL BORT('BUFRLIB: UFBIN3 - INPUT BUFR FILE IS OPEN FOR OUTPUT'//
     . ', IT MUST BE OPEN FOR INPUT')
902   CALL BORT('BUFRLIB: UFBIN3 - A MESSAGE MUST BE OPEN IN INPUT '//
     . 'BUFR FILE, NONE ARE')
903   CALL BORT('BUFRLIB: UFBIN3 - LOCATION OF INTERNAL TABLE FOR '//
     . 'INPUT BUFR FILE DOES NOT AGREE WITH EXPECTED LOCATION IN '//
     . 'INTERNAL SUBSET ARRAY')
      END
