       SUBROUTINE BPDRLN(IJIJ,IBLANQ,KPUTPEL1,LFLIP_J,
     A                  IEXIT,ITPLAN,IMAXWRDS,JMAXROWS)
C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:    BPDRLN      PLACE AN ABSOLUTE VECTOR INTO A BIT_PLANE
C   PRGMMR: KRISHNA KUMAR         ORG: W/NP12    DATE: 1999-07-01
C
C ABSTRACT: TO PLACE AN ABSOLUTE VECTOR INTO A BLACK-AND-WHITE
C   RASTER IMAGE BIT_PLANE.  TO "DRAW" THE STRAIGHT LINE CONNECTING 
C   THE TWO END POINTS OF THE VECTOR, IT COMPUTES WHERE EACH
C   PIXEL SHOULD BE POSITIONED, THEN CALLS ON SUBR WRBORZ() TO PUT 
C   EACH PIXEL INTO THE BITPLANE.
C
C PROGRAM HISTORY LOG:
C   81-10-23  D.SHIMOMURA   -- WROTE ORIGINAL
C   95-03-14  D.SHIMOMURA   -- CONVERT VAX VERSION TO THE CRAY
C   95-07-05  L.LIN         -- ADD DOUBLE WEIGHT CAPABILITY
C 1999-07-01  KRISHNA KUMAR -- CONVERTED CRAY VERSION TO IBM RS/6000
C
C USAGE:    CALL BPDRLN(IJIJ,ITPLAN,IMAXWRDS,JMAXROWS,IBLANQ,KPUTPEL1,
C                       LFLIP_J,IEXIT)
C   INPUT ARGUMENT LIST:
C
C     (1) IJIJ ... INTEGER    IJIJ(4)
C                  WHICH CONTAINS COORDINATES OF STARTING POINT
C                  AND ENDING POINT (IN PIXELS) OF THE VECTOR;
C                      IXA,IYA, IXB,IYB
C
C     (9),(10),(11)  INTEGER    ITPLAN(IMAXWRDS,JMAXROWS)
C                - THE BIT_PLANE FOR DRAWING THE VECTOR INTO;
C                  WHERE IMAXWRDS IS THE LENGTH OF SCANLINE (IN WORDS);
C                        JMAXROWS IS THE TOTAL NUMBER OF SCANLINES.
C
C     (2) IBLANQ - INTEGER SWITCH FOR SETTING BIT ON OR OFF
C                = 0;    TO PUT A ONE BIT INTO BIT PLANE. 
C                = NON-ZERO; TO CLEAR A BIT FROM BIT PLANE.
C
C     (3) KPUTPEL1 - INTEGER SWITCH FOR EITHER PUTTING, OR SKIPPING,
C                    THE VERY FIRST PIXEL OF THE VECTOR; 
C                = 0;  SKIP THE DOT AT THE STARTING POINT
C                = 1;  PUT  THE DOT AT THE STARTING POINT.
C     (4) LFLIP_J - LOGICAL SWITCH TO FLIP THE J-COORDINATE
C                = .TRUE.  TO FLIP THE MAP SO THAT THE BOTTOM SCANLINE
C                          BECOMES THE TOP SCANLINE, AND VICE VERSA;
C                = .FALSE. TO LEAVE THE J-COORDINATE AS IS.
C     (5) LDOUBLE - LOGICAL SWITCH FOR WEIGHT
C                   =TRUE, DOUBLE WEIGHT
C     (6) DASHFG  - LOGICAL SWITHCH  FOR DASHING THE SEGMENT
C     (7) DASHMK  - (1) DASH MASK FOR THE SOLID PORTION OF THE SEGMENT
C                   (2) DASH MASK FOR THE SOLID PORTION PLUS BLANK PORTION
C
C   OUTPUT ARGUMENT LIST:
C     (8) IEXIT - REURN CODE
C               =0;  NORMAL RETURN
C               =1;  ERROR -- VALUE OF IMAXWRDS IS OUT-OF-BOUNDS
C               =2;  ERROR -- VALUE OF JMAXROWS IS OUT-OF-BOUNDS
C
C REMARKS: 
C
C     LIMITING NO. OF PIXELS PER SCANLINE IS SET AT 4224 WHICH IS
C     MODULO 64-BITS WHICH WILL INCLUDE BEDIENT'S LIMIT OF 4192 PIXELS.
C     MAYBE THE 4192 LIMIT COULD BE APPLIED IN THE RLE ENCODING OF
C     THE RASTERS.  PUTLAB() USES MAXI=4100.
C
C     WHAT WAS BEDIENT'S MAX NO. OF SCANLINES???
C        I THINK BEDIENT PUTS THE FIRST STRIP TITLE AT J=8200 ????
C        PUTLAB() USES MAXJ=8190
C
C     CAUTION:  THE DIMENSIONS OF THE BIT_PLANE MUST BE WITHIN
C        THE BOUNDS: (LMTIWRD,LMTNROW)
C                    ((4224/64),8199)    
C                    WHERE THESE LIMITS ARE DEFINED HEREIN BY 
C                          PARAMETER STATEMENTS;
C                    IF OUT-OF-RANGE, THEN THIS DOES NOTHING.
C
C     THE LFLIP_J OPTION WAS FOR THE SITUATION:
C      ... THE GIVEN Y-COORDINATES ARE REVERSED WITHIN THIS SUBR
C      ... TO FIT THE NEDS BIT PLANE CONVENTION WHICH HAS
C      ... ROW1 AT TOP AND ROW1536 AT BOTTOM.
C
C      USING DIGITAL DIFFERENTIAL ANALYZER LOGIC OF 
C      ...   W.M. NEWMAN AND R.F. SPROULL (1973),
C      ...   "PRINCIPLES OF INTERACTIVE COMPUTER GRAPHICS".
C
C ATTRIBUTES:
C   LANGUAGE: F90
C   MACHINE:  IBM
C
C$$$
C
C      *     *     *     *     *     *     *     *     *     *
C
C
C
      COMMON /DASH/LDOUBLE,DASHFG,DASHMK(2),IDASH,SHADNO,SHADMK(20)
      LOGICAL      LDOUBLE
      LOGICAL      DASHFG
      INTEGER      DASHMK
      INTEGER      IDASH
      LOGICAL      SHADFG
      INTEGER      SHADMK
C
       INTEGER    NBITSPWD
       PARAMETER (NBITSPWD=64)
       INTEGER    LMTNROW
       PARAMETER (LMTNROW=8199)
       INTEGER    LMTIPEL
       PARAMETER (LMTIPEL=4224)
       INTEGER    LMTIWRD
       PARAMETER (LMTIWRD=LMTIPEL/NBITSPWD)
C
C      ... CALL SEQUENCE FOR THIS SUBR BPDRLN():
       INTEGER    IJIJ(4)
       INTEGER    ITPLAN(IMAXWRDS,JMAXROWS)
       INTEGER    IBLANQ
       INTEGER    KPUTPEL1
       LOGICAL    LFLIP_J
       INTEGER    IEXIT
C
C      ... CALL SEQUENCE FOR THE CALLED SUBR WRBORZ():
       INTEGER    IXA,IYA
       INTEGER    IXAA, IYAA
C
C
C      . . .   S T A R T   . . . 
C      print *,' draw a line '
C
C
       IEXIT = 0
       IF((IMAXWRDS .LE. 0) .OR. (IMAXWRDS .GT. LMTIWRD))THEN
         IEXIT = 1
         GO TO 777
       ENDIF
       IF((JMAXROWS .LE. 0) .OR. (JMAXROWS .GT. LMTNROW))THEN
         IEXIT = 2
         GO TO 777
       ENDIF
       
C
       IXA = IJIJ(1)
       IYA = IJIJ(2)
       IXB = IJIJ(3)
       IYB = IJIJ(4)

       IF(LFLIP_J) THEN
         MAXJR = JMAXROWS
         MAXJR = MAXJR + 1
C        ... WHERE MAXJR IS USED TO TURN Y-COORDINATE UPSIDE DOWN
         IYA = MAXJR - IYA
         IYB = MAXJR - IYB
       ENDIF

       IDELX = IXB - IXA
       IDELY = IYB - IYA
       IABDX = IABS(IDELX)
       IABDY = IABS(IDELY)     
       REM = 0.5
C
C      ... TEST FOR THE CASE WHERE THE ENDING POINT OF THIS STRAIGHT
C      ... LINE COINCIDES WITH THE STARTING POINT. VERY SHORT LINE.
       IF(IDELX .NE. 0) GO TO 211
       IF(IDELY .NE. 0) GO TO 211
C      ... OTHERWISE, BOTH DELTAS WERE ZERO, SO JUMP OUT
       GO TO 777
C
  211  CONTINUE
C      ... COMES HERE IF AT LEAST ONE OF THE DELTAS IS NON-ZERO
       IXCHAN = 1
       IF(IDELX .LE. 0) IXCHAN = -1
       IYCHAN = 1
       IF(IDELY .LE. 0) IYCHAN = -1
       IF(IABDX .LT. IABDY) GO TO 400

C      ... OTHERWISE, X .GE. Y ...
       SLOPE = FLOAT(IABDY) / FLOAT(IABDX)
       M2 = IABDX
       IF(KPUTPEL1 .NE. 0) THEN
C        ... TO DRAW A DOT AT THE STARTING POINT,
         CALL WRBORZ(IBLANQ,IXA,IYA,ITPLAN,IMAXWRDS,JMAXROWS)
         IF (LDOUBLE) THEN
            IXAA = IXA - IXCHAN
            IYAA = IYA + IYCHAN
            CALL WRBORZ(IBLANQ,IXA,IYAA,ITPLAN,IMAXWRDS,JMAXROWS)
            CALL WRBORZ(IBLANQ,IXAA,IYA,ITPLAN,IMAXWRDS,JMAXROWS)
         ENDIF
       ELSE IF (DASHFG) THEN
         IF (IDASH .LE. DASHMK(2)) THEN
           CALL WRBORZ(IBLANQ,IXA,IYA,ITPLAN,IMAXWRDS,JMAXROWS)
           IF (LDOUBLE) THEN
             IXAA = IXA - IXCHAN
             IYAA = IYA + IYCHAN
             CALL WRBORZ(IBLANQ,IXA,IYAA,ITPLAN,IMAXWRDS,JMAXROWS)
             CALL WRBORZ(IBLANQ,IXAA,IYA,ITPLAN,IMAXWRDS,JMAXROWS)
           ENDIF
         ELSE
           IF (LDOUBLE) THEN
             IXAA = IXA - IXCHAN
             IYAA = IYA + IYCHAN
           ENDIF
         ENDIF
         IDASH = IDASH + 1
         IF (IDASH .GT. DASHMK(1)) IDASH=IDASH-DASHMK(1)
       ENDIF
C      ... INITIALIZE ALTERNATING SWITCH = 0 (PUT A DOT)
       DO  ISTEP = 1,M2
         REM = REM + SLOPE
         IXA = IXA + IXCHAN
         IF(REM .GE. 1.0) THEN
C          ... CHANGE Y BY ONE DOT ALSO
           IYA = IYA + IYCHAN
           IF (LDOUBLE) IYAA = IYA + IYCHAN
           REM = REM - 1.0
         ENDIF
C
         IF (DASHFG) THEN
           IF (IDASH .LE. DASHMK(2)) THEN
             CALL WRBORZ(IBLANQ,IXA,IYA,ITPLAN,IMAXWRDS,JMAXROWS)
             IF (LDOUBLE) THEN
              IXAA = IXA - IXCHAN
              CALL WRBORZ(IBLANQ,IXA,IYAA,ITPLAN,IMAXWRDS,JMAXROWS)
              CALL WRBORZ(IBLANQ,IXAA,IYA,ITPLAN,IMAXWRDS,JMAXROWS)
             ENDIF
           ELSE
             IF (LDOUBLE) THEN
              IXAA = IXA - IXCHAN
             ENDIF
           ENDIF
           IDASH = IDASH + 1
           IF (IDASH .GT. DASHMK(1)) IDASH=IDASH-DASHMK(1)
         ELSE
           CALL WRBORZ(IBLANQ,IXA,IYA,ITPLAN,IMAXWRDS,JMAXROWS)
           IF (LDOUBLE) THEN
             IXAA = IXA - IXCHAN
             CALL WRBORZ(IBLANQ,IXA,IYAA,ITPLAN,IMAXWRDS,JMAXROWS)
             CALL WRBORZ(IBLANQ,IXAA,IYA,ITPLAN,IMAXWRDS,JMAXROWS)
           ENDIF
         ENDIF
C
C        ... ALTERNATING SWITCH ON/OFF
       ENDDO
C
       GO TO 777
C
  400  CONTINUE
C      ... COMES HERE IF Y .GT. X  ...
       SLOPE = FLOAT(IABDX) / FLOAT(IABDY)
       M2 = IABDY
       IF(KPUTPEL1 .NE. 0) THEN
C        ... TO DRAW A DOT AT THE STARTING POINT,
         CALL WRBORZ(IBLANQ,IXA,IYA,ITPLAN,IMAXWRDS,JMAXROWS)
C
         IF (LDOUBLE) THEN
            IYAA = IYA - IYCHAN
            IXAA = IXA + IXCHAN
            CALL WRBORZ(IBLANQ,IXA,IYAA,ITPLAN,IMAXWRDS,JMAXROWS)
            CALL WRBORZ(IBLANQ,IXAA,IYA,ITPLAN,IMAXWRDS,JMAXROWS)
         ENDIF
       ELSE IF (DASHFG) THEN
         IF (IDASH .LE. DASHMK(2)) THEN
           CALL WRBORZ(IBLANQ,IXA,IYA,ITPLAN,IMAXWRDS,JMAXROWS)
C
           IF (LDOUBLE) THEN
            IYAA = IYA - IYCHAN
            IXAA = IXA + IXCHAN
            CALL WRBORZ(IBLANQ,IXA,IYAA,ITPLAN,IMAXWRDS,JMAXROWS)
            CALL WRBORZ(IBLANQ,IXAA,IYA,ITPLAN,IMAXWRDS,JMAXROWS)
           ENDIF
         ELSE
           IF (LDOUBLE) THEN
            IYAA = IYA - IYCHAN
            IXAA = IXA + IXCHAN
           ENDIF
         ENDIF
         IDASH = IDASH + 1
         IF (IDASH .GT. DASHMK(1)) IDASH=IDASH-DASHMK(1)
       ENDIF
C
       DO  ISTEP = 1,M2
         REM = REM + SLOPE
         IYA = IYA + IYCHAN
         IF(REM .GE. 1.0) THEN
C        ... CHANGE X BY ONE DOT ALSO ...
           IXA = IXA + IXCHAN
           IF (LDOUBLE) IXAA = IXAA + IXCHAN
           REM = REM - 1.0
         ENDIF
C
         IF (DASHFG) THEN
           IF (IDASH .LE. DASHMK(2)) THEN
             CALL WRBORZ(IBLANQ,IXA,IYA,ITPLAN,IMAXWRDS,JMAXROWS)
             IF (LDOUBLE) THEN
              IYAA = IYA - IYCHAN
              CALL WRBORZ(IBLANQ,IXA,IYAA,ITPLAN,IMAXWRDS,JMAXROWS)
              CALL WRBORZ(IBLANQ,IXAA,IYA,ITPLAN,IMAXWRDS,JMAXROWS)
             ENDIF
           ELSE
             IF (LDOUBLE) THEN
              IYAA = IYA - IYCHAN
             ENDIF
           ENDIF
           IDASH = IDASH + 1
           IF (IDASH .GT. DASHMK(1)) IDASH=IDASH-DASHMK(1)
         ELSE
           CALL WRBORZ(IBLANQ,IXA,IYA,ITPLAN,IMAXWRDS,JMAXROWS)
           IF (LDOUBLE) THEN
             IYAA = IYA - IYCHAN
             CALL WRBORZ(IBLANQ,IXA,IYAA,ITPLAN,IMAXWRDS,JMAXROWS)
             CALL WRBORZ(IBLANQ,IXAA,IYA,ITPLAN,IMAXWRDS,JMAXROWS)
           ENDIF
         ENDIF
C
       ENDDO
C
  777  CONTINUE
       RETURN
       END
