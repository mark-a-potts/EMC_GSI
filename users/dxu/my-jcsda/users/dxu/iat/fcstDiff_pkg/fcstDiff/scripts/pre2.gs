*'open /tmp/wd23sm/rungras32/flx.ctl'
'open /tmp/wd23sm/jan3/flx.ctl'
*
'run /wd5/wd51/wd51js/rgbset.gs'
'set display color white'
'clear'
*
'enable print out.gr'
*
'set t 1'
'set grads off'
'set grid off'
'set t 1 115'
'define pm3=aave(prate*86400,lon=0,lon=360,lat=-90,lat=90)'
'define cm3=aave(cprat*86400,lon=0,lon=360,lat=-90,lat=90)'
'define em3=aave(lhtfl*0.03456,lon=0,lon=360,lat=-90,lat=90)'
'define pw3=aave(pwat,lon=0,lon=360,lat=-90,lat=90)'
*
' set lon 0'
' set t 2 115'
'set parea 1.0 5.5  4.5 7.5'
'set axlim 0 4'
'set cthick 5'
'set ccolor 1'
'set cstyle 1'
'set cmark 0'
'set grads off'
'd pm3'
'set ccolor 1'
'set cmark 0'
'set cstyle 3'
'set grads off'
'd em3'
'set ccolor 1'
'set cmark 0'
'set cstyle 5'
'set grads off'
'd cm3'
'set ccolor 1'
'set cmark 0'
'set cstyle 6'
'set grads off'
'd pm3-cm3'
'draw ylab (mm/day)'
'run /emcsrc3/wd23sm/scripts/lnspcc.gs leg4p'
'set string 1 tl 4 0'
'set strsiz 0.1'
'draw string 1.0 7.65 (a)'
'set string 1 tr 4 0'
'set strsiz 0.1'
'draw string 5.5 7.65 Rk=3'
*
*'set parea 6.0 10.5  4.5 7.5'
*
'print'
'c'
' set t 1 115'
*
'set parea 2.5 8.5  1.5 7.0'
'set axlim 23 28'
'set cthick 5'
'set ccolor 1'
'set cstyle 1'
'set cmark 0'
'set grads off'
'd pw3'
'draw title Global Mean Precipitable Water (Kg/m**2)'
*'run /emcsrc3/wd23sm/scripts/lnspcc.gs leg4pw'
*
'print'
