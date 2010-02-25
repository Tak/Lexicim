lib_LTLIBRARIES=libLexicim.la
libLexicim_la_VALA =  \
	lexicim.vala \
	immodule.vala \
	gdkkeysyms.vapi

libLexicim_la_SOURCES= \
	$(libLexicim_la_VALA:.vala=.c)

libLexicim_la_LIBADD=@GTK_LIBS@
BUILT_SOURCES = ccode.stamp
AM_CFLAGS=@GTK_CFLAGS@ -fPIC -shared

.vala.c: ccode.stamp

ccode.stamp: $(libLexicim_la_VALA)
	$(VALAC) -C --library lexicim --pkg gee-1.0 --pkg gtk+-2.0 $(libLexicim_la_VALA)
	touch $@

CLEANFILES= ccode.stamp \
lexicim.c \
immodule.c \
Lexicim.h 

