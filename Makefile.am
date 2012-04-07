SUBDIRS = \
    plugins \
    po

geanyvalatoysdocdir = ${prefix}/doc/geany-vala-toys
geanyvalatoysdoc_DATA = \
    ChangeLog \
    README \
    COPYING \
    AUTHORS \
    INSTALL \
    NEWS

EXTRA_DIST = \
    $(xsplashaadoc_DATA) \
    intltool-extract.in \
    intltool-merge.in \
    intltool-update.in \
    vapi/geany.deps \
    vapi/geany.vapi \
    build/common.am \
    build/plugins.am

DISTCLEANFILES = \
    intltool-extract \
    intltool-merge \
    intltool-update \
    po/.intltool-merge-cache
