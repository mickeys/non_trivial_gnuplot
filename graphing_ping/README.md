# Triaging networking issues in real-time

One of my life's greatest pleasures is travel. While I started in pre-digital times, now I — like most of us — rarely move about without at least a phone and often with a laptop. Presupposing the availability of a reasonably reliable network connection will lead to frustration and failure. This column describes how I came to triage issues in far-flung places like Sichuan, China, and Cape Town, South Africa. The techniques and code I used can help you on your travels.

## You can't fix what you can't measure

One symptom of first-world hubris is imagining the rest of the world has heavy bandwidth available upon demand (as we do in much of the cosmopolitan USA). The cost to individuals and governments for this kind of infrastructure is prohibitive, and so — at a very minimum — the mobile apps and websites you've grown used to will perform poorly, if at all. Blocking behavior while waiting on large images or supporting data to be delivered yields poor results or complete failure.

Most recently, on a months-long trip to China, my work productivity and social participation was sorely challenged by exceedingly poor infrastructure. Hotel technical support was seemingly limited to "let us reboot the Wi-Fi access point nearest to you"; without the real-time measurements of bad performance there was no chance of enlisting IT to improve the situation.

## We need connectivity, latency, and bandwidth

Being able to reach the computer which has data you desire — **connectivity** — is the first hurdle to retrieving data. If there's no route from your device to the requested computer over the network then nothing good can follow.

The lag in the time it takes data to pass from one point on a network to another — **latency** — is usually what social media scrollers and video game players mean when "my computer is slow" is uttered. Latency issues can happen when the route between devices is inefficient, having too many "hops", or hardware along the route is performing poorly.

The volume of data transmitted over the connection — **bandwidth** — restricts performance; "starving for content" exposes assumptions in app code about what's necessary to proceed (like preventing entering a search phrase until a graphic banner finishes loading). Bandwidth assumptions are so important that software quality assurance teams will frequently "throttle" their existing network to simulate real-world locations to make apps and websites work better in resource-constrained situations.

## Our goal is to provide actionable information

Having discovered that hotel IT can't be motivated to fix what can't be measured, my goal was to test the performance of my laptop and provide actionable information to improve my circumstances whilst on the road. Read on to have the same tools in your kit; at the end of this post you'll have the ability to see and share text and graphic measurements of the networks you traverse.

While my efforts were done in `bash` on <a href="https://en.wikipedia.org/wiki/MacOS">macOS</a>, a UNIX variant called 'darwin', I believe all this code is portable to <a href="https://www.linux.org/">Linux</a> and <a href="https://msdn.microsoft.com/en-us/commandline/wsl/about">Ubuntu for Windows</a>. If you find a bug, please let me know. Code fragments will be used to describe useful patterns; the complete source code appears at the bottom.

## Reporting issues textually

The most bare-bones solution is to use the built-in tools to measure network issues. The following section covers how to obtain this basic information in a text-based way.

### First step: aim for the target

A network consists of (at minimum) two computers, yours and the one with which you want to communicate. On your local networks, and the Internet, there are many computers within reach. Which to pick as the target?

If you're suffering network connectivity issues with a work project, then you may have a specific computer in mind, something vital to your business process (like an email server), that would serve as a good target. If not, finding a public computer with high availability will serve as our target.

A very common US-centric target is the Google <a href="https://en.wikipedia.org/wiki/Domain_Name_System">DNS</a> cluster, identified by the very easy-to-remember IP address of 8.8.8.8. Feel free to substitute something appropriate for your country. (The use case of working behind the <a href="https://en.wikipedia.org/wiki/Great_Firewall">Great Firewall of China</a> is covered below.)

For the moment, though, we'll use

```
target='8.8.8.8'				# Aim at Google's DNS nameserver
```

Later, when you come across `$target` you'll know that it's pointing to a well-known highly available networking resource.

### Is there a network?

Before we can do any network performance checking, much less any graphing, we need to have connectivity. A simple, lightweight, way of checking is:

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

The code above reaches out to `$target` on port 80 (through which web pages are transmitted) and throws the data returned directly into the trash, `/dev/null`. We're interested only in the true-false result, which tells us whether the network is up. 

As an analogy to targets and ports, think of `$target` as the street address and the port as the apartment number. To successfully visit a friend you have to get both the street address and apartment number correct.

### ping

We'll be using UNIX's `ping` program, which <a href="https://en.wikipedia.org/wiki/Ping_%28networking_utility%29">sends a packet of information to the target, and will receive one in return</a>. (We are typing into your computer's "terminal app".) The `ping` command, along with some necessary arguments, consists: 

```
ping -i $interval_in_seconds $target
```

Looking at a real-world example:

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

we can see your computer showing it's ready for input with a prompt — in this case `%`. Yours may show something different, like `yourname $`. We're going to tell ping to, well, reach out to the computer with the IP address 8.8.8.8 repeatedly, with an interval of 1 second between pings.

In response, ping will forever hit that machine, reporting (at the end of each line) how long in milliseconds it took for a message to go between the computers. Shorter times are better; longer times result in your interactions with that computer feel laggy.

Packets don't go directly through the tubes from your computer to the target. Instead, they hop from computer to computer, like a demented game of hopscotch. The `traceroute` command will reveal the path taken, but that's a topic for another day.

The `^C` shows where I've interrupted the program by typing <a href="https://en.wikipedia.org/wiki/Control-C">Control-C on my keyboard</a>.

Many things impact the time it takes for the ping to make a round-trip: the physical distance the message has to travel, the quality of the connection between each of the computers through which the message hops, and the type of connection. (One can reach the Internet from a cruise ship, but the latency of the connection makes it an unpleasant experience; the lag, not the cruise.)

To be complete, not every ping is able to report a connection and a time, as shown above. If your network is down you'll see something like:

```
Request timeout for icmp_seq 11
ping: sendto: No route to host
ping: sendto: No route to host
```

The ping results are one thing you can share with hotel IT support to give depth to your complaints.

## Reporting issues graphically

We're wired to process visual imagery. Obtain meaning by representing ping information is often more powerful and motivating than text.

Additionally, you can adapt the following code to other sources of textual data.

Our live-graphing utility consists of two interacting parts:

1. The _collector_, gathering the `ping` values, and
2. The _grapher_, pictorially displaying the values

### The collector

The collector code consists of:

```
ping -i "$interval" "$target" | \
	/usr/local/bin/grep --line-buffered -oP "time=\K(\d*)\.\d*" 2>&1 >> "$outfile" &
echo "Collecting data..."				# warn about sleep()
sleep $(( interval * 2 ))				# time to get several data points
```

We'll specify `$outfile` later. The above code:

* does the `ping`
* sends the result to the `grep` command (to which I've specified a filter that returns only the time portion)
* the result of which is written to the end of `$outfile`
* and because I've ended that line with `&` the `ping` runs in the background, hidden from sight, while the foreground program sleeps for twice the `$interval` in order to gather enough data to begin graphing.
* The phrase `Collecting data...` reassures a human viewer that things are proceeding as planned.

(In order to get the enhanced `--line-buffered` functionality of `grep` I installed GNU Grep package into `/usr/local/bin/grep` as the Apple-provided `grep` is too basic.)

### The grapher

To graph the data being gathered by the collector we'll be using <a href="https://en.wikipedia.org/wiki/Gnuplot">gnuplot</a>, a free, widely-available program, to plot our data. The grapher code looks like:

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

With the grapher code saved in a file named `pinger.sh` we can invoke the graphic display by typing:

```
% bash pinger.sh
```

The result, updated every `$interval`, will appear something like:

<center><table cellpadding="20" border="1" width="66%">
	<tr><td bgcolor="black"><img src="graphing_ping.gif"></td></tr>
</table></center>

This live graphing of generated data can be improved in so many ways, from passing the target to `pinger.sh` on the command line to using a more capable terminal to get prettier graphic output instead of letter characters. I settled upon this solution as it'll work for most computer setups.

While in China I had to cope with the added obstacle of an aggressive firewall.

## The Great Firewall of China 防火长城

<a href="https://en.wikipedia.org/wiki/Great_Firewall">Great Firewall of China</a> (防火长城), officially Project Golden Shield, is a censorship and surveillance project that blocks politically inexpedient data from foreign countries arriving over the Internet.

If you're a businessperson visiting China, or a resident, you'll find that the Google infrastructure - from search to Gmail to Google Maps and Photos - are blocked. Boring a tunnel through the Golden Shield we require a <a href="https://en.wikipedia.org/wiki/Virtual_private_network">virtual private network</a>, or VPN. (It's beyond this document to discuss the evaluation, installation, security implications, and general use of a VPN, but <a href="https://openvpn.net">OpenVPN</a>, a program that will work on your laptop and smartphones, is a good place to start.)

The following code presumes you're inside of China or a similar environment. The code simplistically tests for the presence of an active VPN, and, assuming you're surrounded by the Great Firewall, if the VPN is active it'll set the target to a Google server, and if not it'll reach for a target that's freely-available within the Middle Kingdom. If you're never in a place that has restrictive connection rules, or you never use a VPN, you can skip this code fragment.

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

## Conclusion

Find the complete source code for `pinger.sh` in several places:

* if you have a local copy, in the same directory as this README file
* online, in the master `git` repository, at
[https://github.com/mickeys/gnuplot/blob/master/graphing_ping/pinger.sh
](https://github.com/mickeys/gnuplot/blob/master/graphing_ping/pinger.sh?ts=4)

As you're perusing the code for `pinger.sh` please note two coding styles that I heartily recommend:

* Defensive programming — long ago I learned that if I didn't take time to write code to test all the possible things that can go wrong then I spent far longer when encountering the unexpected is and my program falls over.

* Copious comments — there's nothing quite a frustrating as spending time teasing out your thought process as you wrote the code that just fell over. Stream-of-consciousness commenting, adding explanations as you're actually writing the code, saves countless hours later.

Lastly, please remember the framework described here can be adapted to graphically display other commands which report numeric results. This can convey relationships in a powerful way. For a concrete example, I've documented my process of retrieving battery-usage telemetry from mobile devices and graphing the results for a general audience in _[gnuplot ~ a non-trivial introduction](https://github.com/mickeys/non_trivial_gnuplot/blob/master/a_real_world_gnuplot_introduction/README.md)_ (which also shows how to make flexible Lisp-like self-modifying code within GNU Plot).
