#!/bin/sh
# Run this to generate all the initial makefiles, etc.

srcdir=`dirname $0`
test -z "$srcdir" && srcdir=.

PKG_NAME="lexicim"

#. gnome-autogen.sh
libtoolize
aclocal
automake --gnu --add-missing
autoconf
./configure "$@"
