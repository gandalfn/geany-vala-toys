include $(top_srcdir)/build/plugins.am

plugins_LTLIBRARIES = libgvt-project-plugin.la

libgvt_project_plugin_la_VALAFLAGS = \
    --header=gvt-plugin.h

libgvt_project_plugin_la_SOURCES = \
    prj-plugin.vala \
    set.vala \
    variable.vala \
    command.vala \
    backend.vala \
    item.vala \
    node.vala \
    manager.vala \
    autotools.vala \
    project.vala \
    group.vala \
    target.vala \
    source.vala \
    data.vala

libgvt_project_plugin_la_LIBADD = \
    $(GEANY_VALA_TOYS_LIBS)

VALAFILES = \
    $(filter %.vala,$(libgvt_project_plugin_la_SOURCES))

CLEANFILES += \
    libgvt_project_plugin_la_vala.stamp \
    $(VALAFILES:.vala=.c)
