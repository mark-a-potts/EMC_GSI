C-----------------------------------------------------------------------
      SUBROUTINE BAFRINDEX(LU,IB,LX,IX)
!
      IMPLICIT NONE
      INTEGER,INTENT(IN):: LU,IB
      INTEGER,INTENT(INOUT):: LX
      INTEGER,INTENT(OUT):: IX
      integer(kind=8) :: LONG_JB,LONG_JX 
!
      call BAFRINDEXL(LU,LONG_JB,LONG_JX,IX)
      LX=LONG_JX
      return
      end SUBROUTINE BAFRINDEX
C-----------------------------------------------------------------------
      SUBROUTINE BAFRINDEXL(LU,IB,LX,IX)
C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM: BAFRINDEX      BYTE-ADDRESSABLE FORTRAN RECORD INDEX
C   PRGMMR: IREDELL          ORG: W/NMC23     DATE: 1999-01-21
C
C ABSTRACT: THIS SUBPROGRAM EITHER READS AN UNFORMATTED FORTRAN RECORD
C   AND RETURN ITS LENGTH AND START BYTE OF THE NEXT FORTRAN RECORD;
C   OR GIVEN THE RECORD LENGTH, WITHOUT I/O IT DETERMINES THE START BYTE
C   OF THE NEXT FORTRAN RECORD.
C
C PROGRAM HISTORY LOG:
C   1999-01-21  IREDELL
C
C USAGE:    CALL BAFRINDEX(LU,IB,LX,IX)
C   INPUT ARGUMENTS:
C     LU           INTEGER LOGICAL UNIT TO READ
C                  IF LU<=0, THEN DETERMINE IX FROM LX
C     IB           INTEGER FORTRAN RECORD START BYTE
C                  (FOR THE FIRST FORTRAN RECORD, IB SHOULD BE 0)
C     LX           INTEGER RECORD LENGTH IN BYTES IF LU<=0
C
C   OUTPUT ARGUMENTS:
C     LX           INTEGER RECORD LENGTH IN BYTES IF LU>0,
C                  OR LX=-1 FOR I/O ERROR (PROBABLE END OF FILE),
C                  OR LX=-2 FOR I/O ERROR (INVALID FORTRAN RECORD)
C     IX           INTEGER START BYTE FOR THE NEXT FORTRAN RECORD
C                  (COMPUTED ONLY IF LX>=0)
C
C SUBPROGRAMS CALLED:
C   BAREAD         BYTE-ADDRESSABLE READ
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 90
C
C$$$
      IMPLICIT NONE
      INTEGER,INTENT(IN):: LU
      INTEGER(KIND=8),INTENT(IN):: IB
      INTEGER(KIND=8),INTENT(INOUT):: LX
      INTEGER(KIND=8),INTENT(OUT):: IX
      INTEGER(KIND=8),PARAMETER:: LBCW=4
      INTEGER(KIND=LBCW):: BCW1,BCW2
      INTEGER(KIND=8):: KR
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  COMPARE FIRST BLOCK CONTROL WORD AND TRAILING BLOCK CONTROL WORD
      IF(LU.GT.0) THEN
        CALL BAREADL(LU,IB,LBCW,KR,BCW1)
        IF(KR.NE.LBCW) THEN
          LX=-1
        ELSE
          CALL BAREADL(LU,IB+LBCW+BCW1,LBCW,KR,BCW2)
          IF(KR.NE.LBCW.OR.BCW1.NE.BCW2) THEN
            LX=-2
          ELSE
            LX=BCW1
          ENDIF
        ENDIF
      ENDIF
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  COMPUTE START BYTE FOR THE NEXT FORTRAN RECORD
      IF(LX.GE.0) IX=IB+LBCW+LX+LBCW
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      END SUBROUTINE BAFRINDEXL
C-----------------------------------------------------------------------
      SUBROUTINE BAFRREAD(LU,IB,NB,KA,A)
!
      IMPLICIT NONE
      INTEGER,INTENT(IN):: LU,IB,NB
      INTEGER,INTENT(OUT):: KA
      CHARACTER,INTENT(OUT):: A(NB)
      INTEGER(KIND=8) :: LONG_IB,LONG_NB,LONG_KA
!
        if(IB<0 .or. NB<0 ) THEN
          print *,'WRONG: in BAFRREAD starting postion IB or read '//    &
     & 'data size NB < 0, STOP! Consider use bafreadl and long integer'
          KA=0
          return
        ENDIF
        LONG_IB=IB
        LONG_NB=NB
        CALL BAFRREADL(LU,LONG_IB,LONG_NB,LONG_KA,A)
        KA=LONG_KA
      END SUBROUTINE BAFRREAD
C-----------------------------------------------------------------------
      SUBROUTINE BAFRREADL(LU,IB,NB,KA,A)
C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM: BAFRREAD       BYTE-ADDRESSABLE FORTRAN RECORD READ
C   PRGMMR: IREDELL          ORG: W/NMC23     DATE: 1999-01-21
C
C ABSTRACT: THIS SUBPROGRAM READS AN UNFORMATTED FORTRAN RECORD
C
C PROGRAM HISTORY LOG:
C   1999-01-21  IREDELL
C
C USAGE:    CALL BAFRREAD(LU,IB,NB,KA,A)
C   INPUT ARGUMENTS:
C     LU           INTEGER LOGICAL UNIT TO READ
C     IB           INTEGER FORTRAN RECORD START BYTE
C                  (FOR THE FIRST FORTRAN RECORD, IB SHOULD BE 0)
C     NB           INTEGER NUMBER OF BYTES TO READ
C
C   OUTPUT ARGUMENTS:
C     KA           INTEGER NUMBER OF BYTES IN FORTRAN RECORD
C                  (IN WHICH CASE THE NEXT FORTRAN RECORD
C                  SHOULD HAVE A START BYTE OF IB+KA),
C                  OR KA=-1 FOR I/O ERROR (PROBABLE END OF FILE),
C                  OR KA=-2 FOR I/O ERROR (INVALID FORTRAN RECORD),
C                  OR KA=-3 FOR I/O ERROR (REQUEST LONGER THAN RECORD)
C     A            CHARACTER*1 (NB) DATA READ
C
C SUBPROGRAMS CALLED:
C   BAFRINDEX      BYTE-ADDRESSABLE FORTRAN RECORD INDEX
C   BAREAD         BYTE-ADDRESSABLE READ
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 90
C
C$$$
      IMPLICIT NONE
      INTEGER,INTENT(IN):: LU
      INTEGER(kind=8),INTENT(IN):: IB,NB
      INTEGER(kind=8),INTENT(OUT):: KA
      CHARACTER,INTENT(OUT):: A(NB)
      INTEGER(kind=8),PARAMETER:: LBCW=4
      INTEGER(kind=8):: LX,IX
      INTEGER(kind=8):: KR
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  VALIDATE FORTRAN RECORD
      CALL BAFRINDEXL(LU,IB,LX,IX)
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  READ IF VALID
      IF(LX.LT.0) THEN
        KA=LX
      ELSEIF(LX.LT.NB) THEN
        KA=-3
      ELSE
        CALL BAREADL(LU,IB+LBCW,NB,KR,A)
        IF(KR.NE.NB) THEN
          KA=-1
        ELSE
          KA=LBCW+LX+LBCW
        ENDIF
      ENDIF
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      END SUBROUTINE BAFRREADL
C-----------------------------------------------------------------------
      SUBROUTINE BAFRWRITE(LU,IB,NB,KA,A)
!
      IMPLICIT NONE
      INTEGER,INTENT(IN):: LU,IB,NB
      INTEGER,INTENT(OUT):: KA
      CHARACTER,INTENT(OUT):: A(NB)
      INTEGER(KIND=8) :: LONG_IB,LONG_NB,LONG_KA
!
        if(IB<0 .or. NB<0 ) THEN
          print *,'WRONG: in BAFRREAD starting postion IB or read '//    &
     &   'data size NB <0, STOP! ' //                                    &
     &   'Consider use bafrrwritel and long integer'
          KA=0
          return
        ENDIF
        LONG_IB=IB
        LONG_NB=NB
        CALL BAFRWRITEL(LU,LONG_IB,LONG_NB,LONG_KA,A)
        KA=LONG_KA
!
      END SUBROUTINE BAFRWRITE
C-----------------------------------------------------------------------
      SUBROUTINE BAFRWRITEL(LU,IB,NB,KA,A)
C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM: BAFRWRITE      BYTE-ADDRESSABLE FORTRAN RECORD WRITE
C   PRGMMR: IREDELL          ORG: W/NMC23     DATE: 1999-01-21
C
C ABSTRACT: THIS SUBPROGRAM WRITES AN UNFORMATTED FORTRAN RECORD
C
C PROGRAM HISTORY LOG:
C   1999-01-21  IREDELL
C
C USAGE:    CALL BAFRWRITE(LU,IB,NB,KA,A)
C   INPUT ARGUMENTS:
C     LU           INTEGER LOGICAL UNIT TO WRITE
C     IB           INTEGER FORTRAN RECORD START BYTE
C                  (FOR THE FIRST FORTRAN RECORD, IB SHOULD BE 0)
C     NB           INTEGER NUMBER OF BYTES TO WRITE
C     A            CHARACTER*1 (NB) DATA TO WRITE
C
C   OUTPUT ARGUMENTS:
C     KA           INTEGER NUMBER OF BYTES IN FORTRAN RECORD
C                  (IN WHICH CASE THE NEXT FORTRAN RECORD
C                  SHOULD HAVE A START BYTE OF IB+KA),
C                  OR KA=-1 FOR I/O ERROR
C
C SUBPROGRAMS CALLED:
C   BAWRITE        BYTE-ADDRESSABLE WRITE
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 90
C
C$$$
      IMPLICIT NONE
      INTEGER,INTENT(IN):: LU
      INTEGER(KIND=8),INTENT(IN):: IB,NB
      INTEGER(kind=8),INTENT(OUT):: KA
      CHARACTER,INTENT(IN):: A(NB)
      INTEGER(kind=8),PARAMETER:: LBCW=4
      INTEGER(kind=LBCW):: BCW
      INTEGER(kind=8):: KR
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  WRITE DATA BRACKETED BY BLOCK CONTROL WORDS
      BCW=NB
      CALL BAWRITEL(LU,IB,LBCW,KR,BCW)
      IF(KR.NE.LBCW) THEN
        KA=-1
      ELSE
        CALL BAWRITEL(LU,IB+LBCW,NB,KR,A)
        IF(KR.NE.NB) THEN
          KA=-1
        ELSE
          CALL BAWRITEL(LU,IB+LBCW+BCW,LBCW,KR,BCW)
          IF(KR.NE.LBCW) THEN
            KA=-1
          ELSE
            KA=LBCW+BCW+LBCW
          ENDIF
        ENDIF
      ENDIF
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      END SUBROUTINE  BAFRWRITEL
