/* -*- Mode: Vala; indent-tabs-mode: nil; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * node.vala
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

public abstract class GVT.Node : Item
{
    // properties
    private Set<Item> m_Childs;

    // accessors
    public uint length {
        get {
            return m_Childs.length;
        }
    }

    // methods
    construct
    {
        m_Childs = new Set<Item> ();
        m_Childs.compare_func = Item.compare;
    }

    private unowned Item?
    find_path_array (string[] inPath, int inPos)
        requires (inPos < inPath.length)
    {
        unowned Item? item = get (inPath[inPos]);

        if (item == null && inPos < inPath.length - 1)
        {
            string f = inPath[inPos];
            for (int cpt = inPos + 1; cpt < inPath.length; cpt++)
            {
                f += "/" + inPath[cpt];
            }
            return find (f);
        }

        if (item != null && inPos < inPath.length - 1)
        {
            if (item is Node)
            {
                item = ((Node)item).find_path_array (inPath, inPos + 1);
            }
            else
            {
                item = null;
            }
        }
        else if (item == null && inPos == inPath.length - 1)
        {
            item = find (inPath[inPos]);
        }

        return item;
    }

    public Set.Iterator<Item>
    iterator ()
    {
        return m_Childs.iterator ();
    }

    public bool
    contains (string inName)
    {
        unowned Item? item = m_Childs.search<string> (inName, (v, k) => {
            return GLib.strcmp (v.name, k);
        });
        return item != null;
    }

    public new unowned Item?
    @get (string inName)
    {
        return m_Childs.search<string> (inName, (v, k) => {
            return GLib.strcmp (v.name, k);
        });
    }

    public unowned Item?
    find (string inName)
    {
        unowned Item? ret = get (inName);

        if (ret == null)
        {
            foreach (unowned Item? item in this)
            {
                if (item is Node)
                {
                    ret = ((Node)item).find (inName);
                    if (ret != null) break;
                }
            }
        }

        return ret;
    }

    public unowned Item?
    find_path (string inPath)
    {
        string[] path = inPath.split ("/");
        return find_path_array (path, 0);
    }

    public bool
    add (Item inChild)
    {
        if (!(inChild.name in this))
        {
            m_Childs.insert (inChild);
            return true;
        }

        return false;
    }

    public bool
    remove (string inName)
    {
        unowned Item? item = m_Childs.search<string> (inName, (v, k) => {
            return GLib.strcmp (v.name, k);
        });

        if (item != null)
        {
            m_Childs.remove (item);
            return true;
        }

        return false;
    }

    public void
    clear ()
    {
        m_Childs.clear ();
    }
}
