      SUBROUTINE W3FC07(FFID, FFJD, FGU, FGV, FU, FV)
C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:  W3FC07        GRID U-V TO EARTH U-V IN NORTH HEM.
C   PRGMMR: CHASE            ORG: NMC421      DATE:88-10-26
C
C ABSTRACT: GIVEN THE GRID-ORIENTED WIND COMPONENTS ON A NORTHERN
C   HEMISPHERE POLAR STEREOGRAPHIC GRID POINT, COMPUTE THE EARTH-
C   ORIENTED WIND COMPONENTS AT THAT POINT.  IF THE INPUT WINDS
C   ARE AT THE NORTH POLE, THE OUTPUT COMPONENTS WILL BE MADE
C   CONSISTENT WITH THE WMO STANDARDS FOR REPORTING WINDS AT THE
C   NORTH POLE.  (SEE OFFICE NOTE 241 FOR WMO DEFINITION.)
C
C PROGRAM HISTORY LOG:
C   81-12-30  STACKPOLE, J. D.
C   88-10-13  CHASE, P.   ALLOW INPUT AND OUTPUT TO BE THE SAME
C   91-03-06  R.E.JONES   CHANGE TO CRAY CFT77 FORTRAN
C
C USAGE:    CALL W3FC07 (FFID, FFJD, FGU, FGV, FU, FV)
C
C   INPUT ARGUMENT LIST:
C     FFID     - REAL   I-DISPLACEMENT FROM POINT TO NORTH POLE
C     FFJD     - REAL   J-DISPLACEMENT FROM POINT TO NORTH POLE
C     FGU      - REAL   GRID-ORIENTED U-COMPONENT
C     FGV      - REAL   GRID-ORIENTED V-COMPONENT
C
C   OUTPUT ARGUMENT LIST:
C     FU       - REAL   EARTH-ORIENTED U-COMPONENT, POSITIVE FROM WEST
C                MAY REFERENCE THE SAME LOCATION AS FGU.
C     FV       - REAL   EARTH-ORIENTED V-COMPONENT, POSITIVE FROM SOUTH
C                MAY REFERENCE THE SAME LOCATION AS FGV.
C
C   SUBPROGRAMS CALLED:
C     LIBRARY:
C       COMMON - SQRT
C
C REMARKS:  CALCULATE FFID AND FFJD AS FOLLOWS...
C         FFID = REAL(IP - I)
C         FFJD = REAL(JP - J)
C   WHERE (IP,JP) IS THE GRID COORDINATES OF THE NORTH POLE AND
C   (I,J) IS THE GRID COORDINATES OF THE POINT WHERE FGU AND FGV
C   OCCUR.
C        SEE W3FC11 FOR A SOUTHERN HEMISPHERE COMPANION SUBROUTINE.
C
C ATTRIBUTES:
C   LANGUAGE: CRAY CFT77 FORTRAN
C   MACHINE:  CRAY C916-128, CRAY Y-MP8/864, CRAY Y-MP EL2/256
C
C$$$
C
      SAVE
C
      DATA  COS80 / 0.1736482 /
      DATA  SIN80 / 0.9848078 /

C     COS80 AND SIN80 ARE FOR WIND AT POLE
C     (USED FOR CO-ORDINATE ROTATION TO EARTH ORIENTATION)

      DFP = SQRT(FFID * FFID + FFJD * FFJD)
      IF (DFP .EQ. 0.0) THEN
        XFU = -(FGU * COS80 + FGV * SIN80)
        FV  = -(FGV * COS80 - FGU * SIN80)
      ELSE
        XFU = (FGU * FFJD - FGV * FFID) / DFP
        FV  = (FGU * FFID + FGV * FFJD) / DFP
      ENDIF
      FU = XFU
      RETURN
      END
