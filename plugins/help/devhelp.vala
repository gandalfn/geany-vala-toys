/* -*- Mode: Vala; indent-tabs-mode: nil; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * help-manager.vala
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

public Geany.Plugin    geany_plugin;
public Geany.Data      geany_data;
public Geany.Functions geany_functions;

const string MAN2HTML = "/usr/lib/cgi-bin/man/man2html";

public class GVT.Devhelp : GLib.Object
{
    // types
    private class View : Gtk.Frame
    {
        // properties
        private WebKit.WebView m_DHView;
        private Gtk.ToolButton m_BackButton;
        private Gtk.ToolButton m_ForwardButton;

        // accessors
        public int page_id { get; set; }

        // methods
        public View ()
        {
            set_shadow_type(Gtk.ShadowType.NONE);

            m_DHView = new WebKit.WebView();
            m_DHView.show ();

            Gtk.VBox vbox = new Gtk.VBox (false, 0);
            vbox.show ();
            add (vbox);

            Gtk.Toolbar toolbar = new Gtk.Toolbar ();
            toolbar.show ();
            vbox.pack_start (toolbar, false, false);

            m_BackButton = new Gtk.ToolButton.from_stock (Gtk.Stock.GO_BACK);
            m_BackButton.show ();
            m_BackButton.clicked.connect (() => {
                m_DHView.go_back ();
            });
            toolbar.insert (m_BackButton, -1);

            m_ForwardButton = new Gtk.ToolButton.from_stock (Gtk.Stock.GO_FORWARD);
            m_ForwardButton.show ();
            m_BackButton.clicked.connect (() => {
                m_DHView.go_forward ();
            });
            toolbar.insert (m_ForwardButton, -1);

            Gtk.SeparatorToolItem separator = new Gtk.SeparatorToolItem ();
            separator.show ();
            toolbar.insert (separator, -1);

            Gtk.ToolButton zoom_in = new Gtk.ToolButton.from_stock (Gtk.Stock.ZOOM_IN);
            zoom_in.show ();
            zoom_in.clicked.connect (() => {
                m_DHView.zoom_in ();
            });
            toolbar.insert (zoom_in, -1);

            Gtk.ToolButton zoom_out = new Gtk.ToolButton.from_stock (Gtk.Stock.ZOOM_OUT);
            zoom_out.show ();
            zoom_out.clicked.connect (() => {
                m_DHView.zoom_out ();
            });
            toolbar.insert (zoom_out, -1);

            Gtk.ScrolledWindow swview = new Gtk.ScrolledWindow(null, null);
            swview.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
            swview.show ();

            swview.add (m_DHView);
            vbox.pack_start (swview);

            m_DHView.document_load_finished.connect (() => {
                update_history_buttons ();
            });
            m_DHView.notify["uri"].connect (() => {
                update_history_buttons ();
            });
            m_DHView.notify["load-status"].connect (() => {
                update_history_buttons ();
            });

            m_DHView.open("about:blank");
        }

        private void
        update_history_buttons ()
        {
            m_BackButton.set_sensitive (m_DHView.can_go_back ());
            m_ForwardButton.set_sensitive (m_DHView.can_go_forward ());
        }

        private string?
        get_man_html_page (string[] inArgs)
        {
            string cmd = MAN2HTML;

            foreach (string arg in inArgs)
            {
                cmd += " " + arg;
            }
            try
            {
                string html;
                int ret;
                debug ("launch %s", cmd);
                GLib.Process.spawn_command_line_sync (cmd, out html, null, out ret);
                if (ret == 0)
                {
                    GLib.FileUtils.set_contents ("/tmp/gvt-help-plugin.html", html);
                    return "/tmp/gvt-help-plugin.html";
                }
            }
            catch (GLib.Error err)
            {
                warning ("%s", err.message);
            }

            return null;
        }

        public void
        open (string inUri)
        {
            debug ("open %s", inUri);
            int current = geany_data.main_widgets.message_window_notebook.get_current_page ();
            if (current != page_id)
                geany_data.main_widgets.message_window_notebook.set_current_page (page_id);

            if (inUri.has_prefix ("/cgi-bin/man/man2html?"))
            {
                string[] args = inUri.substring ("/cgi-bin/man/man2html?".length).split("+");
                string? page = get_man_html_page (args);
                if (page != null)
                    m_DHView.open (page);
            }
            else
            {
                m_DHView.open (inUri);
            }
        }

        public void
        open_man_page (string inTag)
        {
            string[] args = {};
            args += inTag;
            string? page = get_man_html_page (args);

            if (page != null)
            {
                open (page);
            }
        }
    }

    class Sidebar : Gtk.Notebook
    {
        // properties
        private Dh.Base     m_DHBase;
        private Dh.BookTree m_DHBookTree;
        private Dh.Search   m_DHSearch;
        private View        m_View;

        // accessors
        public int page_id { get; set; }

        // methods
        public Sidebar (View inView)
        {
            m_DHBase = new Dh.Base();

            m_View = inView;

            Dh.BookManager book_manager = m_DHBase.get_book_manager();

            m_DHBookTree = new Dh.BookTree(book_manager);
            m_DHBookTree.show ();
            m_DHSearch = new Dh.Search(book_manager);
            m_DHSearch.show ();

            Gtk.ScrolledWindow swbooktree = new Gtk.ScrolledWindow(null, null);
            swbooktree.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            swbooktree.border_width = 5;
            swbooktree.show ();
            swbooktree.add(m_DHBookTree);

            Gtk.Frame frasearch = new Gtk.Frame(null);
            frasearch.set_shadow_type(Gtk.ShadowType.NONE);
            frasearch.border_width = 5;
            frasearch.show ();
            frasearch.add(m_DHSearch);

            append_page(swbooktree, new Gtk.Label("Contents"));
            append_page(frasearch, new Gtk.Label("Search"));

            m_DHBookTree.link_selected.connect(on_link_selected);
            m_DHSearch.link_selected.connect(on_link_selected);
        }

        private void
        on_link_selected (void* inLink)
        {
            Dh.Link link = (Dh.Link)inLink;
            string uri = link.get_uri();
            m_View.open (uri);
        }

        public void
        search (string inTag)
        {
            debug ("search: %s", inTag);
            int current = geany_data.main_widgets.sidebar_notebook.get_current_page ();
            if (current != page_id)
                geany_data.main_widgets.sidebar_notebook.set_current_page (page_id);
            set_current_page (1);

            m_DHSearch.set_search_string (inTag, null);
        }
    }

    // properties
    private View    m_View;
    private Sidebar m_Sidebar;

    // static methods
    static construct
    {
        geany_plugin.module_make_resident ();
    }

    // methods
    public Devhelp ()
    {
        // Create help tabs
        m_View = new View ();
        m_View.show ();
        m_Sidebar = new Sidebar (m_View);
        m_Sidebar.show ();

        // Add sidebar
        m_Sidebar.page_id = geany_data.main_widgets.sidebar_notebook.append_page (m_Sidebar,
                                                                                  new Gtk.Label ("GVT Help"));

        // Add view
        m_View.page_id = geany_data.main_widgets.message_window_notebook.append_page (m_View,
                                                                                      new Gtk.Label ("GVT Documentation"));

        unowned Geany.KeyGroup key_group = geany_plugin.set_key_group ("GVT Help Manager", GVT.HelpKeyBinding.COUNT);
        Geany.Keybindings.set_item (key_group, GVT.HelpKeyBinding.SEARCH_SYMBOL, plugin_kb_activate, 0, 0,
                                    "gvt_help_search_symbol", "Find symbol in help", null);
        Geany.Keybindings.set_item (key_group, GVT.HelpKeyBinding.SEARCH_MAN_SYMBOL, plugin_kb_activate, 0, 0,
                                    "gvt_help_search_man_symbol", "Find symbol in man pages", null);
    }

    public string?
    get_current_word ()
    {
        unowned Geany.Document? document = Geany.Document.get_current ();

        if (document == null || document.editor == null || document.editor.scintilla == null)
            return null;

        if (document.editor.scintilla.has_selection ())
        {
            string val = document.editor.scintilla.get_selection_contents ();
            val.canon (Geany.Editor.WORD_CHARS, ' ');
            return val.strip ();
        }

        int pos = document.editor.scintilla.get_current_position ();
        string val = document.editor.get_word_at_pos (pos);
        if (val != null && val.length > 0)
        {
            val.canon (Geany.Editor.WORD_CHARS, ' ');
            return val.strip ();
        }

        return null;
    }

    public void
    search_symbol ()
    {
        string? tag = get_current_word ();
        if (tag != null)
        {
            m_Sidebar.search (tag);
        }
    }

    public void
    search_man_symbol ()
    {
        string? tag = get_current_word ();
        if (tag != null)
        {
            m_View.open_man_page (tag);
        }
    }
}
