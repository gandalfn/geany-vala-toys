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

public class GVT.Group : Node
{
    // accessors
    public override string path {
        owned get {
            return parent.path + "/" + name;
        }
    }

    public unowned Project? project {
        get {
            unowned Node? p = null;
            if (this is Project) return (Project?)this;
            for (p = (Node)parent; p != null && !(p is Project); p = (Node)p.parent);
            return (Project?)p;
        }
    }

    public GLib.FileMonitor monitor { get; set; default = null; }

    public signal void updated ();

    // methods
    public Group (Node? inParent, string inName)
    {
        GLib.Object (name: inName, parent: inParent);

        Variable srcdir = new Variable (this, "srcdir");
        srcdir.val = path;
        variables.insert (srcdir);

        Variable builddir = new Variable (this, "builddir");
        builddir.val = path;
        variables.insert (builddir);

        Variable topsrcdir = new Variable (this, "top_srcdir");
        Variable topbuilddir = new Variable (this, "top_builddir");
        if (project != null)
        {
            topsrcdir.val = project.path;
            topbuilddir.val = project.path;
        }
        else
        {
            topsrcdir.val = path;
            topbuilddir.val = path;
        }

        variables.insert (topsrcdir);
        variables.insert (topbuilddir);
    }

    ~Group ()
    {
        if (monitor != null) monitor.cancel ();
    }

    public void
    clear_variables ()
    {
        variables.clear ();

        Variable srcdir = new Variable (this, "srcdir");
        srcdir.val = path;
        variables.insert (srcdir);

        Variable builddir = new Variable (this, "builddir");
        builddir.val = path;
        variables.insert (builddir);

        Variable topsrcdir = new Variable (this, "top_srcdir");
        Variable topbuilddir = new Variable (this, "top_builddir");
        if (project != null)
        {
            topsrcdir.val = project.path;
            topbuilddir.val = project.path;
        }
        else
        {
            topsrcdir.val = path;
            topbuilddir.val = path;
        }

        variables.insert (topsrcdir);
        variables.insert (topbuilddir);
    }
}
