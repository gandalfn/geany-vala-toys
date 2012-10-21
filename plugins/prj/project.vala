/* -*- Mode: Vala; indent-tabs-mode: nil; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * group.vala
 * Copyright (C) Nicolas Bruguier 2010-2011 <gandalfn@club-internet.fr>
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

public class GVT.Project : Group
{
    // properties
    private string      m_Version;
    private string      m_Root;
    private Set<string> m_Patterns;

    // accessors
    public string version {
        get {
            return m_Version;
        }
        set {
            m_Version = value;
        }
    }

    public override string path {
        owned get {
            return m_Root;
        }
    }

    public string[] patterns {
        owned get {
            string[] ret = {};
            foreach (string p in m_Patterns)
            {
                ret += p;
            }
            ret += null;
            return ret;
        }
    }

    // methods
    public Project (string inName, string? inVersion, string inRoot)
    {
        GLib.Object (name: inName, parent: null);
        m_Version = inVersion;
        m_Root = inRoot;
        m_Patterns = new Set<string> ();
        m_Patterns.compare_func = (a, b) => {
            return GLib.strcmp (a, b);
        };

        Variable srcdir = new Variable (this, "srcdir");
        srcdir.val = path;
        variables.insert (srcdir);

        Variable top_srcdir = new Variable (this, "top_srcdir");
        top_srcdir.val = path;
        variables.insert (top_srcdir);

        Variable builddir = new Variable (this, "builddir");
        builddir.val = path;
        variables.insert (builddir);

        Variable top_builddir = new Variable (this, "top_builddir");
        top_builddir.val = path;
        variables.insert (top_builddir);
    }

    public void
    add_patterns (string[] inPatterns)
    {
        foreach (string p in inPatterns)
        {
            m_Patterns.insert (p);
        }
    }
}
