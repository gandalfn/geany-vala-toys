/* -*- Mode: Vala; indent-tabs-mode: nil; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * dock-plugin.vala
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

public Geany.Plugin    geany_plugin;
public Geany.Data      geany_data;
public Geany.Functions geany_functions;

static uint s_IdCreate = 0;
static GVT.DockPlugin s_Plugin = null;

public class GVT.DockPlugin : GLib.Object
{
    // types
    private enum DockBarPosition
    {
        LEFT,
        RIGHT,
        TOP,
        BOTTOM;

        public string
        to_string ()
        {
            switch (this)
            {
                case LEFT:
                    return "left";
                case RIGHT:
                    return "right";
                case TOP:
                    return "top";
                case BOTTOM:
                    return "botton";
            }

            return "left";
        }

        public static DockBarPosition
        from_string (string inStr)
        {
            switch (inStr)
            {
                case "left":
                    return LEFT;
                case "right":
                    return RIGHT;
                case "top":
                    return TOP;
                case "bottom":
                    return BOTTOM;
            }

            return LEFT;
        }
    }

    private class Prefs : GLib.Object
    {
        // properties
        private string m_Filename = geany_data.app.config_dir + "/plugins/gvt-dock/gvt-dock.conf";
        private GLib.KeyFile m_Config;

        // accessors
        public DockBarPosition bar_position {
            get {
                return DockBarPosition.from_string (Geany.Utils.get_setting_string (m_Config, "dock", "bar_position", "left"));
            }
            set {
                m_Config.set_string ("dock", "bar_position", value.to_string ());
            }
        }

        public Gdl.DockBarStyle bar_style {
            get {
                return Gdl.DockBarStyle.from_string (Geany.Utils.get_setting_string (m_Config, "dock", "bar_style", "both"));
            }
            set {
                m_Config.set_string ("dock", "bar_style", value.to_string ());
            }
        }

        public Gdl.SwitcherStyle switcher_style {
            get {
                return Gdl.SwitcherStyle.from_string (Geany.Utils.get_setting_string (m_Config, "dock", "switcher_style", "both"));
            }
            set {
                m_Config.set_string ("dock", "switcher_style", value.to_string ());
            }
        }

        public Prefs ()
        {
            bool loaded = false;

            m_Config = new GLib.KeyFile ();

            if (GLib.FileUtils.test (m_Filename, GLib.FileTest.EXISTS))
            {
                try
                {
                    m_Config.load_from_file (m_Filename, GLib.KeyFileFlags.KEEP_COMMENTS);
                    loaded = true;
                }
                catch (GLib.Error err)
                {
                }
            }

            if (!loaded)
            {
                bar_position = DockBarPosition.LEFT;
                bar_style = Gdl.DockBarStyle.BOTH;
                switcher_style = Gdl.SwitcherStyle.BOTH;
                clear_iconified ();
            }
        }

        ~Prefs ()
        {
            save ();
        }

        public void
        save ()
        {
            string path_config = GLib.Path.get_dirname (m_Filename);
            if (!GLib.FileUtils.test (path_config, GLib.FileTest.EXISTS))
            {
                GLib.DirUtils.create_with_parents(path_config, 0755);
            }

            Geany.Utils.write_file (m_Filename, m_Config.to_data ());
        }

        public bool
        is_iconified (string inName)
        {
            string iconifieds = Geany.Utils.get_setting_string (m_Config, "dock", "iconified", "");

            if (iconifieds != "")
            {
                string[] split = iconifieds.split (",");

                foreach (unowned string item in split)
                {
                    if (item == inName) return true;
                }
            }

            return false;
        }

        public Gdl.DockPlacement
        get_placement (string inName)
        {
            return Gdl.DockPlacement.from_string (Geany.Utils.get_setting_string (m_Config, inName, "placement", "none"));
        }

        public void
        add_iconified (Gdl.DockItem inItem)
        {
            if (!is_iconified (inItem.long_name))
            {
                string iconifieds = Geany.Utils.get_setting_string (m_Config, "dock", "iconified", "");
                if (iconifieds == "")
                    iconifieds = inItem.long_name;
                else
                    iconifieds += "," + inItem.long_name;

                m_Config.set_string ("dock", "iconified", iconifieds);

                Gdl.DockPlacement placement = Gdl.DockPlacement.LEFT;
                m_Config.set_string (inItem.long_name, "placement", placement.to_string ());
            }
        }

        public void
        clear_iconified ()
        {
            m_Config.set_string ("dock", "iconified", "");
        }
    }

    // properties
    private Prefs                   m_Settings;
    private Gtk.Widget              m_OriginalMain;
    private Gtk.Box                 m_Box;
    private Gdl.Dock                m_Dock;
    private Gdl.DockBar             m_DockBar;
    private Gdl.DockLayout          m_Layout;
    private Gdl.DockItem            m_DocumentDock;
    private GLib.List<Gdl.DockItem> m_SideItems = new GLib.List<Gdl.DockItem> ();
    private GLib.List<Gdl.DockItem> m_MessageItems = new GLib.List<Gdl.DockItem> ();
    private Gtk.MenuItem            m_DockMenu;
    private Gtk.Menu                m_Menu;

    // methods
    public DockPlugin ()
    {
        // Get settings
        m_Settings = new Prefs ();

        // Create main box
        if (m_Settings.bar_position == DockBarPosition.LEFT || m_Settings.bar_position == DockBarPosition.RIGHT)
            m_Box = new Gtk.HBox (false, 5);
        else
            m_Box = new Gtk.VBox (false, 5);
        m_Box.show ();

        // Create dock view
        m_Dock = new Gdl.Dock ();
        m_Dock.show ();

        // Creat dock bar
        m_DockBar = new Gdl.DockBar (m_Dock);
        if (m_Settings.bar_position == DockBarPosition.LEFT || m_Settings.bar_position == DockBarPosition.RIGHT)
            m_DockBar.set_orientation (Gtk.Orientation.VERTICAL);
        else
            m_DockBar.set_orientation (Gtk.Orientation.HORIZONTAL);

        m_DockBar.set_style (m_Settings.bar_style);
        m_DockBar.show ();
        if (m_Settings.bar_position == DockBarPosition.LEFT || m_Settings.bar_position == DockBarPosition.TOP)
        {
            m_Box.pack_start (m_DockBar, false, false);
            m_Box.pack_start (m_Dock);
        }
        else
        {
            m_Box.pack_start (m_Dock);
            m_Box.pack_end (m_DockBar, false, false);
        }

        // Create view menu
        m_DockMenu = new Gtk.MenuItem.with_label ("GVT Dock");
        m_DockMenu.show ();
        geany_data.main_widgets.tools_menu.add (m_DockMenu);

        m_Menu = new Gtk.Menu ();
        m_Menu.show ();
        m_DockMenu.set_submenu (m_Menu);

        // Hide original main pane
        m_OriginalMain = Geany.Ui.lookup_widget (geany_data.main_widgets.window, "vpaned1");
        m_OriginalMain.hide ();

        // Put dock in geany window
        var main = Geany.Ui.lookup_widget (geany_data.main_widgets.window, "vbox1") as Gtk.Box;
        main.add (m_Box);
        main.reorder_child (m_Box, -1);

        // Put status bar to bottom
        var statusbar = Geany.Ui.lookup_widget (geany_data.main_widgets.window, "hbox1") as Gtk.Box;
        main.reorder_child (statusbar, -1);

        // Create dock documents
        plug_documents_view ();

        // Create dock of message items
        plug_message_view ();

        // Create dock of side items
        plug_side_view ();

        // Load layout
        string layout_filename = geany_data.app.config_dir + "/plugins/gvt-dock/layout.xml";
        m_Layout = new Gdl.DockLayout (m_Dock);
        m_Layout.master.switcher_style = m_Settings.switcher_style;

        if (GLib.FileUtils.test (layout_filename, GLib.FileTest.EXISTS))
        {
            m_Layout.load_from_file (layout_filename);
            m_Layout.load_layout (null);
            foreach (unowned Gdl.DockItem item in m_SideItems)
            {
                if (m_Settings.is_iconified (item.long_name))
                {
                    item.dock_to (m_DocumentDock, m_Settings.get_placement (item.long_name), -1);
                    item.iconify_item ();
                }
            }
            foreach (unowned Gdl.DockItem item in m_MessageItems)
            {
                if (m_Settings.is_iconified (item.long_name))
                {
                    item.dock_to (m_DocumentDock, m_Settings.get_placement (item.long_name), -1);
                    item.iconify_item ();
                }
            }
            update_menus ();
        }
        m_Layout.notify["dirty"].connect (() => {
            if (m_Layout.is_dirty ())
            {
                update_menus ();
                save_layout ();
            }
        });

        geany_plugin.signal_connect (null, "document-open", true,
                                     (GLib.Callback) on_document_activate, this);
        geany_plugin.signal_connect (null, "document-activate", true,
                                     (GLib.Callback) on_document_activate, this);
    }

    [CCode (instance_pos = -1)]
    private void
    on_document_activate (GLib.Object inObject, Geany.Document inDocument)
    {
        if (m_DocumentDock.parent is Gtk.Notebook)
        {
            unowned Gtk.Notebook notebook = (Gtk.Notebook)m_DocumentDock.parent;
            int num = notebook.page_num (m_DocumentDock);
            if (num != notebook.get_current_page ())
            {
                debug("activate editor");
                notebook.set_current_page (num);
            }
        }
    }

    private void
    update_menus ()
    {
        m_Settings.clear_iconified ();
        foreach (unowned Gdl.DockItem item in m_SideItems)
        {
            unowned Gtk.CheckMenuItem? menu = item.get_data ("dock-menu");
            if (menu != null)
            {
                menu.active = item.is_attached ();
            }
            if (item.is_iconified ())
            {
                m_Settings.add_iconified (item);
            }
        }
        foreach (unowned Gdl.DockItem item in m_MessageItems)
        {
            unowned Gtk.CheckMenuItem? menu = item.get_data ("dock-menu");
            if (menu != null)
            {
                menu.active = item.is_attached ();
            }
            if (item.is_iconified ())
            {
                m_Settings.add_iconified (item);
            }
        }
    }

    private void
    add_to_display_menu (string inName, Gdl.DockItem inItem)
    {
        var menu = new Gtk.CheckMenuItem.with_label (inName);
        menu.show ();
        m_Menu.add (menu);
        menu.active = inItem.is_attached ();
        inItem.set_data ("dock-menu", menu);
        menu.toggled.connect (() => {
            if (menu.active && !inItem.is_attached ())
                inItem.show_item ();
            else if (!menu.active && inItem.is_attached ())
                inItem.hide_item ();
        });
    }

    private void
    plug_documents_view ()
    {
        // Create document dock item
        m_DocumentDock = new Gdl.DockItem.with_stock ("main-documents", "Documents", Gtk.Stock.EDIT,
                                                      Gdl.DockItemBehavior.NEVER_FLOATING |
                                                      Gdl.DockItemBehavior.CANT_CLOSE     |
                                                      Gdl.DockItemBehavior.CANT_ICONIFY   |
                                                      Gdl.DockItemBehavior.NO_GRIP);
        m_Dock.add_item (m_DocumentDock, Gdl.DockPlacement.CENTER);
        m_DocumentDock.show ();
        m_DocumentDock.set_default_position (m_Dock);

        // Reparent document notebook in dock item
        geany_data.main_widgets.documents_notebook.reparent (m_DocumentDock);
    }

    private void
    unplug_documents_view ()
    {
        // Reparent document view in orginal paned view
        var paned = Geany.Ui.lookup_widget (geany_data.main_widgets.window, "hpaned1") as Gtk.HPaned;

        geany_data.main_widgets.documents_notebook.reparent (paned);
        m_DocumentDock.destroy ();
    }

    private void
    plug_side_view ()
    {
        // Get all side pane items
        int nb_pages = geany_data.main_widgets.sidebar_notebook.get_n_pages ();
        for (int cpt = 0; cpt < nb_pages; ++cpt)
        {
            var item =  geany_data.main_widgets.sidebar_notebook.get_nth_page (cpt);

            // Reparent page to side item dock
            if (item != null)
                on_side_view_page_added (geany_data.main_widgets.sidebar_notebook, item, cpt);
        }

        // Connect on page added of side notebook
        geany_data.main_widgets.sidebar_notebook.page_added.connect (on_side_view_page_added_delay);
        geany_data.main_widgets.sidebar_notebook.switch_page.connect (on_side_view_page_switched);
    }

    private void
    unplug_side_view ()
    {
        // Disconnect on page added of side notebook
        geany_data.main_widgets.sidebar_notebook.page_added.disconnect (on_side_view_page_added_delay);
        geany_data.main_widgets.sidebar_notebook.switch_page.disconnect (on_side_view_page_switched);

        // Remove all fake pages
        int nb_pages = geany_data.main_widgets.sidebar_notebook.get_n_pages ();
        for (int cpt = 0; cpt < nb_pages; ++cpt)
        {
            var item =  geany_data.main_widgets.sidebar_notebook.get_nth_page (0);
            item.destroy ();
        }

        // Restore child in side items
        foreach (Gdl.DockItem item in m_SideItems)
        {
            var child = item.get_children ().nth_data (0) as Gtk.Widget;
            child.ref ();
            item.remove (child);
            geany_data.main_widgets.sidebar_notebook.append_page (child, new Gtk.Label (item.long_name));
            child.unref ();
            child.hide.disconnect (on_child_item_hide);
            child.show.disconnect (on_child_item_show);
            item.destroy ();
        }
    }

    private void
    plug_message_view ()
    {
        // Get all message pane items
        int nb_pages = geany_data.main_widgets.message_window_notebook.get_n_pages ();
        for (int cpt = 0; cpt < nb_pages; ++cpt)
        {
            var item =  geany_data.main_widgets.message_window_notebook.get_nth_page (cpt);

            // Reparent page to message item dock
            if (item != null)
                on_message_view_page_added (geany_data.main_widgets.message_window_notebook, item, cpt);
        }

        // Connect on page added of side notebook
        geany_data.main_widgets.message_window_notebook.page_added.connect (on_message_view_page_added_delay);
        geany_data.main_widgets.message_window_notebook.switch_page.connect (on_message_view_page_switched);
    }

    private void
    unplug_message_view ()
    {
        // Disconnect on page added of message notebook
        geany_data.main_widgets.message_window_notebook.page_added.disconnect (on_message_view_page_added_delay);
        geany_data.main_widgets.message_window_notebook.switch_page.disconnect (on_message_view_page_switched);

        // Remove all fake pages
        int nb_pages = geany_data.main_widgets.message_window_notebook.get_n_pages ();
        for (int cpt = 0; cpt < nb_pages; ++cpt)
        {
            var item =  geany_data.main_widgets.message_window_notebook.get_nth_page (0);
            item.destroy ();
        }

        // Restore child in message items
        foreach (Gdl.DockItem item in m_MessageItems)
        {
            var child = item.get_children ().nth_data (0) as Gtk.Widget;
            child.ref ();
            item.remove (child);
            geany_data.main_widgets.message_window_notebook.append_page (child, new Gtk.Label (item.long_name));
            child.unref ();
            child.hide.disconnect (on_child_item_hide);
            child.show.disconnect (on_child_item_show);
            item.destroy ();
        }
    }

    private void
    on_side_view_page_added_delay (Gtk.Notebook inSideView, Gtk.Widget inWidget, uint inPageNum)
    {
        GLib.Idle.add (() => {
            on_side_view_page_added (inSideView, inWidget, inPageNum);
            return false;
        });
    }

    private void
    on_side_view_page_added (Gtk.Notebook inSideView, Gtk.Widget inWidget, uint inPageNum)
    {
        if (!(inWidget is Gtk.Label) || ((Gtk.Label)inWidget).label != "fake")
        {
            // Get notebook page label
            var label = inSideView.get_tab_label_text (inWidget);

            // Create dock with tab label and page content
            var dock_item = new Gdl.DockItem ("side-" + label, label, Gdl.DockItemBehavior.NORMAL);
            m_Dock.add_item (dock_item, inWidget.visible ? Gdl.DockPlacement.LEFT : Gdl.DockPlacement.NONE);
            dock_item.show ();

            uint nb = m_SideItems.length ();
            if (inWidget.visible)
            {
                if (nb != 0)
                {
                    unowned GLib.List<Gdl.DockItem> last = m_SideItems.last ();
                    for (; last != null && !last.data.is_attached (); last = last.prev);
                    if (last != null) dock_item.dock_to (last.data, Gdl.DockPlacement.CENTER, -1);
                }
                else
                {
                    dock_item.dock_to (m_DocumentDock, Gdl.DockPlacement.LEFT, -1);
                }
            }


            // Reparent item in dock
            inWidget.set_size_request (0, 0);
            inWidget.reparent (dock_item);
            inWidget.show.connect (on_child_item_show);
            inWidget.hide.connect (on_child_item_hide);

            // Add fake page to keep switch page event
            inSideView.insert_page (new Gtk.Label ("fake"), null, (int)inPageNum);

            // Add item to side items
            m_SideItems.append (dock_item);

            // Add item to menu
            add_to_display_menu (label, dock_item);

            // Remove dock item on child destroy
            inWidget.destroy.connect (() => {
                var item = m_SideItems.nth_data (nb);
                m_SideItems.remove (item);
                unowned Gtk.Widget? menu = item.get_data ("dock-menu");
                if (menu != null) menu.destroy ();
                item.destroy ();
            });
        }
    }

    private void
    on_side_view_page_switched (Gtk.NotebookPage inWidget, uint inPageNum)
    {
        unowned Gdl.DockItem? item = m_SideItems.nth_data (inPageNum);
        if (item != null)
        {
            if (item.parent is Gtk.Notebook)
            {
                ((Gtk.Notebook)item.parent).set_current_page (((Gtk.Notebook)item.parent).page_num (item));
            }
            else if (!item.is_attached ())
            {
                item.show_item ();
            }
        }
    }

    private void
    on_message_view_page_switched (Gtk.NotebookPage inWidget, uint inPageNum)
    {
        unowned Gdl.DockItem? item = m_MessageItems.nth_data (inPageNum);
        if (item != null)
        {
            if (item.parent is Gtk.Notebook)
            {
                ((Gtk.Notebook)item.parent).set_current_page (((Gtk.Notebook)item.parent).page_num (item));
            }
        }
    }

    private void
    on_message_view_page_added_delay (Gtk.Notebook inSideView, Gtk.Widget inWidget, uint inPageNum)
    {
        GLib.Idle.add (() => {
            on_message_view_page_added (inSideView, inWidget, inPageNum);
            return false;
        });
    }

    private void
    on_message_view_page_added (Gtk.Notebook inMessageView, Gtk.Widget inWidget, uint inPageNum)
    {
        if (!(inWidget is Gtk.Label) || ((Gtk.Label)inWidget).label != "fake")
        {
            // Get notebook page label
            var label = inMessageView.get_tab_label_text (inWidget);

            // Create dock with tab label and page content
            var dock_item = new Gdl.DockItem ("message-" + label, label, Gdl.DockItemBehavior.NORMAL);
            m_Dock.add_item (dock_item, inWidget.visible ? Gdl.DockPlacement.BOTTOM : Gdl.DockPlacement.NONE);
            dock_item.show ();

            uint nb = m_MessageItems.length ();
            if (inWidget.visible)
            {
                if (nb != 0)
                {
                    unowned GLib.List<Gdl.DockItem> last = m_MessageItems.last ();
                    for (; last != null && !last.data.is_attached (); last = last.prev);
                    if (last != null) dock_item.dock_to (last.data, Gdl.DockPlacement.CENTER, -1);
                }
                else
                {
                    dock_item.dock_to (m_DocumentDock, Gdl.DockPlacement.BOTTOM, -1);
                }
            }

            // Reparent item in dock
            inWidget.set_size_request (0, 0);
            inWidget.reparent (dock_item);
            inWidget.show.connect (on_child_item_show);
            inWidget.hide.connect (on_child_item_hide);

            // Add fake page to keep switch page event
            inMessageView.insert_page (new Gtk.Label ("fake"), null, (int)inPageNum);

            // Add item to side items
            m_MessageItems.append (dock_item);

            // Add item to menu
            add_to_display_menu (label, dock_item);

            // Remove dock item on child destroy
            inWidget.destroy.connect (() => {
                var item = m_MessageItems.nth_data (nb);
                m_MessageItems.remove (item);
                unowned Gtk.Widget? menu = item.get_data ("dock-menu");
                if (menu != null) menu.destroy ();
                item.destroy ();
            });
        }
    }

    private void
    on_child_item_show (Gtk.Widget inWidget)
    {
        Gdl.DockItem item = inWidget.parent as Gdl.DockItem;
        if (item != null) item.show_item ();
    }

    private void
    on_child_item_hide (Gtk.Widget inWidget)
    {
        Gdl.DockItem item = inWidget.parent as Gdl.DockItem;
        if (item != null) item.hide_item ();
    }

    private void
    on_configure_response (Gtk.Dialog inDialog, int inResponse)
    {
        if (inResponse != Gtk.ResponseType.OK && inResponse != Gtk.ResponseType.APPLY)
            return;

        unowned Gtk.ComboBox? combo_dock_button_appareance = inDialog.get_data ("dock-button-appareance");
        Gdl.SwitcherStyle style = (Gdl.SwitcherStyle)combo_dock_button_appareance.get_active ();

        if (m_Settings.switcher_style != style)
        {
            m_Settings.switcher_style = style;
            m_Settings.save ();
            m_Layout.master.switcher_style = m_Settings.switcher_style;
        }
    }


    public Gtk.Widget
    configure (Gtk.Dialog inDialog)
    {
        var vbox = new Gtk.VBox (false, 5);

        var frame_appareance = new Gtk.Frame ("Appareance");
        frame_appareance.show ();
        vbox.pack_start (frame_appareance, false, false, 0);

        var vbox_appareance = new Gtk.VBox (false, 5);
        vbox_appareance.show ();
        vbox_appareance.border_width = 5;
        frame_appareance.add (vbox_appareance);

        var hbox_dock_button_appearance = new Gtk.HBox (false, 5);
        hbox_dock_button_appearance.show ();
        vbox_appareance.pack_start (hbox_dock_button_appearance, false, false, 0);

        var label_dock_button_appareance = new Gtk.Label ("Dock switcher style:");
        label_dock_button_appareance.show ();
        hbox_dock_button_appearance.pack_start (label_dock_button_appareance, false, false, 0);

        var combo_dock_button_appareance = new Gtk.ComboBox.text ();
        combo_dock_button_appareance.append_text ("Text");
        combo_dock_button_appareance.append_text ("Icons");
        combo_dock_button_appareance.append_text ("Text + Icons");
        combo_dock_button_appareance.append_text ("Gnome toolbar settings");
        combo_dock_button_appareance.append_text ("Tabs");
        combo_dock_button_appareance.show ();
        combo_dock_button_appareance.set_active (m_Settings.switcher_style);
        hbox_dock_button_appearance.pack_start (combo_dock_button_appareance, false, false, 0);

        inDialog.set_data ("dock-button-appareance", combo_dock_button_appareance);

        inDialog.response.connect (on_configure_response);

        return vbox;
    }

    public void
    save_layout ()
    {
        string path_config = geany_data.app.config_dir + "/plugins/gvt-dock";
        if (!GLib.FileUtils.test (path_config, GLib.FileTest.EXISTS))
        {
            GLib.DirUtils.create_with_parents(path_config, 0755);
        }

        string layout_filename = path_config + "/layout.xml";
        m_Layout.save_layout (null);
        m_Layout.save_to_file (layout_filename);

        m_Settings.save ();
    }

    public void
    unplug_all ()
    {
        // Unplug document view
        unplug_documents_view ();

        // Unplug side view
        unplug_side_view ();

        // Unplug message view
        unplug_message_view ();

        // Destroy dock
        m_Dock.detach (true);
        m_Dock.destroy ();
        var main = Geany.Ui.lookup_widget (geany_data.main_widgets.window, "vbox1") as Gtk.Box;
        main.remove (m_Box);

        // Restore status bar position
        var statusbar = Geany.Ui.lookup_widget (geany_data.main_widgets.window, "hbox1") as Gtk.Box;
        m_OriginalMain.show ();
        main.reorder_child (m_OriginalMain, -1);
        main.reorder_child (statusbar, -1);
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
    inInfo.set ("GVT Dock", "GDL Dock plugin for Geany", "0.1.0", "Nicolas Bruguier");
}

public void
plugin_init (Geany.Data inData)
{
    geany_plugin.module_make_resident ();

    // Delay creation to let geany original creation terminate before
    // relayout it
    if (s_IdCreate == 0)
    {
        s_IdCreate = GLib.Idle.add (() => {
            if (s_IdCreate != 0)
            {
                s_Plugin = new GVT.DockPlugin ();
                s_IdCreate = 0;
            }
            return false;
        });
    }
}

public void
plugin_cleanup ()
{
    if (s_IdCreate != 0) GLib.Source.remove (s_IdCreate);
    s_IdCreate = 0;
    if (s_Plugin != null)
    {
        s_Plugin.unplug_all ();
    }
    s_Plugin = null;
}

public Gtk.Widget?
plugin_configure (Gtk.Dialog inDialog)
{
    if (s_Plugin != null)
    {
        return s_Plugin.configure (inDialog);
    }

    return null;
}
