# -----------------------------------------------------------------------------
# Filename:	archive.gp
# Purpose:	Describe the process of using gnuplot to map battery usage data.
# Author:	Michael Sattler
# -----------------------------------------------------------------------------

set terminal svg size 768,512			# background rgb 'white'
set datafile separator ","				# properly handle Excel CSV files

set label 99 at screen 0.985, screen 0.07 rotate by 90 font ",16"
file='data/2017-08-18.csv'

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set label 99 '' # Figure 0 - nothing at all
set output 'figures/0.svg'
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set key off
plot "<echo '0 0'" with points linecolor rgb 'white'
set output

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set label 99 'Figure 1 - default gnuplot configuration'
set output 'figures/1.svg'
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
plot file every 3 with linespoints
set output

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set label 99 'Figure 2 - switch x and y axes for x=time'
set output 'figures/2.svg'
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
plot file every 3 using 2:1 with linespoints
set output

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set label 99 'Figure 3 - x axis as hours, not seconds'
set output 'figures/3.svg'
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
plot file every 3 using ($2/3600):1 with linespoints
set output

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set label 99 'Figure 4 - lines and labels'
set output 'figures/4.svg'
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
plot file every 3 using ($2/3600):1 with linespoints, \
	file every 3 using ($2/3600):1:(sprintf( '(%d,%d)', ($2/3600), $1)) \
		notitle with labels offset 3,0
set output


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set label 99 'Figure 5 - lots of prettifying'
set output 'figures/5.svg'
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set label 99 at screen 0.985, screen 0.11 # a label positioned for later use

set terminal svg size 768,512 linewidth 3 # background rgb 'white'

# global changes for all plots
set pointsize 2								# globally set points to this size
set style data linespoints					# globally set lines to this style

# chart title and axes labels
set title  'Battery Longevity' font ',32' offset 0,-2,0
set xlabel 'Time (hours)' font ',24' offset 0,0.2,0
set ylabel 'Charge (percent)' font ',24' offset 1,0,0

# background grid
set grid linetype 0 linewidth 1 linecolor rgb "#DCDCDC"

# axes labels
set tics font ', 18' textcolor rgb 'red' nomirror scale 0
set ytics rotate by 45 right

# key (legend)
set key title 'My Phone' bottom left box linewidth 1 font ',18'

plot file every 3 using ($2/3600):1 with linespoints \
	pointtype 7 pointsize 1 title 'Wi-Fi off '
set output

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set label 99 'Figure 6 - maximising plot by stats & range'
set output 'figures/6.svg'
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +-----------------+
# We're currently doing measurements from a full            |  1           5  |
# state to empty, then back to full. So our graph           |     2     4     |
# of one complete test cycle winds up looking like          |        3        |
# the diagram at right, a 'v'.                              +-----------------+
#
# When the focus is on the depletion process, it's          +-----------------+
# easier for researchers to see just the downward           |  1              |
# part of the data. To do this we need to find the          |        2        |
# minimum data point and use 'xrange' to limit output.      |              3  |
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +-----------------+
stats file using ($2/3600):1 prefix "STATS" nooutput
set xrange [0:STATS_pos_min_y]
plot file every 3 using ($2/3600):((($2/3600) <= STATS_pos_min_y) ? $1 : 1/0) \
	with linespoints pointtype 7 pointsize 1 title 'Wi-Fi off '
set output
unset xrange

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set output 'figures/7.svg'
set label 99 'Figure 7 - plotting multiple data files by looping'
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set key opaque							# show legend over plot lines
plots=''								# create before using
files=system("ls -1B data/2017*csv | sort")
do for [ file in files ] {
#	filename=system( 'basename "'.file.'" | sed -e "s/.csv//g"' )
	# "data/2017-MM-DD.csv" -> "2017-MM-DD.csv"
	name_from_path=system( 'basename "'.file.'"' )
	# "2017-MM-DD.csv" -> "2017-MM-DD"
	part_from_name=system( 'basename "'.name_from_path.'" .csv' )

	conditional=sprintf( '($2/3600):1' )
	action=sprintf( '"%s" every 3 using %s with linespoints title "%s", ', \
		file, conditional, part_from_name )
	plots=plots.action					# add this plot to the ongoing list
}
eval('plot '.plots)						# finally plot the whole bunch
set output

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set output 'figures/8.svg'
set label 99 'Figure 8 - stats & range for multiple plots'
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
my_xrange=0
plots=''
files=system("ls -1B data/2017*.csv | sort")
do for [ file in files ] {
	stats file using ($2/3600):1 prefix "STATS" nooutput

	if ( STATS_pos_min_y > my_xrange ) { my_xrange = STATS_pos_min_y }
print sprintf( "7: my_xrange %f.2 for file %s", my_xrange, file ) ;

	# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	conditional=sprintf( '($2/3600):((($2/3600) <= %.2f) ? $1 : 1/0)', STATS_pos_min_y )
	filename=system( 'basename "'.file.'" | sed -e "s/.csv//g"' )
	action=sprintf( '"%s" every 3 using %s with linespoints title "%s", ', \
		file, conditional, filename )
	plots=plots.action					# add this plot to the ongoing list
}
set xrange [0:my_xrange]				# show only the width calculated
eval('plot '.plots)						# finally plot the whole bunch
set output

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set output 'figures/9.svg'
set label 99 'Figure 9 - stats & range for multiple plots'
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#set grid linecolor rgb '#708090'

my_xrange=0
plots=''
files=system("ls -1B data/2016*.csv | sort")
do for [ file in files ] {
	stats file using ($2/3600):1 prefix "STATS" nooutput

	if ( STATS_pos_min_y > my_xrange ) { my_xrange = STATS_pos_min_y }

	conditional=sprintf( '($2/3600):((($2/3600) <= %.2f) ? $1 : 1/0)', STATS_pos_min_y )
	filename=system( 'basename "'.file.'" | sed -e "s/.csv//g"' )
	action=sprintf( '"%s" every 3 using %s with linespoints notitle linecolor "#D2B48C", ', \
		file, conditional, filename )
	plots=plots.action					# add this plot to the ongoing list
}

# .............................................................................
# I hard-code the colors used in the main plot to make things easier to see as
# the default colors just don't do a good job of showing the contrast between
# the two datasets.
#
# Good on you for digging deep and finding this; reading the source code is a win!
# .............................................................................
set style line 1 lt 1 lw 1 pt 8 ps 2 linecolor rgb "red"
set style line 2 lt 1 lw 1 pt 10 ps 2 linecolor rgb "blue"
set style line 3 lt 1 lw 1 pt 7 ps 2 linecolor rgb "#006400" # or "darkgreen"

i=1
files=system("ls -1B data/2017*.csv | sort")
do for [ file in files ] {
	stats file using ($2/3600):1 prefix "STATS" nooutput

	if ( STATS_pos_min_y > my_xrange ) { my_xrange = STATS_pos_min_y }

	conditional=sprintf( '($2/3600):((($2/3600) <= %.2f) ? $1 : 1/0)', STATS_pos_min_y )
	filename=system( 'basename "'.file.'" | sed -e "s/.csv//g"' )
	action=sprintf( '"%s" every 3 using %s with linespoints ls %d title "%s", ', \
		file, conditional, i, filename )
	i=i+1
	plots=plots.action					# add this plot to the ongoing list
}

set xrange [0:my_xrange]				# show only the width calculated
eval('plot '.plots)						# finally plot the whole bunch
set output

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# article post-processing
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
my_figs='./figures'
files=system("ls -1B figures/*.svg | sort")
do for [ file in files ] {
	my_file=system( 'basename '.file )
	my_fn=system( 'basename '.my_file.' .svg' )
	print 'post-processing '.file
	file_path=sprintf( '%s/%s', my_figs, my_fn )
	convert=sprintf( 'convert -resize 768x512 -background none "%s.svg" "%s.png" ; rm "%s.svg"', \
		file_path, file_path, file_path )
	system( convert )
}
