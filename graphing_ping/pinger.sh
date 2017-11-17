#!/usr/local/bin/bash
#set -x									# turn on shell debugging on bad days

# -----------------------------------------------------------------------------
# Michael Sattler <michael@sattlers.org>
#
# https://github.com/mickeys/gnuplot/blob/master/graphing_ping/pinger.sh?ts=4
#
# This script does real-time graphing of `ping` output, showing one measure of
# network health. It does rudimentary preliminary network sanity-checking, and
# handles the network dropping during the graphing by dropping the data to 0,
# which is easy to spot as an error state; infinitely fast packets, anyone?
#
# This script creates (and destroys) one helper file, $outfile. It depends upon
# gnuplot, but that's not an onerous requirement :-)
#
# I've commented heavily throughout, as this shows off some easy-to-understand,
# useful network and plotting patterns.
#
# I've stood on the shoulders of many Internet giants, but all errors are mine.
# -----------------------------------------------------------------------------
# Remember, kids: always use http://shellcheck.org/ when using bash!
# -----------------------------------------------------------------------------

###############################################################################
#     H O U S E K E E P I N G
###############################################################################
interval=1								# how long between pings, in seconds
retry=3									# how long before sanity-checking, in s

tmp=$(mktemp -dt "$(basename "$0").XXXXXXXXXX")	# a safe place to store files
outfile="$tmp/out.txt"					# where we log connectivity data

trap cleanup SIGHUP SIGINT SIGTERM		# do cleanup() when quitting happens
function cleanup {						# called when trapped quit is caught
	#rm -rf "$tmp"						# destroy our temporary output files
	exit 1								# and we're all done!
}

# -----------------------------------------------------------------------------
# General-purpose debugging set-up.
# -----------------------------------------------------------------------------
QUIET=''								# '' = quiet, 'ANYTHING' show commands
if [[ $QUIET ]] ; then QUIET='>& /dev/null' ; fi

DEBUG=''								# '' = quiet, 'ANYTHING' show debugs
debug() { if  [[ $DEBUG ]] ; then echo "${FUNCNAME[1]}(${LINENO}): $1" ; fi }

###############################################################################
#     S E T    A    T A R G E T
###############################################################################

# -----------------------------------------------------------------------------
# Set the $target remote computer by seeing if we're using a VPN. Simplistic.
#
# This code presumes you're located outside of China; otherwise switch the
# contents of the true and false branches. If you're in China, but never use
# any firewalled resources, feel free to manually set $target and comment out
# this entire section.
# -----------------------------------------------------------------------------
#vpn=$( netstat -rn | grep -c utun1 )	# check for any tunnels in action
#if [[ $vpn -eq 0 ]] ; then
#	# ----------> no VPN, assume Great Firewall of China, use baidu <----------
#	target='www.google.com'				# the machine we're trying to ping
##	dns='8.8.8.8'						# Google's public DNS nameserver
#else
#	# ----------> VPN, so use Google services <--------------------------------
#	target='baidu.com'					# the machine we're trying to ping
##	dns='61.139.2.69'					# DNS for Chengdu, Sichuan, China
#fi

vpn=$( netstat -rn | grep -c utun1 )	# check for any tunnels in action
if [[ $vpn -eq 0 ]] ; then
	# ----------> no VPN, assume Great Firewall of China, use baidu <----------
	target='baidu.com'					# the machine we're trying to ping
#	dns='61.139.2.69'					# DNS for Chengdu, Sichuan, China
else
	# ----------> VPN, so use Google services <--------------------------------
	target='www.google.com'				# the machine we're trying to ping
#	dns='8.8.8.8'						# Google's public DNS nameserver
fi

###############################################################################
#     S A N I T Y    C H E C K I N G
###############################################################################

# -----------------------------------------------------------------------------
# Now that we've done all the housekeeping, let's see whether we can ping the
# $target; if we can't everything else will fail; it's best to know early on.
#
# Trap the timeout "89599 Alarm clock" signal and proceed quietly. <- fails :-/
# -----------------------------------------------------------------------------
while true ; do
	( trap - SIGALRM ; ping -c 1 -t 1 baidu.com >& /dev/null )
	case "$?" in
		0)	break ;; # success - At least one response was heard.
		2)	break ;; # success - Transmission was successful, no responses tho.
		*)	echo '+---------------------+ WARNING:'
			echo "| $( date +"%Y-%m-%d %H:%M:%S" ) | Can't reach $target."
			echo "+---------------------+ Check network; retry in $retry."
			echo ''
			#exit 1
			;;
	esac
	sleep $retry						# give human a chance to check network
done

###############################################################################
#     T H E    C O L L E C T O R
###############################################################################

# -----------------------------------------------------------------------------
# Start data collection happening in the background.
# -----------------------------------------------------------------------------
set -x
ping -i "$interval" "$target" | \
	grep --line-buffered -oP "time=\K(\d*)\.\d*" 2>&1 >> "$outfile" &
set +x
echo "$( date +"%Y-%m-%d %H:%M:%S" ) Collecting data..." # warn about sleep()
sleep $(( interval * 2 ))				# time to get several data points

###############################################################################
#     T H E    G R A P H E R
###############################################################################

# -----------------------------------------------------------------------------
# Now that data is being collected in the background, in the foreground forever
# loop through reading and graphing that data.
# -----------------------------------------------------------------------------
points=80								# display the last $points of data
term_wid=90								# terminal is this wide to display data

while true ; do							# forever until ^C is trapped
	gnuplot -persist <<-END
		set terminal dumb $term_wid 28
		plot "<tail -n $points $outfile" \
			with impulses title "$( date +"%H:%M:%S" )"
		pause "$interval"
		reread
END
done									# the end of the infinite loop
###############################################################################
#     T H E    E N D
###############################################################################