/* -*- Mode: Vala; indent-tabs-mode: nil; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * help-plugin.vala
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

GVT.Devhelp s_Manager = null;

public enum GVT.HelpKeyBinding
{
    SEARCH_SYMBOL,
    SEARCH_MAN_SYMBOL,

    COUNT
}

public void
plugin_kb_activate (uint inKbId)
{
    if (s_Manager != null)
    {
        switch (inKbId)
        {
            case GVT.HelpKeyBinding.SEARCH_SYMBOL:
                s_Manager.search_symbol ();
                break;

            case GVT.HelpKeyBinding.SEARCH_MAN_SYMBOL:
                s_Manager.search_man_symbol ();
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
    inInfo.set ("GVT Help Manager", "Geany Vala Toys Help Manager", "0.1.0", "Nicolas Bruguier");
}

public void
plugin_init (Geany.Data inData)
{
    s_Manager = new GVT.Devhelp ();
}

public void
plugin_cleanup ()
{
    s_Manager = null;
}
