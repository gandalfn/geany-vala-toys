/* -*- Mode: Vala; indent-tabs-mode: nil; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * item.vala
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

public abstract class GVT.Item : GLib.Object
{
    // properties
    private Set<Variable> m_Variables;
    // accessors
    public string name             { get; set; }
    public unowned Item? parent    { get; set; }
    public Set<Variable> variables {
        get {
            return m_Variables;
        }
    }

    public abstract string path { owned get; }

    // methods
    construct
    {
        m_Variables = new Set<Variable> ();
        m_Variables.compare_func = Variable.compare;
    }

    public int
    compare (Item inOther)
    {
        return GLib.strcmp (name, inOther.name);
    }
}
