AC_INIT([geany-vala-toys],[0.1.0],[gandalfn@club-internet.fr],[geany-vala-toys])
AC_CONFIG_SRCDIR(Makefile.am)

AC_CONFIG_AUX_DIR([build])
AC_CONFIG_MACRO_DIR([build])
AC_CONFIG_HEADERS(build/config.h)

AM_INIT_AUTOMAKE([dist-bzip2])
m4_ifdef([AM_SILENT_RULES],[AM_SILENT_RULES([yes])])
AM_MAINTAINER_MODE

dnl ****************************************************************************
dnl Check for build
dnl ****************************************************************************
AC_LANG([C])
AM_PROG_CC_C_O
AC_SEARCH_LIBS([strerror],[cposix])

dnl ****************************************************************************
dnl Check for libtool
dnl ****************************************************************************
LT_PREREQ([2.2])
LT_INIT([disable-static])

dnl ****************************************************************************
dnl Packages version required
dnl ****************************************************************************
GTK_REQUIRED=2.24.0
LIBXML2_REQUIRED=2.7.8
VALA_REQUIRED=0.18.0
WEBKIT_REQUIRED=1.8.1
LIBWNCK_REQUIRED=2.30.0
GEANY_REQUIRED=1.22
GCONF2_REQUIRED=2.30.0

dnl ****************************************************************************
dnl Check for vala
dnl ****************************************************************************
AM_PROG_VALAC($VALA_REQUIRED)

dnl ****************************************************************************
dnl Internationalization
dnl ****************************************************************************
AH_TEMPLATE([GETTEXT_PACKAGE], [Package name for gettext])
GETTEXT_PACKAGE=xsplashaa
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE, "$GETTEXT_PACKAGE")
AC_SUBST(GETTEXT_PACKAGE)
AM_GLIB_GNU_GETTEXT
IT_PROG_INTLTOOL([0.35.0])

dnl ****************************************************************************
dnl Check for packages
dnl ****************************************************************************
PKG_CHECK_MODULES(GEANY_VALA_TOYS, [gtk+-2.0 >= $GTK_REQUIRED
                                    webkit-1.0 >= $WEBKIT_REQUIRED
                                    libwnck-1.0 >= $LIBWNCK_REQUIRED
                                    libxml-2.0 >= $LIBXML2_REQUIRED
                                    gconf-2.0 >= $GCONF2_REQUIRED
                                    geany >= $GEANY_REQUIRED])
AC_SUBST(GEANY_VALA_TOYS_CFLAGS)
AC_SUBST(GEANY_VALA_TOYS_LIBS)

dnl ****************************************************************************
dnl Check for glib tools
dnl ****************************************************************************
GLIB_GENMARSHAL="`$PKG_CONFIG --variable=glib_genmarshal glib-2.0`"
AC_SUBST(GLIB_GENMARSHAL)
GLIB_MKENUMS="`$PKG_CONFIG --variable=glib_mkenums glib-2.0`"
AC_SUBST(GLIB_MKENUMS)

AC_CONFIG_FILES([
Makefile
plugins/Makefile
plugins/dock/Makefile
plugins/dock/gdl/Makefile
plugins/help/Makefile
plugins/help/devhelp/Makefile
plugins/prj/Makefile
po/Makefile.in
])

AC_OUTPUT
