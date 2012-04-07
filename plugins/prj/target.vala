/* -*- Mode: Vala; indent-tabs-mode: nil; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * target.vala
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

// types
public enum GVT.TargetType
{
    UNKNOWN,
    EXECUTABLE,
    LIBRARY
}

public class GVT.Target : Node
{
    // accessors
    public override string path {
        owned get {
            return parent.path;
        }
    }

    public unowned Project? project {
        get {
            unowned Node? p = null;
            for (p = (Node)parent; p != null && !(p is Project); p = (Node)p.parent);
            return (Project?)p;
        }
    }

    public string filename {
        owned get {
            return path + "/" + name;
        }
    }

    public TargetType target_type { get; construct; default = TargetType.UNKNOWN; }

    // methods
    public Target (Group inGroup, TargetType inType, string inName)
    {
        GLib.Object (name: inName, parent: inGroup, target_type: inType);
    }
}
