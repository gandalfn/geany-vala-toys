include $(top_srcdir)/build/common.am

INCLUDES += \
	-DG_LOG_DOMAIN=\"Devhelp\" \
	-I${top_srcdir}/plugins/help

noinst_LTLIBRARIES = libdevhelp-2.la

dh_headers = \
	dh-assistant.h \
	dh-assistant-view.h \
	dh-base.h \
	dh-book-manager.h \
	dh-book.h \
	dh-book-tree.h \
	dh-error.h \
	dh-keyword-model.h \
	dh-link.h \
	dh-search.h \
	dh-window.h

dh-enum-types.h: dh-enum-types.h.template $(dh_headers)
	$(AM_V_GEN) (cd $(srcdir) && @GLIB_MKENUMS@ --template dh-enum-types.h.template $(dh_headers)) > $@

dh-enum-types.c: dh-enum-types.c.template $(dh_headers)
	$(AM_V_GEN) (cd $(srcdir) && @GLIB_MKENUMS@ --template dh-enum-types.c.template $(dh_headers)) > $@

BUILT_SOURCES = \
	dh-marshal.h \
	dh-marshal.c \
	dh-enum-types.h \
	dh-enum-types.c

EXTRA_DIST += \
	dh-marshal.list \
	dh-enum-types.c.template \
	dh-enum-types.h.template \
	libdevhelp-2.0.vapi \
	libdevhelp-2.0.deps

libdevhelp_2_la_SOURCES = \
	dh-assistant.c \
	dh-assistant-view.c \
	dh-base.c \
	dh-book.c \
	dh-book-manager.c \
	dh-book-tree.c \
	dh-enum-types.c \
	dh-enum-types.h \
	dh-error.c \
	dh-keyword-model.c \
	dh-link.c \
	dh-marshal.c \
	dh-marshal.h \
	dh-parser.c \
	dh-parser.h \
	dh-preferences.c \
	dh-preferences.h \
	dh-search.c \
	dh-util.c \
	dh-util.h \
	dh-window.c \
	eggfindbar.c \
	eggfindbar.h \
	ige-conf.c \
	ige-conf-gconf.c \
	ige-conf.h \
	ige-conf-private.h \
	$(dh_headers)

libdevhelp_2_la_LIBADD = \
	$(GEANY_VALA_TOYS_LIBS)

dh-marshal.h: dh-marshal.list
	$(AM_V_GEN) $(GLIB_GENMARSHAL) $< --header --prefix=_dh_marshal dh-marshal.list > $@

dh-marshal.c: dh-marshal.list
	$(AM_V_GEN) echo "#include \"dh-marshal.h\"" > $@ && \
	$(GLIB_GENMARSHAL) $< --body --prefix=_dh_marshal dh-marshal.list >> $@
