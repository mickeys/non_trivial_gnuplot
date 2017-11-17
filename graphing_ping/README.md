# Real-time monitoring and graphing of ping

I've been around, and let me tell you, sometimes it's not all it's cracked up to be, especially the networking, the Wi-Fi and wired connections both. Recently my productivity has been sorely challanged by exceedingly poor infrastructure. What's a coder to do? Well, write some code, of course.

**Goal**: I'd like to measure some quality of the connection between my computer and another one out there on the 'net. I'll show you how to see that connection quality first in text feormat, and then in graphic form. Each has its uses. You'll thank me later :-)

NOTE: My efforts were done in `bash` on <a href="https://en.wikipedia.org/wiki/MacOS">macOS</a>, which is a UNIX variant called 'darwin'. I believe all this code is portable to <a href="https://www.linux.org/">Linux</a> and <a href="https://msdn.microsoft.com/en-us/commandline/wsl/about">Ubuntu for Windows</a>. If you find a bug, please let me know. Code fragments will be used to describe useful patters; the complete source code appears at the bottom.

## Aim for a target

A network consists of (at minimum) two computers, yours and one other. On your local networks, and the Internet, there are many computers. You can "reach" many of them. Which to pick as our target?

If you're doing this for a work project, then you possibly have some local computer in mind, something that's vital to your business and must be reachable at all times. For the rest of us, we just want something "out there" that will serve as our target.

A very common US-centric target is the Google <a href="https://en.wikipedia.org/wiki/Domain_Name_System">DNS</a> cluster, identified by the very easy-to-remember IP address of 8.8.8.8. Feel free to substitute something appropriate for your country. The use case of working behind the <a href="https://en.wikipedia.org/wiki/Great_Firewall">Great Firewall of China</a> is covered below.

For the moment, though, we'll use

```
target='8.8.8.8'				# Aim at Google's DNS nameserver
```

and anywhere in the following, when you read `$target`, you'll know that it's pointing to a comuter, run by Google to do something useful, and which has a known address.

## Is there a network?

Before we can do any network performance checking, much less any graphing, we need to have a network. A simple, lightweight, way of checking is:

```
# -----------------------------------------------------------------------------
# Is there a network?
# -----------------------------------------------------------------------------
if eval nc -z -w 1 "$target" 80 >& /dev/null ; then
    echo "the network is up, continuing..."
    # 
    # put your code here
    #
else
    echo "network is down, giving up..." ; exit 0
fi
```

The code above reaches out to `$target` on port 80, throwing the reported data into the trash, `/dev/null`. We're interested only in the true-false result, which tells us whether the network is up. Fret not about targets and ports: as an analogy, think of `$target` as the street address, ond the port as the apartment number. To get to dinner you have to get the building and apartment correct. :-)

## ping

We'll be using UNIX's `ping` program, which <a href="https://en.wikipedia.org/wiki/Ping_%28networking_utility%29">sends a packet information to the target, and will receive one in return</a>. We type the `ping` command into a "terminal", with some mandiatory additional data, like this: 

```
ping -i $interval_in_seconds $target
```

Here's how it all looks like: the computer tells you it's ready for you by showing you a `%`. (Your terminal may show something different, ilke `yourname $`, but you get the idea.) We're going to tell ping to, well, ping computer 8.8.8.8 repeatedly, at an interval of 1 second between pings.

In response, ping will forever hit that machine, reporting (at the end of each line) how long it took for a message to go between the computers, in milliseconds. Shorter times are better; longer times result in your interactions with that computer feel laggy.

Messages don't go directly through the tubes from your computer to the target. Instead, they hop through computer after computer, like a demented game of hopscotch. There's a command to show you about the path the message is taking - `traceroute` - but we'll get to that some other day.

```
% ping -i 1 8.8.8.8
PING 8.8.8.8 (8.8.8.8): 56 data bytes
64 bytes from 8.8.8.8: icmp_seq=0 ttl=50 time=90.733 ms
64 bytes from 8.8.8.8: icmp_seq=1 ttl=50 time=89.013 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=50 time=86.486 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=50 time=89.420 ms
64 bytes from 8.8.8.8: icmp_seq=4 ttl=50 time=86.697 ms
64 bytes from 8.8.8.8: icmp_seq=5 ttl=50 time=213.006 ms
^C
--- 8.8.8.8 ping statistics ---
6 packets transmitted, 6 packets received, 0.0% packet loss
round-trip min/avg/max/stddev = 86.486/109.226/213.006/46.436 ms
%
```

The `^C` shows where I've interrupted the program by typing <a href="https://en.wikipedia.org/wiki/Control-C">Control-C on my keyboard</a>.

Many things impact the time it takes for a message to reach the target: physical distance the message has to travel, the quality of the connection between each of the computer through which the message hops, and the type of connection. (You can reach the Internet from a cruise ship, but the _latency_ of the connection makes it an unpleasant experience; the lag, not the cruise.

To be complete, not every ping is as successful as the one shown above, able to report a connection and a time. If your network is down you'll see something like:

```
Request timeout for icmp_seq 11
ping: sendto: No route to host
ping: sendto: No route to host
```

## The parts of our live-graphing utility

Look at that, we're already past the preamble. Not a lot of requisite experience needed. Let's move on to our program, which is broken into two interacting parts:

1. The _collector_, gathering data on the health of the connection between your computer and `$arget`, and
2. The _grapher_, which will pictorially display the data.

### The collector

The collector code is:

```
ping -i "$interval" "$target" | \
	/usr/local/bin/grep --line-buffered -oP "time=\K(\d*)\.\d*" 2>&1 >> "$outfile" &
echo "Collecting data..."				# warn about sleep()
sleep $(( interval * 2 ))				# time to get several data points
```

We'll specify `$outfile` later. The above does the `ping` command, sending it's output through `grep` (to which I've specified a filter that returns only the time portion), which is added to the end of `$outfile`, and because I've finished up that line with `&` the ping runs in the background, hidden from sight. Then the foreground program sleeps for twice the `$interval` in order to gather enough data to begin graphing. The phrase `Collecting data...` reassures the human that everything is proceeding as planned.

NOTE: I had to specify `/usr/local/bin/grep` to get the optionally-installed version that I use, rather than the system-installed default version, to have the ``--line-buffered` functionality.

### The grapher

Now that we are collecting data, we have something to graph. We'll be using <a href="https://en.wikipedia.org/wiki/Gnuplot">gnuplot</a>, a free, widely-available program, to plot our data. The grapher code looks like:

```
while true ; do							# continue forever until ^C at terminal
	gnuplot -persist <<-END				# start plotting, leaving the output
		set terminal dumb 90 28			# show only simple keyboard characters
		# ---------------------------------------------------------------------
		# Plot the last 20 lines of $outfile, using grep to get the ping times.
		# Plot using only simple keyboard characters, like *, -, +, etc.
		# ---------------------------------------------------------------------
		plot '<tail -n 20 "$outfile" | grep -oP "time=\K(\d*)\.\d*"' \
			with impulses title 'ping $target (ms)'
		pause "$interval"				# let the next datapoint to be caught
		reread							# re-read the input and plot new data
END	
done									# the end of the infinite loop
```

With these commands in a file we'll call `pinger.sh`, typing:

```
% bash pinger.sh
```

Will result in:

<center><table cellpadding="20" border="1" width="66%">
	<tr><td bgcolor="black"><img src="graphing_ping.gif"></td></tr>
</table></center>

which is updated every `$interval`.

And there you go: live graphing of generated data!

There are so many possible improvements, starting with passing the target on the command line, to dealing with being in China, to using a Caca terminal to get prcetty graphic output instead of keyboard characters on a dumb terminal.

## The Great Firewall of China 防火长城

<a href="https://en.wikipedia.org/wiki/Great_Firewall">Great Firewall of China</a> (防火长城), officially Project Golden Shield, is a censorship and surveillance project that blocks politically inexpedient data from foreign countries arriving over the Internet.

If you're a businessperson visiting China, or a resident, you'll find that the Google infrastructure - from search to Gmail to Google Maps and Photos - are blocked. To bore a tunnel through the Golden Shield, we use a <a href="https://en.wikipedia.org/wiki/Virtual_private_network">virtual private network</a>, or VPN. (It's beyond this document to discuss the evaluation, installation, and use of a VPN, but <a href="https://openvpn.net">OpenVPN</a>, a program that will work on your laptop and smartphones, is a good place to start.

The following code presumes you're inside of China: it simplistically tests for the presence of an active VPN, and, assuming you're surrounded by the Great Firewall, if the VPN is active, it'll set the target to a Google server, if not, it'll reach for something available in the Middle Kingdom. If you're never in a place that has restrictive connection rules, or you never use a VPN, just ignore this code fragment.

```
vpn=$( netstat -rn | grep -c utun1 )	# check for any tunnels in action
if [[ $vpn -eq 0 ]] ; then
	# ----------> no VPN, assume Great Firewall of China, use baidu <----------
	target='baidu.com'					# the machine we're trying to ping
else
	# ----------> VPN, so use Google services <--------------------------------
	target='www.google.com'				# the machine we're trying to ping
fi
```

## The whole solution

Folloting is the complete code for `pinger.sh`. As you're preusing the code, note please two coding styles that I heartily recommend:

Defensive programming - because I long-ago learned that if I didn't take time to write code to test all the possible things that can go wrong then I'll spend way longer when something unexpected is encountered and my program falls over.

Copieus comments - because there's nothing quite a frustrating as spending time figuring out what you were thinking when you wrote the code that just fell over. Stream-of-consciousness commenting, adding explanations as you're actually writing the code, saves countless hours later. Trust me on both of these points.

Here's the program, exactly as it is on my computer, just as I use it:

```
#!/usr/local/bin/bash
#set -x									# turn on shell debugging on bad days

# -----------------------------------------------------------------------------
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
vpn=$( netstat -rn | grep -c utun1 )	# check for any tunnels in action
if [[ $vpn -eq 0 ]] ; then
	# ----------> no VPN, in USA, use google <----------
	target='www.google.com'				# the machine we're trying to ping
#	dns='8.8.8.8'						# Google's public DNS nameserver
else
	# ----------> VPN, in USA, use something custom <--------
	target='baidu.com'					# the machine we're trying to ping
#	dns='61.139.2.69'					# DNS for Chengdu, Sichuan, China
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
ping -i "$interval" "$target" | \
	/usr/local/bin/grep --line-buffered -oP "time=\K(\d*)\.\d*" 2>&1 >> "$outfile" &
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
		plot "<tail -n $points $outfile" with impulses title "$( date +"%Y-%m-%d %H:%M:%S" )"
		pause "$interval"
		reread
END
done									# the end of the infinite loop
###############################################################################
#     T H E    E N D
###############################################################################
```
