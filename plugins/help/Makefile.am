SUBDIRS = devhelp

include $(top_srcdir)/build/plugins.am

INCLUDES += \
    -I${top_srcdir}/plugins/help/devhelp

plugins_LTLIBRARIES = libgvt-help-plugin.la

libgvt_help_plugin_la_VALAFLAGS = \
    --vapidir=${top_srcdir}/plugins/help/devhelp \
    --pkg=libdevhelp-2.0

libgvt_help_plugin_la_SOURCES = \
    help-plugin.vala \
    devhelp.vala

libgvt_help_plugin_la_LIBADD = \
    $(GEANY_VALA_TOYS_LIBS) \
    devhelp/libdevhelp-2.la

VALAFILES = \
    $(filter %.vala,$(libgvt_help_plugin_la_SOURCES))

CLEANFILES += \
    libgvt_help_plugin_la_vala.stamp \
    $(VALAFILES:.vala=.c)
