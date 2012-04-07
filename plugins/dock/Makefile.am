SUBDIRS = gdl

include $(top_srcdir)/build/plugins.am

INCLUDES += \
    -I${top_srcdir}/plugins/dock/gdl

plugins_LTLIBRARIES = libgvt-dock-plugin.la

libgvt_dock_plugin_la_VALAFLAGS = \
    --vapidir=${top_srcdir}/plugins/dock/gdl \
    --pkg=gdl

libgvt_dock_plugin_la_SOURCES = \
    dock-plugin.vala

libgvt_dock_plugin_la_LIBADD = \
    $(GEANY_VALA_TOYS_LIBS) \
    gdl/libgdl-1.la

VALAFILES = \
    $(filter %.vala,$(libgvt_dock_plugin_la_SOURCES))

CLEANFILES += \
    libgvt_dock_plugin_la_vala.stamp \
    $(VALAFILES:.vala=.c)
