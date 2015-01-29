'open d3d.ctl'
'set display color white'
'set lev 1 64'
*prompt 'Enter the latitude for a meridional cross-section: '
*pull clat
*'set lat 'clat
'set lat 0'
'define cnv=ave(ave(cnvhrhbl,y=1,y=73),t=1,t=7)*86400'
'define lw=ave(ave(lwhrhbl,y=1,y=73),t=1,t=7)*86400'
'define sw=ave(ave(swhrhbl,y=1,y=73),t=1,t=7)*86400'
'define sha=ave(ave(shahrhbl,y=1,y=73),t=1,t=7)*86400'
'define vdf=ave(ave(vdfhrhbl,y=1,y=73),t=1,t=7)*86400'
'define lrg=ave(ave(lrghrhbl,y=1,y=73),t=1,t=7)*86400'

'colors'
'set cint 1'
'set gxout shaded'
'set black -.1 .1' 
'set clevs -8 -7 -6 -5 -4 -3 -2 -1 -.5 -.1 .1 .5 1 2 3 4 5 6 7 8'
'set ccols 49 48 47 46 45 44 43 42 41 51 0 31 21 22 23 24 25 26 27 28 29' 
'd cnv'
'cbarn'
'set cint 1'
'set gxout contour'
'set black -.1 .1'
'd cnv'
'draw title \\F24 T126 Meridional mean deep convective heating [K/day]'
'printim meridcnv_meanf24.png x1000 y800'

'c'
'set cint 1'
'set gxout shaded'
'set black -.1 .1'
'set clevs -20 -18 -16 -14 -12 -10 -8 -6 -4 -2 -1 -.5 -.1 .1 .5 1 2 4 6 8 10'
'set ccols 49 48 47 46 45 44 43 42 41 51 52 53 54 0 21 22 23 24 25 26 27 28'
'd lw'
'cbarn'
'set cint 1'
'set black -.1 .1'
'set gxout contour'
'd lw'
'draw title \\F24 T126 Meridional mean longwave radiative heating [K/day]'
'printim meridlwave_meanf24.png x1000 y800'

'c'
'set cint 1'
'set gxout shaded'
'set black -.1 .1'
'set clevs -.1 .1 .2 .4 .6. .8 1 2 4 6 8 10'
'set ccols 41 0 31 33 34 21 22 23 24 25 26 27 28'
'd sw'
'cbarn'
'set cint 1'
'set black -.1 .1'
'set gxout contour'
'd sw'
'draw title \\F24 T126 Meridional mean shortwave radiative heating [K/day]'
'printim meridswave_meanf24.png x1000 y800'

'c'
'set cint 1'
'set black -.1 .1'
'set gxout shaded'
'set clevs -2 -1 -.5 -.1 .1 .5 1 2 3 4 5 6'
'set ccols 49 47 45 43 0 21 22 23 24 25 26 27 28' 
'd sha'
'cbarn'
'set cint 1'
'set black -.1 .1'
'set gxout contour'
'd sha'
'draw title \\F24 T126 Meridional mean shallow convective heating [K/day]'
'printim meridshall_meanf24.png x1000 y800'

'c'
'set cint 1'
'set black -.1 .1'
'set gxout shaded'
'set clevs -8 -7 -6 -5 -4 -3 -2 -1 -.5 -.1 .1 .5 1 3 6 9 12 18 25'
'set ccols 49 48 47 46 45 44 43 42 41 51 0 21 22 23 24 25 26 27 28 29' 
'd vdf'
'cbarn'
'set cint 5'
'set black -.1 .1'
'set gxout contour'
'd vdf'
'draw title \\F24 T126 Meridional mean vertical diffusion heating [K/day]'
'printim meridvdiff_meanf24.png x1000 y800'

'c'
'set cint 1'
'set black -.1 .1'
'set gxout shaded'
'set clevs -7 -6 -5 -4 -3 -2 -1 -.5 -.1 .1 .5 1 2 3 4 5 6 7'
'set ccols 49 48 47 46 45 44 43 42 41 0 31 21 22 23 24 25 26 27 28 29'
'd lrg'
'cbarn'
'set cint 1'
'set black -.1 .1'
'set gxout contour'
'd lrg'
'draw title \\F24 T126 Meridional mean large scale condensation heating [K/day]'
'printim meridlrg_meanf24.png x1000 y800'
'quit'
