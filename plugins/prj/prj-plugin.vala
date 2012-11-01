/* -*- Mode: Vala; indent-tabs-mode: nil; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * prj-plugin.vala
 * Copyright (C) Nicolas Bruguier 2010-2012 <gandalfn@club-internet.fr>
 *
 * geany-vala-toys is free software: you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * geany-vala-toys is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

GVT.Manager s_Manager = null;

public enum GVT.KeyBinding
{
    FIND,
    CONFIGURE,
    BUILD_ALL,
    BUILD,
    CLEAN,
    DIFF,

    COUNT
}

public void
plugin_kb_activate (uint inKbId)
{
    if (s_Manager != null)
    {
        switch (inKbId)
        {
            case GVT.KeyBinding.FIND:
                s_Manager.kb_find ();
                break;

            case GVT.KeyBinding.CONFIGURE:
                s_Manager.kb_configure ();
                break;

            case GVT.KeyBinding.BUILD_ALL:
                s_Manager.kb_build_all ();
                break;

            case GVT.KeyBinding.BUILD:
                s_Manager.kb_build ();
                break;

            case GVT.KeyBinding.CLEAN:
                s_Manager.kb_clean ();
                break;

            case GVT.KeyBinding.DIFF:
                s_Manager.kb_diff ();
                break;
        }
    }
}

public int
plugin_version_check (int inABIVersion)
{
    return Geany.Plugin.version_check (inABIVersion, 185);
}

public void
plugin_set_info (Geany.Plugin.Info inInfo)
{
    inInfo.set ("GVT Project Manager", "Geany Vala Toys Project Manager", "0.1.0", "Nicolas Bruguier");
}

public void
plugin_init (Geany.Data inData)
{
    s_Manager = new GVT.Manager ();
    message ("manager: %u", s_Manager.ref_count);
}

public void
plugin_cleanup ()
{
    s_Manager = null;
}

public Gtk.Widget?
plugin_configure (Gtk.Dialog inDialog)
{
    if (s_Manager != null)
    {
        return s_Manager.configure (inDialog);
    }

    return null;
}
