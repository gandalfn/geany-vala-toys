/* -*- Mode: Vala; indent-tabs-mode: nil; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * variable.vala
 * Copyright (C) Nicolas Bruguier 2012 <gandalfn@club-internet.fr>
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

public class GVT.Variable : GLib.Object
{
    // properties
    private unowned Item m_Item;
    private string       m_Name;
    private string?      m_Value = "";

    // accessors
    public Item item {
        get {
            return m_Item;
        }
    }
    public string name {
        get {
            return m_Name;
        }
    }

    public string? val {
        get {
            return m_Value;
        }
        set {
            m_Value = value;
        }
    }

    // methods
    public Variable (Item inItem, string inName)
    {
        m_Item = inItem;
        m_Name = inName;
    }

    public int
    compare (Variable inOther)
    {
        return GLib.strcmp (m_Name, inOther.m_Name);
    }
}
