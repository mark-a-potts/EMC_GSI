C-----------------------------------------------------------------------
      SUBROUTINE IPMERGE2(NO,NF,M1,L1,F1,M2,L2,F2,MO,LO,FO)
C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM:  IPMERGE2   MERGE TWO BITMAPPED FIELDS INTO ONE
C   PRGMMR: IREDELL       ORG: W/NMC23       DATE: 1998-04-08
C
C ABSTRACT: THIS SUBPROGRAM MERGES TWO BITMAPPED FIELDS INTO ONE.
C           WHERE BOTH INPUT FIELDS ARE VALID, THE FIRST FIELD IS TAKEN.
C           WHERE NEITHER INPUT FIELD IS VALID, THE OUTPUT IS INVALID.
C
C PROGRAM HISTORY LOG:
C 1999-04-08  IREDELL
C
C USAGE:    CALL IPMERGE2(NO,NF,M1,L1,F1,M2,L2,F2,MO,LO,FO)
C
C   INPUT ARGUMENT LIST:
C     NO       - INTEGER NUMBER OF POINTS IN EACH FIELD
C     NF       - INTEGER NUMBER OF FIELDS MERGES
C     M1       - INTEGER FIRST DIMENSION OF FIELD 1 ARRAYS
C     L1       - LOGICAL(1) (M1,NF) BITMAP FOR FIELD 1
C     F1       - REAL (M1,NF) DATA FOR FIELD 1
C     M2       - INTEGER FIRST DIMENSION OF FIELD 2 ARRAYS
C     L2       - LOGICAL(1) (M2,NF) BITMAP FOR FIELD 2
C     F2       - REAL (M2,NF) DATA FOR FIELD 2
C     MO       - INTEGER FIRST DIMENSION OF OUTPUT FIELD ARRAYS
C
C   OUTPUT ARGUMENT LIST:
C     LO       - LOGICAL(1) (MO,NF) BITMAP FOR OUTPUT FIELD
C     FO       - REAL (MO,NF) DATA FOR OUTPUT FIELD
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 90
C
C$$$
      INTEGER NO,NF,M1,M2,MO
      LOGICAL(1) L1(M1,NF),L2(M2,NF)
      REAL F1(M1,NF),F2(M2,NF)
      LOGICAL(1) LO(MO,NF)
      REAL FO(MO,NF)
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  MERGE FIELDS, TAKING FIRST FIELD FIRST
      DO N=1,NF
        DO K=1,NO
          LO(K,N)=L1(K,N).OR.L2(K,N)
          IF(L1(K,N)) THEN
            FO(K,N)=F1(K,N)
          ELSEIF(L2(K,N)) THEN
            FO(K,N)=F2(K,N)
          ELSE
            FO(K,N)=0
          ENDIF
        ENDDO
      ENDDO
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      END
