      FUNCTION LSTRPS(NODE,LUN)

C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM:    LSTRPS
C   PRGMMR: WOOLLEN          ORG: NP20       DATE: 1994-01-06
C
C ABSTRACT: THIS FUNCTION SEARCHES BACKWARDS, BEGINNING FROM A GIVEN
C   NODE WITHIN THE JUMP/LINK TABLE, UNTIL IT FINDS THE MOST RECENT
C   NODE OF TYPE "RPS".  THE INTERNAL JMPB ARRAY IS USED TO JUMP
C   BACKWARDS WITHIN THE JUMP/LINK TABLE, AND THE FUNCTION RETURNS
C   THE TABLE INDEX OF THE FOUND NODE.  IF THE INPUT NODE ITSELF IS
C   OF TYPE "RPS", THEN THE FUNCTION SIMPLY RETURNS THE INDEX OF THAT
C   SAME NODE.  FUNCTION LSTRPS IS CONSIDERED OBSOLETE AND MAY BE
C   REMOVED FROM THE BUFRLIB AT A FUTURE DATE, SINCE FUNCTION LSTJPB
C   ACCOMPLISHES THE SAME THING BUT IN A MORE FLEXIBLE MANNER.
C   FOR NOW, FUNCTION LSTRPS SIMPLY CALLS FUNCTION LSTJPB.
C
C PROGRAM HISTORY LOG:
C 1994-01-06  J. WOOLLEN -- ORIGINAL AUTHOR
C 1998-07-08  J. WOOLLEN -- REPLACED CALL TO CRAY LIBRARY ROUTINE
C                           "ABORT" WITH CALL TO NEW INTERNAL BUFRLIB
C                           ROUTINE "BORT"
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
C                           HISTORY); OUTPUTS MORE COMPLETE DIAGNOSTIC
C                           INFO WHEN ROUTINE TERMINATES ABNORMALLY
C 2009-05-07  J. ATOR    -- MARKED AS OBSOLETE AND ADDED PRINT
C                           NOTIFICATION
C
C USAGE:    LSTRPS (NODE, LUN)
C   INPUT ARGUMENT LIST:
C     NODE     - INTEGER: JUMP/LINK TABLE INDEX OF ENTRY TO BEGIN
C                SEARCHING BACKWARDS FROM
C     LUN      - INTEGER: I/O STREAM INDEX INTO INTERNAL MEMORY ARRAYS
C
C   OUTPUT ARGUMENT LIST:
C     LSTRPS   - INTEGER: INDEX OF FIRST NODE OF TYPE "RPS" FOUND BY
C                JUMPING BACKWARDS FROM INPUT NODE 
C                  0 = NO SUCH NODE FOUND
C
C REMARKS:
C
C    SEE THE DOCBLOCK IN BUFR ARCHIVE LIBRARY SUBROUTINE TABSUB FOR AN
C    EXPLANATION OF THE VARIOUS NODE TYPES PRESENT WITHIN AN INTERNAL
C    JUMP/LINK TABLE 
C
C    THIS ROUTINE CALLS:        ERRWRT   LSTJPB
C    THIS ROUTINE IS CALLED BY: None
C                               Normally not called by any application
C                               programs.
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 77
C   MACHINE:  PORTABLE TO ALL PLATFORMS
C
C$$$

      COMMON /QUIET / IPRT

      CHARACTER*128 ERRSTR

      DATA IFIRST/0/

      SAVE IFIRST

C-----------------------------------------------------------------------
C-----------------------------------------------------------------------

      IF(IFIRST.EQ.0) THEN
         IF(IPRT.GE.0) THEN
      CALL ERRWRT('++++++++++++++BUFR ARCHIVE LIBRARY+++++++++++++++++')
      ERRSTR = 'BUFRLIB: LSTRPS - THIS FUNCTION IS NOW OBSOLETE;'//
     . ' USE FUNCTION LSTJPB INSTEAD'
      CALL ERRWRT(ERRSTR)
      CALL ERRWRT('++++++++++++++BUFR ARCHIVE LIBRARY+++++++++++++++++')
      CALL ERRWRT(' ')
         ENDIF
         IFIRST = 1
      ENDIF

      LSTRPS = LSTJPB(NODE,LUN,'RPS')

      RETURN
      END
