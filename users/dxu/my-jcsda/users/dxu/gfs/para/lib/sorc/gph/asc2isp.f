      SUBROUTINE ASC2ISP(NCHAR,INTEXT,IOUTXT,IERR)
C$$$  SUBPROGRAM DOCUMENTATION  BLOCK
C                .      .    .                                       .
C SUBPROGRAM:    ASC2ISP     CONVERT ASCII  TO EXTENDED DISPLAY CODE.
C   PRGMMR: KRISHNA KUMAR         ORG: NP12      DATE:1999-07-01
C
C ABSTRACT: CONVERTS ASCII TO EXTENDED CD6600 DISPLAY CODE.
C   USED TO CONVERT JFID TO IFID FOR SUBROUTINE CNTR.
C   THERE IS NO LIMIT AS TO THE NUMBER OF CHARACTERS THAT CAN BE
C   CONVERTED IN ONE CALL.
C
C PROGRAM HISTORY LOG:
C   95-06-06  LUKE LIN    ORIGINAL AUTHOR
C 1999-07-01  KRISHNA KUMAR CONVERTED THE CRAY VERSION TO IBM RS/6000.
C
C USAGE:    CALL ASCII(NCHAR,INTEXT,IOUTXT,IERR)
C   INPUT ARGUMENT LIST:
C     NCHAR    - IS THE NUMBER OF CHARACTERS IN STRING TO BE CONVERTED.
C     INTEXT   - IS THE GIVEN ASCII CHATACTER STRING TO CONVERT.
C
C   OUTPUT ARGUMENT LIST:
C     IOUTXT   - IS THE RESULTING TRANSLATED ISP TEXT STRING.
C     IERR     - 0 IS NORMAL RETURN
C     IERR     - 1 THIS IS THE ERROR RETURN FROM SUBROUTINE TRANSA
C              - WHEN IT IS PASSED MORE THAN 256 CHARACTERS.
C
C
C   OUTPUT FILES:
C     FT06F001 - ERROR PRINTS.
C
C REMARKS: 
C
C ATTRIBUTES:
C   LANGUAGE: F90 
C   MACHINE:  IBM
C
C$$$
C    
C
      CHARACTER*1  INTEXT(NCHAR)
      CHARACTER*1  IOUTXT(NCHAR)
      CHARACTER*1  KOUTXT(256)
C
C     INTEGER*4  TABLET(64)    /18*Z2D2D2D2D, Z2D2D2D2F, Z3A29252D,
C    1  2*Z2D2D2D2D, Z2D2D2D2B, Z272A3F3E, Z26282D2D,
C    2    Z2D2D2D2D, Z2D2D2D2E, Z2D2D3B2D, 3*Z2D2D2D2D,
C    3    Z2D2D2C2D, 16*Z2D2D2D2D, Z2D010203, Z04050607,
C    4    Z08092D2D, Z2D2D2D2D, Z2D0A0B0C, Z0D0E0F10,
C    5    Z11122D2D, Z2D2D2D2D, Z2D2D1314, Z15161718,
C    6    Z191A2D2D, Z2D2D2D2D, Z1B1C1D1E, Z1F202122,
C    7    Z23242D2D, Z2D2D2D2D /
C     
      INTEGER    TABLET(32)
      EQUIVALENCE (KOUTXT(1), TABLET(1))
C
      DATA       TABLET  /
     1           4*Z'2D2D2D2D2D2D2D2D', Z'2D2D2D2D2B2D2D2D',
     2             Z'292A27252E262F28', Z'1B1C1D1E1F202122',
     3             Z'23242D3F3A2C3B2D', Z'2D01020304050607',
     4             Z'08090A0B0C0D0E0F', Z'1011121314151617',
     5             Z'18191A2D2D2D2D2D', 20*Z'2D2D2D2D2D2D2D2D'/
C
      IERR = 0
      NCH = NCHAR
         IF(NCH) 900,900,155
  155     CONTINUE
C
          DO I=1, NCH
             IOUTXT(I) = KOUTXT( MOVA2I(INTEXT(I)) + 1 )
          ENDDO
      RETURN
  900 CONTINUE
      IERR = 1
      RETURN
      END
