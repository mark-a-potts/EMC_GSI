      SUBROUTINE ERRWRT(STR)

C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM:    ERRWRT
C   PRGMMR: J. ATOR          ORG: NP12       DATE: 2009-04-21
C
C ABSTRACT: THIS SUBROUTINE WRITES A GIVEN ERROR OR OTHER DIAGNOSTIC
C   MESSAGE TO A USER-SPECIFIED LOGICAL UNIT.  AS DISTRIBUTED WITHIN
C   THE BUFR ARCHIVE LIBRARY, THIS SUBROUTINE WILL WRITE ANY SUCH
C   MESSAGES TO STANDARD OUTPUT; HOWEVER, APPLICATION PROGRAMS MAY
C   SUBSTITUTE AN IN-LINE VERSION OF ERRWRT (OVERRIDING THIS ONE) IN
C   ORDER TO DEFINE AN ALTERNATE DESTINATION FOR SUCH MESSAGES.
C
C PROGRAM HISTORY LOG:
C 2009-04-21  J. ATOR    -- ORIGINAL AUTHOR
C
C USAGE:    CALL ERRWRT (STR)
C   INPUT ARGUMENT LIST:
C     STR      - CHARACTER*(*): ERROR MESSAGE TO BE PRINTED TO
C                STANDARD OUTPUT (DEFAULT) OR TO ANOTHER DESTINATION
C                (IF SPECIFIED BY THE USER APPLICATION VIA AN IN-LINE
C                REPLACEMENT FOR THIS SUBROUTINE)
C
C   OUTPUT FILES:
C     UNIT 06  - STANDARD OUTPUT PRINT
C
C REMARKS:
C    THIS ROUTINE CALLS:        None
C    THIS ROUTINE IS CALLED BY: ADDATE   BORT     BORT2    CKTABA
C                               CPDXMM   DATEBF   DUMPBF   INVCON
C                               INVTAG   INVWIN   IUPBS1   IUPVS1
C                               JSTNUM   LJUST    LSTRPC   LSTRPS
C                               MAKESTAB MAXOUT   MRGINV   MSGUPD
C                               MSGWRT   NVNWIN   OPENBF   OPENBT
C                               PARSEQ   PKTDD    POSAPN   RDBFDX
C                               RDMEMM   RDMEMS   READDX   READERME
C                               READLC   READMG   READMT   READS3
C                               STRNUM   STRSUC   SUBUPD   UFBEVN
C                               UFBIN3   UFBINT   UFBMEM   UFBOVR
C                               UFBREP   UFBRMS   UFBRW    UFBSEQ
C                               UFBSTP   UFBTAB   UFBTAM   USRTPL
C                               VALX     WRDLEN
C                               Can also be called by application
C                               programs using an in-line version.
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 77
C   MACHINE:  PORTABLE TO ALL PLATFORMS
C
C$$$

      CHARACTER*(*) STR

      PRINT*,STR

      RETURN
      END
