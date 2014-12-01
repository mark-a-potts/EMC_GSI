      SUBROUTINE UPB(NVAL,NBITS,IBAY,IBIT)

C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM:    UPB
C   PRGMMR: WOOLLEN          ORG: NP20       DATE: 1994-01-06
C
C ABSTRACT: THIS SUBROUTINE UNPACKS AND RETURNS A BINARY INTEGER
C   CONTAINED WITHIN NBITS BITS OF IBAY, STARTING WITH BIT (IBIT+1).
C   ON OUTPUT, IBIT IS UPDATED TO POINT TO THE LAST BIT THAT WAS
C   UNPACKED.  THIS IS SIMILAR TO BUFR ARCHIVE LIBRARY SUBROUTINE UPBB,
C   EXCEPT IN UPBB IBIT IS NOT UPDATED UPON OUTPUT (AND THE ORDER OF
C   ARGUMENTS IS DIFFERENT).
C
C PROGRAM HISTORY LOG:
C 1994-01-06  J. WOOLLEN -- ORIGINAL AUTHOR
C 2003-05-19  J. ATOR    -- ADDED CHECK FOR NBITS EQUAL TO ZERO
C 2003-11-04  J. ATOR    -- ADDED DOCUMENTATION
C 2003-11-04  J. WOOLLEN -- BIG-ENDIAN/LITTLE-ENDIAN INDEPENDENT (WAS
C                           IN DECODER VERSION)
C 2003-11-04  S. BENDER  -- ADDED REMARKS/BUFRLIB ROUTINE
C                           INTERDEPENDENCIES
C 2003-11-04  D. KEYSER  -- UNIFIED/PORTABLE FOR WRF; ADDED HISTORY
C                           DOCUMENTATION
C 2009-03-23  J. ATOR    -- REWROTE TO CALL UPBB
C
C USAGE:    CALL UPB (NVAL, NBITS, IBAY, IBIT)
C   INPUT ARGUMENT LIST:
C     NBITS    - INTEGER: NUMBER OF BITS OF IBAY WITHIN WHICH TO UNPACK
C                NVAL
C     IBAY     - INTEGER: *-WORD PACKED BINARY ARRAY CONTAINING PACKED
C                NVAL
C     IBIT     - INTEGER: BIT POINTER WITHIN IBAY INDICATING BIT AFTER
C                WHICH TO START UNPACKING
C
C   OUTPUT ARGUMENT LIST:
C     NVAL     - INTEGER: UNPACKED INTEGER
C     IBIT     - INTEGER: BIT POINTER WITHIN IBAY INDICATING LAST BIT
C                THAT WAS UNPACKED
C
C REMARKS:
C    THIS SUBROUTINE IS THE INVERSE OF BUFR ARCHIVE LIBRARY ROUTINE
C    PKB.
C
C    THIS ROUTINE CALLS:        UPBB
C    THIS ROUTINE IS CALLED BY: COPYSB   IUPB     MVB      RDCMPS
C                               RDMGSB   READSB   STNDRD   UFBINX
C                               UFBPOS   UFBTAB   UFBTAM   UPC
C                               WRCMPS   WRITLC
C                               Normally not called by any application
C                               programs.
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 77
C   MACHINE:  PORTABLE TO ALL PLATFORMS
C
C$$$

      DIMENSION IBAY(*)

C----------------------------------------------------------------------
C----------------------------------------------------------------------

      CALL UPBB(NVAL,NBITS,IBIT,IBAY)

      IBIT = IBIT+NBITS

      RETURN
      END
