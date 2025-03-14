This is a README for using Netatalk with AppleTalk networking.

Platforms Covered:

- A.   Linux
- B.I  NetBSD
- B.II Other BSDs
- C.   Generic

----------------------------------------------------------------

# A. Linux

Some Linux distributions ship with AppleTalk support out of the box
(e.g. Debian) others have the kernel module but with a blacklisting
in effect that has to be deactivated before you can use it (e.g. Fedora.)

Netatalk supplies two different types of AFP servers and both
can run at the same time. Classic AFP requires afpd and
atalkd. AFP over TCP only requires afpd.

Classic AFP on GNU/Linux requires that CONFIG_ATALK is compiled
into the kernel or as a kernel module. To check to see if the kernel
has support for AppleTalk:

```
$> dmesg | grep Apple
```

This just parses the boot messages for any line containing
'Apple'.

```
$> lsmod | grep appletalk
```

This checks if the appletalk kernel module is presently loaded.

If you don't find it, you may have to compile a kernel and turn on
Appletalk in Networking options -> Appletalk DDP. You have an option
to install as a module or directly into the kernel.

Some default distribution kernels have already compiled Appletalk DDP
as a module, you may have to edit your /etc/modules.conf to include:
"alias net-pf-5 appletalk ".

Note: check your distribution documentation about editing
/etc/modules.conf.

For more complete information about the Linux kernel see the
[Kernel-HOWTO](http://www.linuxdoc.org/HOWTO/Kernel-HOWTO.html).

A note for RedHat users: You may need to install the glibc-devel
package to be able to compile Netatalk correctly.

----------------------------------------------------------------

# B.I NetBSD

Kernel support for AppleTalk appeared in NetBSD 1.3 in April 1997.
See the [release notes](http://www.netbsd.org/changes/changes-1.3.html)

The source code for the kernel module is located in
sys/netatalk of the NetBSD source tree.

As of NetBSD 9.3, the netatalk kernel module is loaded by default,
and made available to the atalkd daemon when it starts up.

# B.II Other BSDs

Kernel support for AppleTalk appears in FreeBSD 2.2-current
dated after 12 September 1996, as well as OpenBSD 2.2,
or openbsd-current dated after Aug 1, 1997.

However, both distributions deprecated AppleTalk in the 2010s.
You can still run Netatalk as an AFP over TCP server on any
BSD-derived operating system.

----------------------------------------------------------------

# C. Generic

If you would like AppleTalk support on another operating system,
you will need either need a kernel module for your operating system,
or a userland AppleTalk stack.

Look at the Solaris STREAMS module if your operating system supports
that framework. This module used to distributed with Netatalk until
version 2.3 (sys/solaris).

Otherwise, look at the ddp code in NetBSD if your operating system
is BSDish in nature.

If your operating system looks different than these two cases,
you'll have to roll your own implementation.
