include $(top_srcdir)/build/common.am

INCLUDES += \
    -DG_LOG_DOMAIN=\"Gdl\" \
    -I${top_srcdir}/plugins/dock

noinst_LTLIBRARIES = libgdl-1.la

BUILT_SOURCES = \
    libgdlmarshal.c \
    libgdlmarshal.h \
    libgdltypebuiltins.c \
    libgdltypebuiltins.h

CLEANFILES += \
    libgdltypebuiltins.c \
    libgdltypebuiltins.h \
    libgdlmarshal.c \
    libgdlmarshal.h

libgdl_headers = \
    gdl.h \
    gdl-tools.h \
    gdl-dock.h \
    gdl-dock-layout.h \
    gdl-dock-object.h \
    gdl-dock-master.h \
    gdl-dock-item.h \
    gdl-dock-item-grip.h \
    gdl-dock-bar.h \
    gdl-dock-placeholder.h

libgdl_1_la_SOURCES = \
    $(libgdl_headers) \
    gdl-i18n.h \
    gdl-i18n.c \
    gdl-dock-object.c \
    gdl-dock-master.c \
    gdl-dock.c \
    gdl-dock-layout.c \
    gdl-dock-item.c \
    gdl-dock-item-button-image.h \
    gdl-dock-item-button-image.c \
    gdl-dock-item-grip.h \
    gdl-dock-item-grip.c \
    gdl-dock-notebook.h \
    gdl-dock-notebook.c \
    gdl-dock-paned.c \
    gdl-dock-paned.h \
    gdl-dock-tablabel.c \
    gdl-dock-tablabel.h \
    gdl-dock-placeholder.c \
    gdl-dock-bar.c \
    gdl-switcher.c \
    gdl-switcher.h \
    libgdltypebuiltins.h \
    libgdltypebuiltins.c \
    libgdlmarshal.h \
    libgdlmarshal.c

libgdl_1_la_LIBADD = \
    $(GEANY_VALA_TOYS_LIBS)

EXTRA_DIST += \
    libgdlmarshal.list \
    gdl.vapi \
    gdl.deps

libgdltypebuiltins.c: $(libgdl_headers)
	$(AM_V_GEN) @GLIB_MKENUMS@ \
            --fhead "#include <glib-object.h>\n" \
            --fhead "#include \"libgdltypebuiltins.h\"\n\n" \
            --fprod "\n/* enumerations from \"@filename@\" */" \
            --vhead "static const G@Type@Value _@enum_name@_values[] = {" \
            --vprod "  { @VALUENAME@, \"@VALUENAME@\", \"@valuenick@\" }," \
            --vtail "  { 0, NULL, NULL }\n};\n\n" \
            --vtail "GType\n@enum_name@_get_type (void)\n{\n" \
            --vtail "  static GType type = 0;\n\n" \
            --vtail "  if (!type)\n" \
            --vtail "    type = g_@type@_register_static (\"@EnumName@\", _@enum_name@_values);\n\n" \
            --vtail "  return type;\n}\n\n" \
        $^ > xgen-gtbec \
    && cp xgen-gtbec $(@F) \
    && rm -f xgen-gtbec

libgdltypebuiltins.h: $(libgdl_headers)
	$(AM_V_GEN) @GLIB_MKENUMS@ \
            --fhead "#ifndef __LIBGDLTYPEBUILTINS_H__\n" \
            --fhead "#define __LIBGDLTYPEBUILTINS_H__ 1\n\n" \
            --fhead "#include <gdl/gdl.h>\n\n" \
            --fhead "G_BEGIN_DECLS\n\n" \
            --ftail "G_END_DECLS\n\n" \
            --ftail "#endif /* __LIBGDLTYPEBUILTINS_H__ */\n" \
            --fprod "\n/* --- @filename@ --- */" \
            --eprod "#define GDL_TYPE_@ENUMSHORT@ @enum_name@_get_type()\n" \
            --eprod "GType @enum_name@_get_type (void);\n" \
        $^ > xgen-gth \
    && cp xgen-gth $(@F) \
    && rm -f xgen-gth

libgdlmarshal.h: libgdlmarshal.list
	$(AM_V_GEN) @GLIB_GENMARSHAL@ \
        --prefix=gdl_marshal $(srcdir)/libgdlmarshal.list --header > xgen-gmc \
    && cp xgen-gmc $(@F) \
    && rm -f xgen-gmc

libgdlmarshal.c: libgdlmarshal.h
	$(AM_V_GEN) echo "#include \"libgdlmarshal.h\"" > xgen-gmc \
    && @GLIB_GENMARSHAL@ \
        --prefix=gdl_marshal $(srcdir)/libgdlmarshal.list --body >> xgen-gmc \
    && cp xgen-gmc $(@F) \
    && rm -f xgen-gmc

