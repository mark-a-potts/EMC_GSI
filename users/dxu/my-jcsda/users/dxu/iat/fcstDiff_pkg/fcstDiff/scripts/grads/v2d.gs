'reinit'
'open /ptmp2/wd23sm/pgb/pgb.ctl1w'
'open /ptmp2/wd23sm/pgb/pgb.ctl2w'
'open /ptmp2/wd23sm/pgb/pgb.ctl3w'
'open /emcsrc3/wd23sm/scripts/climrl.ctl'
'enable print outu2w.gr'
*
'run /wd5/wd51/wd51js/rgbset.gs'
'set display color white'
'clear'
*
* This script good for U & V at 850 hPa and V at 200 hPa
*
'set t 1'
'set lev 850'
'set grads off'
'set grid off'
'set lon 0 360'
'set lat -90 90'
'define um=ave(ugrd,t=1,t=3)'
'define vm=ave(ugrd.2,t=1,t=3)'
'define tm=ave(ugrd.3,t=1,t=3)'
'define qm=(ugrd.4(t=1)+ugrd.4(t=2)+ugrd.4(t=12))/3'
*'define qm=(ugrd.4(t=6)+ugrd.4(t=7)+ugrd.4(t=8))/3'
*
*
*  Plotting Zonal Wind
*
'set parea 1.0 5.5  4.5 7.5'
'set grads off'
'set gxout shaded'
'set clevs -12 -6  6 12'
'set ccols 14 9 0 9 14' 
*'set clevs -10 -6 -4 4 6 10'
*'set ccols 10 14 9 0 9 14 10' 
'd um'
'set gxout contour'
'set cint 3 '
*'set cint 2 '
'set clab off'
'set ccolor 1'
'set grads off'
'd um'
'set clab on'
'set clevs -6 -3 0 3 6'
*'set clevs -6 -2 0 2 6'
'set ccolor 1'
'set grads off'
'd um'
*
'draw ylab Latitude'
'set string 1 tl 4 0'
'set strsiz 0.1'
'draw string 1.0 7.70 (a)'
'set string 1 tr 4 0'
'set strsiz 0.1'
*'draw string 5.5 7.70 Rk=3'
'set string 1 tc 5 0'
'set strsiz 0.15'
'draw string 3.25 7.70 RASV1'
*'run /emcsrc3/wd23sm/scripts/cbarnew.gs 0.7 0 3.25 4.25'
*
'set parea 6.0 10.5  4.5 7.5'
*
*
*  Plotting Meridional Wind
*
'set parea 6.0 10.5  4.5 7.5'
*
'set grads off'
'set gxout shaded'
'set clevs -12 -6  6 12'
'set ccols 14 9 0 9 14'
*'set clevs -10 -6 -4 4 6 10'
*'set ccols 10 14 9 0 9 14 10'
'd vm'
'set gxout contour'
'set cint 3 '
*'set cint 2 '
'set clab off'
'set ccolor 1'
'set grads off'
'd vm'
'set clab on'
'set clevs -6 -3 0 3 6'
*'set clevs -6 -2 0 2 6'
'set ccolor 1'
'set grads off'
'd vm'
*
'set strsiz 0.1'
'set string 1 tl 4 0'
'draw string 6.0 7.70 (b)'
'set string 1 tr 4 0'
*'draw string 10.5 7.70 Rk=3'
'set string 1 tc 5 0'
'set strsiz 0.15'
'draw string 8.25 7.70 RAS V2 NO DD'
*'run /emcsrc3/wd23sm/scripts/cbarnew.gs 0.7 0 8.25 4.25'
*
'set parea 1.0 5.5  1.0 4.0'
*
*  Plotting Temperature 
*
'set grads off'
'set gxout shaded'
'set clevs -12 -6  6 12'
'set ccols 14 9 0 9 14'
*'set clevs -10 -6 -4 4 6 10'
*'set ccols 10 14 9 0 9 14 10'
'd tm'
'set gxout contour'
'set cint 3 '
*'set cint 2 '
'set clab off'
'set ccolor 1'
'set grads off'
'd tm'
'set clab on'
'set clevs -6 -3 0 3 6'
*'set clevs -6 -2 0 2 6'
'set ccolor 1'
'set grads off'
'd tm'
'draw ylab Latitude'
'draw xlab Longitude'
*
'set strsiz 0.1'
'set string 1 tl 4 0'
'draw string 1.0 4.20 (c)'
'set string 1 tr 4 0'
*'draw string 5.5 4.20 Rk=3'
'set string 1 tc 5 0'
'set strsiz 0.15'
'draw string 3.25 4.20 RAS V2 With DD'
*'run /emcsrc3/wd23sm/scripts/cbarnew.gs 0.7 0 3.25 0.3'
*
*  Specific Humidity
*
'set parea 6.0 10.5  1.0 4.0'
*
'set grads off'
'set gxout shaded'
'set clevs -12 -6  6 12'
'set ccols 14 9 0 9 14'
*'set clevs -10 -6 -4 4 6 10'
*'set ccols 10 14 9 0 9 14 10'
'd qm'
'set gxout contour'
'set cint 3 '
*'set cint 2 '
'set clab off'
'set ccolor 1'
'set grads off'
'd qm'
'set clab on'
'set clevs -6 -3 0 3 6'
*'set clevs -6 -2 0 2 6'
'set ccolor 1'
'set grads off'
'd qm'
'draw xlab Longitude'
*
'set strsiz 0.1'
'set string 1 tl 4 0'
'draw string 6.0 4.20 (d)'
'set string 1 tr 4 0'
*'draw string 10.5 4.20 Rk=3'
'set string 1 tc 5 0'
'set strsiz 0.15'
'draw string 8.25 4.20 NCEP Reanalysis'
'set strsiz 0.2'
'set string 1 tc 6 0'
'draw string 5.5 8.0 DJF Mean 850 hPa U'
*'run /emcsrc3/wd23sm/scripts/cbarnew.gs 0.7 0 8.25 0.3'
*
'print'
