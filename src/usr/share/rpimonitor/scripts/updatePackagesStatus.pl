#!/usr/bin/perl
#
# Copyright 2013 - Xavier Berger - http://rpi-experiences.blogspot.fr/
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
use File::Which;
use strict;

# aptitude is no longer installed by default on Raspberry Pi OS Bookworm+.
# Use apt-get as the primary method, fall back to aptitude or checkupdates.
if ( which('apt-get') ) {
  open ( FILE, 'apt-get -s -o Debug::NoLocking=true upgrade 2>/dev/null | grep "^Inst " |')
    or die "Failed to run apt-get: $!\n";
} elsif ( which('aptitude') ) {
  open ( FILE, 'aptitude -F%p --disable-columns search ~U 2>/dev/null |') or die "$!\n";
} elsif ( which('checkupdates') ) {
  open ( FILE, 'checkupdates 2>/dev/null |' ) or die "$!\n";
} else {
  die "Error: no suitable package manager found (tried apt-get, aptitude, checkupdates)\n";
}

my $pkgnbr = 0;
my $pkglist = "";
while (<FILE>){
  chomp;
  # Strip the 'Inst ' prefix produced by apt-get -s
  s/^Inst\s+(\S+).*/$1/;
  $pkglist = "$pkglist $_";
  $pkgnbr++;
}
close (FILE);
open ( FILE, '> /var/lib/rpimonitor/updatestatus.txt' ) or die "$!\n";
  print FILE "$pkglist   $pkgnbr upgradable(s)\n";
close (FILE);
