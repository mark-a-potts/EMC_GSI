      SUBROUTINE UFBRP(LUN,USR,I1,I2,IO,IRET)

C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM:    UFBRP
C   PRGMMR: WOOLLEN          ORG: NP20       DATE: 1994-01-06
C
C ABSTRACT: THIS SUBROUTINE WRITES OR READS SPECIFIED VALUES TO OR
C   FROM THE CURRENT BUFR DATA SUBSET WITHIN INTERNAL ARRAYS, WITH THE
C   DIRECTION OF THE DATA TRANSFER DETERMINED BY THE CONTEXT OF IO
C   (I.E., IF IO INDICATES LUN POINTS TO A BUFR FILE THAT IS OPEN FOR
C   INPUT, THEN DATA VALUES ARE READ FROM THE INTERNAL DATA SUBSET;
C   OTHERWISE, DATA VALUES ARE WRITTEN TO THE INTERNAL DATA SUBSET.
C   THE DATA VALUES CORRESPOND TO INTERNAL ARRAYS REPRESENTING PARSED
C   STRINGS OF MNEMONICS WHICH ARE PART OF A REGULAR (I.E., NON-
C   DELAYED) REPLICATION SEQUENCE OR FOR THOSE WHICH ARE REPLICATED
C   VIA BEING DIRECTLY LISTED MORE THAN ONCE WITHIN AN OVERALL SUBSET
C   DEFINITION RATHER THAN BY BEING INCLUDED WITHIN A REPLICATION
C   SEQUENCE.  THIS ROUTINE IS ONLY CALLED BY BUFR ARCHIVE LIBRARY
C   SUBROUTINE UFBREP AND SHOULD NEVER BE CALLED BY ANY APPLICATION
C   PROGRAM (APPLICATION PROGRAMS SHOULD ALWAYS CALL UFBREP TO PERFORM
C   THESE FUNCTIONS).
C
C PROGRAM HISTORY LOG:
C 1994-01-06  J. WOOLLEN -- ORIGINAL AUTHOR
C 1998-07-08  J. WOOLLEN -- IMPROVED MACHINE PORTABILITY
C 1999-11-18  J. WOOLLEN -- THE NUMBER OF BUFR FILES WHICH CAN BE
C                           OPENED AT ONE TIME INCREASED FROM 10 TO 32
C                           (NECESSARY IN ORDER TO PROCESS MULTIPLE
C                           BUFR FILES UNDER THE MPI)
C 2003-11-04  S. BENDER  -- ADDED REMARKS/BUFRLIB ROUTINE
C                           INTERDEPENDENCIES
C 2003-11-04  D. KEYSER  -- MAXJL (MAXIMUM NUMBER OF JUMP/LINK ENTRIES)
C                           INCREASED FROM 15000 TO 16000 (WAS IN
C                           VERIFICATION VERSION); UNIFIED/PORTABLE FOR
C                           WRF; ADDED DOCUMENTATION (INCLUDING
C                           HISTORY)
C
C USAGE:    CALL UFBRP (LUN, USR, I1, I2, IO, IRET)
C   INPUT ARGUMENT LIST:
C     LUN      - INTEGER: I/O STREAM INDEX INTO INTERNAL MEMORY ARRAYS
C     USR      - ONLY IF BUFR FILE OPEN FOR OUTPUT:
C                   REAL*8: (I1,I2) STARTING ADDRESS OF DATA VALUES
C                   WRITTEN TO DATA SUBSET
C     I1       - INTEGER: LENGTH OF FIRST DIMENSION OF USR
C     I2       - INTEGER: LENGTH OF SECOND DIMENSION OF USR
C     IO       - INTEGER: STATUS INDICATOR FOR BUFR FILE ASSOCIATED
C                WITH LUN:
C                       0 = input file
C                       1 = output file
C
C   OUTPUT ARGUMENT LIST:
C     USR      - ONLY IF BUFR FILE OPEN FOR INPUT:
C                   REAL*8: (I1,I2) STARTING ADDRESS OF DATA VALUES
C                   READ FROM DATA SUBSET
C     IRET     - INTEGER:
C                  - IF BUFR FILE OPEN FOR INPUT: NUMBER OF "LEVELS" OF
C                    DATA VALUES READ FROM DATA SUBSET (MUST BE NO
C                    LARGER THAN I2)
C                  - IF BUFR FILE OPEN FOR OUTPUT: NUMBER OF "LEVELS"
C                    OF DATA VALUES WRITTEN TO DATA SUBSET (SHOULD BE
C                    SAME AS I2)
C
C REMARKS:
C    THIS ROUTINE CALLS:        INVTAG
C    THIS ROUTINE IS CALLED BY: UFBREP
C                               Normally not called by any application
C                               programs (they should call UFBREP).
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 77
C   MACHINE:  PORTABLE TO ALL PLATFORMS
C
C$$$

      INCLUDE 'bufrlib.prm'

      COMMON /USRINT/ NVAL(NFILES),INV(MAXSS,NFILES),VAL(MAXSS,NFILES)
      COMMON /USRSTR/ NNOD,NCON,NODS(20),NODC(10),IVLS(10),KONS(10)

      REAL*8 USR(I1,I2),VAL

C----------------------------------------------------------------------
C----------------------------------------------------------------------

      IRET = 0
      INS1 = 0
      INS2 = 0

C  FIND FIRST NON-ZERO NODE IN STRING
C  ----------------------------------

      DO NZ=1,NNOD
      IF(NODS(NZ).GT.0) GOTO 1
      ENDDO
      GOTO 100

C  FRAME A SECTION OF THE BUFFER - RETURN WHEN NO FRAME
C  ----------------------------------------------------

1     IF(INS1+1.GT.NVAL(LUN)) GOTO 100
      IF(IO.EQ.1 .AND. IRET.EQ.I2) GOTO 100
      INS1 = INVTAG(NODS(NZ),LUN,INS1+1,NVAL(LUN))
      IF(INS1.EQ.0) GOTO 100

      INS2 = INVTAG(NODS(NZ),LUN,INS1+1,NVAL(LUN))
      IF(INS2.EQ.0) INS2 = NVAL(LUN)
      IRET = IRET+1

C  READ USER VALUES
C  ----------------

      IF(IO.EQ.0 .AND. IRET.LE.I2) THEN
         DO I=1,NNOD
         IF(NODS(I).GT.0) THEN
            INVN = INVTAG(NODS(I),LUN,INS1,INS2)
            IF(INVN.GT.0) USR(I,IRET) = VAL(INVN,LUN)
         ENDIF
         ENDDO
      ENDIF

C  WRITE USER VALUES
C  -----------------

      IF(IO.EQ.1 .AND. IRET.LE.I2) THEN
         DO I=1,NNOD
         IF(NODS(I).GT.0) THEN
            INVN = INVTAG(NODS(I),LUN,INS1,INS2)
            IF(INVN.GT.0) VAL(INVN,LUN) = USR(I,IRET)
         ENDIF
         ENDDO
      ENDIF

C  GO FOR NEXT FRAME
C  -----------------

      GOTO 1

C  EXIT
C  ----

100   RETURN
      END
