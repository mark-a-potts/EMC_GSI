 subroutine seaice

 use program_setup, only         : seaice_file

 implicit none

 character*3                    :: interp_mask
 character*2                    :: interp_type
 character*150                  :: output_file

 integer                        :: grib_scale_fac
 integer                        :: iunit_out

 real                           :: default_value

!-----------------------------------------------------------------------
! initialize some variables, then call interp driver.
!-----------------------------------------------------------------------

 if (len_trim(seaice_file) == 0) return

 print*,"- INTERPOLATE SEA ICE DATA TO MODEL GRID"
 
 output_file    = "fort.72"   ! grib file of data on model grid.
 iunit_out      = 72          ! unit # of above.
 grib_scale_fac = 0           ! # decimal places. make a yes/no flag 
 default_value  = -99.        ! if interp routine can not find data
                              ! at a model grid point, set to this value.
 interp_type    = "xx"        ! let routine logic choose interp method
 interp_mask    = "wtr"       ! a land field

 call interp_to_mdl(seaice_file, output_file, iunit_out, &
                    interp_type, default_value, grib_scale_fac, &
                    interp_mask)

 return

 end subroutine seaice
