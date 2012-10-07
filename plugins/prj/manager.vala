/* -*- Mode: Vala; indent-tabs-mode: nil; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * manager.vala
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

public class GVT.Manager : GLib.Object
{
    // types
    private class GlobalPrefs : GLib.Object
    {
        // properties
        private string m_Filename = geany_data.app.config_dir + "/plugins/gvt-project/gvt-project.conf";
        private GLib.KeyFile m_Config;

        // accessors
        public string[] current_projects {
            owned get {
                return Geany.Utils.get_setting_string (m_Config, "project", "current", "").split(",");
            }
            set {
                m_Config.set_string ("project", "current", string.joinv (",", value));
            }
        }

        public string diff_tool {
            owned get {
                return Geany.Utils.get_setting_string (m_Config, "project", "difftool", "meld");
            }
            set {
                m_Config.set_string ("project", "difftool", value);
            }
        }

        public int build_job {
            get {
                return Geany.Utils.get_setting_integer (m_Config, "project", "job", 1);
            }
            set {
                m_Config.set_integer ("project", "job", value);
            }
        }

        public GlobalPrefs ()
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
                build_job = 1;
                diff_tool = "/usr/bin/meld";
                save ();
            }
        }

        ~GlobalPrefs ()
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
    }

    private class Prefs : GLib.Object
    {
        // properties
        private string m_Filename;
        private GLib.KeyFile m_Config;

        // accessors
        public string[] current_files {
            owned get {
                return Geany.Utils.get_setting_string (m_Config, "project", "files", "").split(",");
            }
            set {
                m_Config.set_string ("project", "files", string.joinv (",", value));
            }
        }

        public Prefs (Project inProject)
        {
            m_Filename = inProject.path + "/." + inProject.name + ".gvt-project";
            m_Config = new GLib.KeyFile ();

            if (GLib.FileUtils.test (m_Filename, GLib.FileTest.EXISTS))
            {
                try
                {
                    m_Config.load_from_file (m_Filename, GLib.KeyFileFlags.KEEP_COMMENTS);
                }
                catch (GLib.Error err)
                {
                }
            }
        }

        ~Prefs ()
        {
            save ();
        }

        public void
        add_file (string inFilename)
        {
            bool found = false;
            string[] files = current_files;
            foreach (string filename in files)
            {
                if (filename == inFilename)
                {
                    found = true;
                    break;
                }
            }

            if (!found)
            {
                files += inFilename;
                current_files = files;
            }
        }

        public void
        remove_file (string inFilename)
        {
            string[] files = {};

            foreach (string filename in current_files)
            {
                if (filename != inFilename)
                {
                    files += filename;
                }
            }

            current_files = files;
        }

        public void
        save ()
        {
            Geany.Utils.write_file (m_Filename, m_Config.to_data ());
        }
    }

    private class Prj : GLib.Object
    {
        // properties
        private bool                          m_Active;
        private unowned GlobalPrefs           m_GlobalPrefs;
        private Prefs                         m_Prefs;
        private unowned Gtk.TreeStore         m_TreeStore;
        private unowned Gtk.TreeView          m_TreeView;
        private Autotools                     m_Autotools;
        private Project                       m_Project;
        private Geany.TagManager.SourceFile[] m_TmFiles = {};
        private Gtk.TreeIter                  m_IterRoot;

        // accessors
        public string name {
            owned get {
                return m_Project.name + " [" + m_Project.version + "]";
            }
        }

        public string project_name {
            owned get {
                return m_Project.name;
            }
        }

        public string path {
            owned get {
                return m_Project.path;
            }
        }

        public bool active {
            get {
                return m_Active;
            }
            set {
                if (m_Active != value)
                {
                    m_Active = value;
                    if (m_Active)
                    {
                        debug ("set %s active", name);
                        foreach (unowned Geany.TagManager.SourceFile file in m_TmFiles)
                        {
                            geany_data.app.tm_workspace.add_object (file);
                        }
                    }
                    else
                    {
                        debug ("set %s inactive", name);
                        foreach (unowned Geany.TagManager.SourceFile file in m_TmFiles)
                        {
                            geany_data.app.tm_workspace.remove_object (file, false, false);
                        }
                    }
                }
            }
        }

        // methods
        public Prj (Manager inManager, string inPath)
        {
            m_Active = false;
            m_GlobalPrefs = inManager.m_GlobalPrefs;
            m_TreeStore = inManager.m_TreeStore;
            m_TreeView = inManager.m_TreeView;
            m_Autotools = new Autotools ();
            m_Autotools.message.connect ((s) => {
                Geany.MessageWindow.compiler_add (Geany.MessageWindow.Color.BLACK, s);
            });
            m_Autotools.error_message.connect ((s) => {
                Geany.MessageWindow.compiler_add (Geany.MessageWindow.Color.RED, s);
            });
            m_Autotools.completed.connect ((c, r) => {
                Geany.MessageWindow.compiler_add (Geany.MessageWindow.Color.BLUE, "%s finished with status %u", c, r);
                Geany.Ui.progress_bar_stop ();
                s_CommandLaunched = false;
            });
            m_Project = m_Autotools.parse (inPath);

            m_Prefs = new Prefs (m_Project);

            // Fill manager tree store
            Gdk.Pixbuf icon = Manager.pixbuf_from_stock (Gtk.Stock.DIRECTORY);

            m_TreeStore.append (out m_IterRoot, null);
            m_TreeStore.set (m_IterRoot, 0, icon, 1, name, 2, m_Project);

            foreach (unowned Item? item in m_Project)
            {
                add_item (m_IterRoot, item);
            }

            // Add to recent project openned
            add_recent_project ();
        }

        ~Prj ()
        {
            active = false;
            m_TreeStore.remove (m_IterRoot);
            foreach (unowned Geany.TagManager.SourceFile file in m_TmFiles)
            {
                file.update (true, false, true);
                geany_data.app.tm_workspace.remove_object (file, false, false);
            }
        }

        private void
        add_recent_project ()
        {
            string groups [2] = { "gvtprojects", null };
            Gtk.RecentData recent_data = Gtk.RecentData ();
            recent_data.display_name = m_Project.name;
            recent_data.groups = groups;
            recent_data.app_name = "geany";
            recent_data.app_exec = "geany";
            recent_data.mime_type = "text/plain";
            recent_data.is_private = false;

            try
            {
                Gtk.RecentManager.get_default ().add_full (Filename.to_uri (m_Project.path), recent_data);
            }
            catch (GLib.Error err)
            {
                critical (err.message);
            }
        }

        private void
        add_item (Gtk.TreeIter inIter, Item? inItem)
        {
            if (inItem is Group)
            {
                Group group = (Group)inItem;
                Gdk.Pixbuf icon = Manager.pixbuf_from_stock (Gtk.Stock.DIRECTORY);
                Gtk.TreeIter iter;

                m_TreeStore.append (out iter, inIter);
                m_TreeStore.set (iter, 0, icon, 1, inItem.name, 2, inItem);

                foreach (unowned Item child in group)
                {
                    add_item (iter, child);
                }

                group.updated.connect (() => {
                    bool group_expanded = m_TreeView.is_row_expanded (m_TreeStore.get_path (iter));
                    Set<string> expanded = new Set<string> ();
                    expanded.compare_func = (a, b) => {
                        return GLib.strcmp (a, b);
                    };

                    // Remove all targets and datas
                    int nb = m_TreeStore.iter_n_children (iter);
                    for (int cpt = nb - 1; cpt >= 0; --cpt)
                    {
                        Gtk.TreeIter child_iter;
                        m_TreeStore.iter_nth_child (out child_iter, iter, cpt);
                        unowned Item? child = null;
                        m_TreeStore.get (child_iter, 2, out child);

                        if (m_TreeView.is_row_expanded (m_TreeStore.get_path (child_iter)))
                        {
                            expanded.insert (child.name);
                        }

                        if (child is Target || child is Data)
                        {
                            m_TreeStore.remove (child_iter);
                        }
                    }

                    // Re add them
                    foreach (unowned Item child in group)
                    {
                        if (child is Target || child is Data)
                            add_item (iter, child);
                    }

                    // Re-expand rows
                    if (group_expanded)
                    {
                        m_TreeView.expand_row (m_TreeStore.get_path (iter), false);
                    }

                    nb = m_TreeStore.iter_n_children (iter);
                    for (int cpt = 0; cpt < nb; ++cpt)
                    {
                        Gtk.TreeIter child_iter;
                        m_TreeStore.iter_nth_child (out child_iter, iter, cpt);
                        unowned Item? child = null;
                        m_TreeStore.get (child_iter, 2, out child);
                        if (child.name in expanded)
                        {
                            m_TreeView.expand_row (m_TreeStore.get_path (child_iter), false);
                        }
                    }
                });
                // workaround for valac 0.12 which does not support owned/unowned delegate
                unref ();
            }
            else if (inItem is Target)
            {
                unowned Target target = (Target)inItem;

                Gdk.Pixbuf icon = Manager.pixbuf_from_stock (Gtk.Stock.NEW);

                if (target.target_type == TargetType.EXECUTABLE)
                    icon = Manager.pixbuf_from_stock (Gtk.Stock.EXECUTE);
                else
                    icon = Manager.pixbuf_from_stock (Gtk.Stock.PAGE_SETUP);
                Gtk.TreeIter iter;

                m_TreeStore.append (out iter, inIter);
                m_TreeStore.set (iter, 0, icon, 1, inItem.name, 2, inItem);

                foreach (unowned Item child in target)
                {
                    add_item (iter, child);
                }
            }
            else if (inItem is Source)
            {
                unowned Source source = (Source)inItem;

                if (source.filename != null)
                {
                    Gdk.Pixbuf icon = Manager.detect_type_from_file (source.filename).icon;
                    Gtk.TreeIter iter;

                    m_TreeStore.append (out iter, inIter);
                    m_TreeStore.set (iter, 0, icon, 1, inItem.name, 2, inItem);

                    if (source.filename != null && GLib.FileUtils.test (source.filename, GLib.FileTest.EXISTS))
                    {
                        m_TmFiles += new Geany.TagManager.SourceFile (source.filename, true, source.file_type.name);
                        if (m_TmFiles [m_TmFiles.length - 1] != null)
                        {
                            source.set_data ("tm-file", m_TmFiles.length);
                        }
                        else
                            m_TmFiles.resize (m_TmFiles.length - 1);
                    }
                }
            }
            else if (inItem is Data)
            {
                Data data = (Data)inItem;

                if (data.length == 0)
                {
                    Gdk.Pixbuf icon = Manager.detect_type_from_file (((Data)inItem).filename).icon;
                    Gtk.TreeIter iter;
                    string name = inItem.name;

                    m_TreeStore.append (out iter, inIter);
                    m_TreeStore.set (iter, 0, icon, 1, name.length == 0 ? "data" : name, 2, inItem);
                }
                else
                {
                    Gdk.Pixbuf icon = Manager.pixbuf_from_stock (Gtk.Stock.EDIT);
                    Gtk.TreeIter iter;
                    string name = inItem.name;

                    m_TreeStore.append (out iter, inIter);
                    m_TreeStore.set (iter, 0, icon, 1, name.length == 0 ? "data" : name, 2, inItem);

                    foreach (unowned Item child in data)
                    {
                        add_item (iter, child);
                    }
                }
            }
        }

        public void
        configure (string inParams, bool inRegenerate)
        {
            if (!s_CommandLaunched)
            {
                save_all ();
                Geany.MessageWindow.switch_tab (Geany.MessageWindow.TabID.COMPILER, true);
                Geany.MessageWindow.clear_tab (Geany.MessageWindow.TabID.COMPILER);
                Geany.MessageWindow.compiler_add (Geany.MessageWindow.Color.BLUE, "Launching %s %s", !inRegenerate ? "./configure" : "./autogen.sh", inParams);
                Geany.Ui.progress_bar_start (null);
                s_CommandLaunched = m_Autotools.configure (m_Project, inParams, inRegenerate);
            }
        }

        public void
        build_all ()
        {
            debug ("Build all %s", m_Project.name);
            build (m_Project);
        }

        public void
        build (Group inGroup)
        {
            if (!s_CommandLaunched)
            {
                save_all ();
                Geany.MessageWindow.switch_tab (Geany.MessageWindow.TabID.COMPILER, true);
                Geany.MessageWindow.clear_tab (Geany.MessageWindow.TabID.COMPILER);
                Geany.MessageWindow.compiler_add (Geany.MessageWindow.Color.BLUE, "Launching build...");
                Geany.Ui.progress_bar_start (null);
                string params = "";

                if (m_GlobalPrefs.build_job > 1)
                    params = "-j%i".printf (m_GlobalPrefs.build_job);

                string working_path = inGroup.path;
                geany_data.build_info.group = Geany.BuildType.MAKE_ALL.to_build_group ();
                geany_data.build_info.dir = working_path;
                geany_data.build_info.file_type_id = Geany.FiletypeID.MAKE;
                s_CommandLaunched = m_Autotools.build (inGroup.path, params);
            }
        }

        public void
        build_target (Target inTarget)
        {
            if (!s_CommandLaunched)
            {
                save_all ();
                unowned Group? group = (Group?)inTarget.parent;
                Geany.MessageWindow.switch_tab (Geany.MessageWindow.TabID.COMPILER, true);
                Geany.MessageWindow.clear_tab (Geany.MessageWindow.TabID.COMPILER);
                Geany.MessageWindow.compiler_add (Geany.MessageWindow.Color.BLUE, "Launching build of %s ...", inTarget.name);
                Geany.Ui.progress_bar_start (null);
                string params = "";

                if (m_GlobalPrefs.build_job > 1)
                    params = "-j%i".printf (m_GlobalPrefs.build_job);

                params += " " + inTarget.name;
                string working_path = group.path;
                geany_data.build_info.group = Geany.BuildType.CUSTOM.to_build_group ();
                geany_data.build_info.dir = working_path;
                geany_data.build_info.file_type_id = Geany.FiletypeID.MAKE;
                s_CommandLaunched = m_Autotools.build (group.path, params);
            }
        }

        public bool
        build_target_for_filename (string inFilename)
        {
            bool ret = false;
            string filename= inFilename.substring (m_Project.path.length + 1);
            unowned Item? item = m_Project.find_path (filename);

            if (item != null)
            {
                unowned Item? p = null;
                for (p = item.parent; p != null && !(p is Target) && !(p is Group); p = p.parent);

                if (item != null && p != null)
                {
                    if (p is Target)
                    {
                        unowned Target? target = (Target?)p;
                        debug ("Build %s", target.name);
                        build_target (target);
                        ret = true;
                    }
                    else if (p is Group)
                    {
                        unowned Group? group = (Group?)p;
                        debug ("Build %s", group.name);
                        build (group);
                        ret = true;
                    }
                }
            }

            return ret;
        }

        public void
        clean (Group inGroup)
        {
            if (!s_CommandLaunched)
            {
                save_all ();
                Geany.MessageWindow.switch_tab (Geany.MessageWindow.TabID.COMPILER, true);
                Geany.MessageWindow.clear_tab (Geany.MessageWindow.TabID.COMPILER);
                Geany.MessageWindow.compiler_add (Geany.MessageWindow.Color.BLUE, "Launching clean ...");
                Geany.Ui.progress_bar_start (null);

                s_CommandLaunched = m_Autotools.clean (inGroup.path);
            }
        }

        public void
        clean_all ()
        {
            clean (m_Project);
        }

        public int
        compare (Prj inOther)
        {
            return m_Project.compare (inOther.m_Project);
        }

        public void
        update_tag (string inFilename)
        {
            string filename= inFilename.substring (m_Project.path.length + 1);
            unowned Item? item = m_Project.find_path (filename);
            if (item != null && item is Source)
            {
                unowned Source? source = (Source?)item;
                int num = source.get_data ("tm-file");
                if (num > 0)
                {
                    debug ("update tag of %s", source.name);
                    m_TmFiles[num - 1].update (true, false, true);
                }
            }
        }

        public void
        add_tag (string inFilename)
        {
            string filename= inFilename.substring (m_Project.path.length + 1);
            unowned Item? item = m_Project.find_path (filename);
            if (item != null && item is Source)
            {
                unowned Source? source = (Source?)item;
                int num = source.get_data ("tm-file");
                if (num > 0)
                {
                    debug ("add tag of %s", source.name);
                    geany_data.app.tm_workspace.add_object (m_TmFiles[num - 1]);
                }
            }
        }

        public void
        remove_tag (string inFilename)
        {
            string filename= inFilename.substring (m_Project.path.length + 1);
            unowned Item? item = m_Project.find_path (filename);
            if (item != null && item is Source)
            {
                unowned Source? source = (Source?)item;
                int num = source.get_data ("tm-file");
                if (num > 0)
                {
                    debug ("remove tag of %s", source.name);
                    geany_data.app.tm_workspace.remove_object (m_TmFiles[num - 1], false, false);
                }
            }
        }
    }

    public class AskConfigureParams : Gtk.Dialog
    {
        // properties
        private Gtk.CheckButton   m_Regenerate;
        private Gtk.ComboBoxEntry m_Combo;

        // accessors
        public string params {
            get {
                unowned Gtk.Entry entry = (Gtk.Entry)m_Combo.get_child ();
                return entry.get_text ();
            }
        }

        public bool regenerate {
            get {
                return m_Regenerate.active;
            }
        }

        // methods
        construct
        {
            var vbox = new Gtk.VBox (false, 5);
            vbox.show ();

            this.vbox.pack_start (vbox);

            m_Regenerate = new Gtk.CheckButton.with_label ("Regenerate");
            m_Regenerate.show ();
            vbox.pack_start (m_Regenerate, false, false, 5);

            var hbox = new Gtk.HBox (false, 5);
            hbox.show ();
            vbox.pack_start (hbox, true, false);

            var label = new Gtk.Label ("Configure options:");
            label.show ();
            hbox.pack_start (label, false, false, 0);

            m_Combo = new Gtk.ComboBoxEntry ();
            m_Combo.show ();
            hbox.pack_start (m_Combo);

            Gtk.Entry entry = (Gtk.Entry)m_Combo.get_child ();
            Geany.Ui.entry_add_clear_icon (entry);
        }

        public AskConfigureParams ()
        {
            set_title ("Configure");
            set_default_size (400, -1);
            set_transient_for (geany_data.main_widgets.window);
            set_modal (true);
            add_buttons (Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
                         Gtk.Stock.EXECUTE, Gtk.ResponseType.OK);
        }

        public bool
        main ()
        {
            bool ret = false;

            m_Regenerate.active = false;
            m_Combo.active = 0;

            Gtk.ResponseType response = (Gtk.ResponseType)run ();
            if (response == Gtk.ResponseType.OK)
            {
                Geany.Ui.combo_box_add_to_history (m_Combo, params);
                ret = true;
            }
            hide ();

            return ret;
        }
    }

    // static properties
    static bool                s_CommandLaunched = false;

    // properties
    private GlobalPrefs        m_GlobalPrefs;
    private Gtk.MenuItem       m_ProjectMenu;
    private Set<Prj>           m_Projects;
    private Gtk.TreeView       m_TreeView;
    private Gtk.TreeStore      m_TreeStore;
    private AskConfigureParams m_ConfigureDialog;

    // static methods
    public static inline unowned Geany.Filetype?
    detect_type_from_file (string inFilename)
    {
        return Geany.Filetype.detect_from_file (inFilename);
    }

    public static inline Gdk.Pixbuf?
    pixbuf_from_stock(string inStock)
    {
        unowned Gtk.IconSet? icon_set = Gtk.IconFactory.lookup_default (inStock);

        if (icon_set != null)
            return icon_set.render_icon(Gtk.Widget.get_default_style (), Gtk.Widget.get_default_direction(),
                                        Gtk.StateType.NORMAL, Gtk.IconSize.MENU, geany_data.main_widgets.window, "");
        return null;
    }

    public static void
    save_all ()
    {
        int nb = geany_data.main_widgets.documents_notebook.get_n_pages ();

        for (uint cpt = 0; cpt < nb; ++cpt)
        {
            unowned Geany.Document? document = Geany.Document.get_from_notebook_page (cpt);
            if (!document.has_changed) continue;

            document.save ();
        }
    }

    // methods
    public Manager ()
    {
        // Load config
        m_GlobalPrefs = new GlobalPrefs ();

        // Create prj array
        m_Projects = new Set<Prj> ();
        m_Projects.compare_func = Prj.compare;

        // Create side pane
        create_project_pane ();

        // Create tool menus
        create_tool_menu ();

        // Create configure dialog
        m_ConfigureDialog = new AskConfigureParams ();

        // Load last projects
        if (m_GlobalPrefs.current_projects.length > 0)
        {
            foreach (string project in m_GlobalPrefs.current_projects)
            {
                m_Projects.insert (new Prj (this, project));
            }
        }

        geany_plugin.signal_connect (null, "document-open",     true, (GLib.Callback) on_document_open,     this);
        geany_plugin.signal_connect (null, "document-close",    true, (GLib.Callback) on_document_close,    this);
        geany_plugin.signal_connect (null, "document-save",     true, (GLib.Callback) on_document_save,     this);
        geany_plugin.signal_connect (null, "document-reload",   true, (GLib.Callback) on_document_save,     this);
        geany_plugin.signal_connect (null, "document-activate", true, (GLib.Callback) on_document_activate, this);

        unowned Geany.KeyGroup key_group = geany_plugin.set_key_group ("GVT Project Manager", GVT.KeyBinding.COUNT);
        Geany.Keybindings.set_item (key_group, GVT.KeyBinding.FIND, plugin_kb_activate, 0, 0,
                                    "gvt_prj_find", "Find in project", null);
        Geany.Keybindings.set_item (key_group, GVT.KeyBinding.CONFIGURE, plugin_kb_activate, 0, 0,
                                    "gvt_prj_configure", "Configure project", null);
        Geany.Keybindings.set_item (key_group, GVT.KeyBinding.BUILD_ALL, plugin_kb_activate, 0, 0,
                                    "gvt_prj_build_all", "Build project", null);
        Geany.Keybindings.set_item (key_group, GVT.KeyBinding.BUILD, plugin_kb_activate, 0, 0,
                                    "gvt_prj_build", "Build", null);
        Geany.Keybindings.set_item (key_group, GVT.KeyBinding.CLEAN, plugin_kb_activate, 0, 0,
                                    "gvt_prj_clean", "Clean project", null);
        Geany.Keybindings.set_item (key_group, GVT.KeyBinding.DIFF, plugin_kb_activate, 0, 0,
                                    "gvt_prj_diff", "Diff project", null);
    }

    ~Manager ()
    {
        m_Projects.clear ();
    }

    [CCode (instance_pos = -1)]
    private void
    on_document_open (GLib.Object inObject, Geany.Document inDocument)
    {
        string filename = inDocument.file_name;
        foreach (unowned Prj? prj in m_Projects)
        {
            if (filename.has_prefix (prj.path + "/"))
            {
                prj.active = true;
                prj.remove_tag (filename);
            }
            else
            {
                prj.active = false;
            }
        }
    }

    [CCode (instance_pos = -1)]
    private void
    on_document_close (GLib.Object inObject, Geany.Document inDocument)
    {
        string filename = inDocument.file_name;
        foreach (unowned Prj? prj in m_Projects)
        {
            if (filename.has_prefix (prj.path + "/"))
            {
                unowned Geany.Document? document = Geany.Document.get_current ();
                if (document == null || document.file_name == filename || !document.file_name.has_prefix (prj.path))
                {
                    prj.active = false;
                    prj.add_tag (filename);
                }
                break;
            }
        }
    }

    [CCode (instance_pos = -1)]
    private void
    on_document_save (GLib.Object inObject, Geany.Document inDocument)
    {
        string filename = inDocument.file_name;
        foreach (unowned Prj? prj in m_Projects)
        {
            if (filename.has_prefix (prj.path + "/"))
            {
                prj.update_tag (filename);
                break;
            }
        }
    }

    [CCode (instance_pos = -1)]
    private void
    on_document_activate (GLib.Object inObject, Geany.Document inDocument)
    {
        string filename = inDocument.file_name;
        foreach (unowned Prj? prj in m_Projects)
        {
            if (filename.has_prefix (prj.path + "/"))
            {
                prj.active = true;
                prj.remove_tag (filename);
            }
            else
            {
                prj.active = false;
            }
        }
    }

    private void
    close_project ()
    {
        Gtk.TreeModel model;
        Gtk.TreeIter iter;

        if (m_TreeView.get_selection ().get_selected (out model, out iter))
        {
            unowned Item item;
            m_TreeStore.get (iter, 2, out item);
            for (;item != null && !(item is Project); item = item.parent);
            if (item != null)
            {
                unowned Prj? prj = m_Projects.search <string> (item.name, (k, v) => {
                    return GLib.strcmp (k.project_name, v);
                });
                if (prj != null)
                {
                    m_Projects.remove (prj);
                    prj.unref ();
                }

                string[] c = {};
                foreach (unowned Prj p in m_Projects)
                {
                    c += p.path;
                }
                c += null;
                m_GlobalPrefs.current_projects = c;
                m_GlobalPrefs.save ();
            }
        }
    }

    private Gtk.Menu
    create_popup_menu (Node inNode)
    {
        var menu = new Gtk.Menu ();
        menu.show ();

        if (inNode is Project)
        {
            unowned Project project = (Project)inNode;
            unowned Prj? prj = m_Projects.search <string> (project.name, (k, v) => {
                return GLib.strcmp (k.project_name, v);
            });

            if (prj != null)
            {
                var menu_configure = new Gtk.MenuItem.with_label ("Configure");
                menu_configure.show ();
                menu.add (menu_configure);

                menu_configure.activate.connect (() => {
                    bool ret = m_ConfigureDialog.main ();
                    message ("ret = %s", ret.to_string ());
                    if (ret)
                    {
                        prj.configure (m_ConfigureDialog.params, m_ConfigureDialog.regenerate);
                    }
                });
            }
        }

        if (inNode is Group)
        {
            unowned Group group = (Group)inNode;
            unowned Project project = (Project)group.project;
            unowned Prj? prj = m_Projects.search <string> (project.name, (k, v) => {
                return GLib.strcmp (k.project_name, v);
            });

            if (prj != null)
            {
                var menu_build = new Gtk.MenuItem.with_label ("Build");
                menu_build.show ();
                menu.add (menu_build);

                menu_build.activate.connect (() => {
                    prj.build (group);
                });

                var menu_clean = new Gtk.MenuItem.with_label ("Clean");
                menu_clean.show ();
                menu.add (menu_clean);

                menu_clean.activate.connect (() => {
                    prj.clean (group);
                });
            }

            var separator1 = new Gtk.SeparatorMenuItem ();
            separator1.show ();
            menu.add (separator1);
        }

        if (inNode is Project)
        {
            unowned Project project = (Project)inNode;
            string configure_in = project.path + "/configure.in";
            string configure_ac = project.path + "/configure.ac";
            string? configure = null;

            if (GLib.FileUtils.test (configure_in, GLib.FileTest.EXISTS))
                configure = configure_in;
            else if (GLib.FileUtils.test (configure_ac, GLib.FileTest.EXISTS))
                configure = configure_ac;
            if (configure != null)
            {
                var menu_configure = new Gtk.MenuItem.with_label ("Open configure");
                menu_configure.show ();
                menu.add (menu_configure);

                menu_configure.activate.connect (() => {
                    Geany.Document.open (configure);
                });
            }
        }

        if (inNode is Group)
        {
            unowned Group group = (Group)inNode;
            string makefile_am = group.path + "/Makefile.am";

            if (GLib.FileUtils.test (makefile_am, GLib.FileTest.EXISTS))
            {
                var menu_makefile = new Gtk.MenuItem.with_label ("Open makefile");
                menu_makefile.show ();
                menu.add (menu_makefile);

                menu_makefile.activate.connect (() => {
                    Geany.Document.open (makefile_am);
                });
            }
        }

        if (inNode is Target)
        {
            unowned Target? target = (Target?)inNode;
            unowned Group? group = (Group?)target.parent;
            unowned Project project = (Project)group.project;
            unowned Prj? prj = m_Projects.search <string> (project.name, (k, v) => {
                return GLib.strcmp (k.project_name, v);
            });

            if (prj != null)
            {
                var menu_build = new Gtk.MenuItem.with_label ("Build %s".printf (target.name));
                menu_build.show ();
                menu.add (menu_build);

                menu_build.activate.connect (() => {
                    prj.build_target (target);
                });
            }

            if (target.target_type == TargetType.EXECUTABLE)
            {
                var separator1 = new Gtk.SeparatorMenuItem ();
                separator1.show ();
                menu.add (separator1);

                var menu_execute = new Gtk.MenuItem.with_label ("Execute %s".printf (target.name));
                menu_execute.show ();
                menu.add (menu_execute);

                menu_execute.activate.connect (() => {
                    Geany.MessageWindow.switch_tab (Geany.MessageWindow.TabID.VTE, true);
                    Geany.Vte.send_cmd (target.filename + "\n");
                });
            }
        }

        if (inNode is Group)
        {
            unowned Group group = (Group)inNode;

            var separator1 = new Gtk.SeparatorMenuItem ();
            separator1.show ();
            menu.add (separator1);

            var menu_cwd = new Gtk.MenuItem.with_label ("Open %s".printf (group.path));
            menu_cwd.show ();
            menu.add (menu_cwd);

            menu_cwd.activate.connect (() => {
                Geany.MessageWindow.switch_tab (Geany.MessageWindow.TabID.VTE, true);
                Geany.Vte.cwd (group.path, true);
            });
        }

        if (inNode is Project)
        {
            unowned Project project = (Project)inNode;

            var separator1 = new Gtk.SeparatorMenuItem ();
            separator1.show ();
            menu.add (separator1);

            var menu_execute = new Gtk.MenuItem.with_label ("Launch Diff Tool");
            menu_execute.show ();
            menu.add (menu_execute);

            menu_execute.activate.connect (() => {
                try
                {
                    new Command (project.path, m_GlobalPrefs.diff_tool + " .");
                }
                catch (GLib.Error err)
                {
                    warning ("Error on launching difftool: %s", err.message);
                }
            });

            var menu_close = new Gtk.MenuItem.with_label ("Close");
            menu_close.show ();
            menu.add (menu_close);

            menu_close.activate.connect (() => {
                close_project ();
            });
        }

        return menu;
    }

    private void
    create_tool_menu ()
    {
        m_ProjectMenu = new Gtk.MenuItem.with_mnemonic ("GVT _Project");
        m_ProjectMenu.show ();
        geany_data.main_widgets.tools_menu.add (m_ProjectMenu);

        var menu = new Gtk.Menu ();
        menu.show ();
        m_ProjectMenu.set_submenu (menu);

        var open_menu = new Gtk.ImageMenuItem.with_mnemonic ("_Open");
        open_menu.image = new Gtk.Image.from_stock (Gtk.Stock.OPEN, Gtk.IconSize.MENU);
        open_menu.activate.connect (on_open_project);
        open_menu.show ();
        menu.add (open_menu);

        var close_menu = new Gtk.ImageMenuItem.with_mnemonic ("_Close");
        close_menu.image = new Gtk.Image.from_stock (Gtk.Stock.CLOSE, Gtk.IconSize.MENU);
        close_menu.activate.connect (close_project);
        close_menu.show ();
        menu.add (close_menu);

        var recent_menu = new Gtk.MenuItem.with_mnemonic ("_Recent project");
        recent_menu.show ();
        menu.add (recent_menu);

        var recent_chooser_menu = new Gtk.RecentChooserMenu.for_manager (Gtk.RecentManager.get_default ());
        var filter = new Gtk.RecentFilter ();
        filter.add_group ("gvtprojects");
        recent_chooser_menu.set_filter (filter);
        recent_chooser_menu.item_activated.connect (() => {
            try
            {
                m_Projects.insert (new Prj (this, Filename.from_uri (recent_chooser_menu.get_current_uri ())));
                string[] c = {};
                foreach (unowned Prj p in m_Projects)
                {
                    c += p.path;
                }
                c += null;
                m_GlobalPrefs.current_projects = c;
                m_GlobalPrefs.save ();
            }
            catch (GLib.Error err)
            {
                critical (err.message);
            }
        });
        recent_chooser_menu.show ();
        recent_menu.set_submenu (recent_chooser_menu);
    }

    private Gtk.TreeView
    create_tree_view ()
    {
        var tree_view = new Gtk.TreeView ();
        var tree_view_column = new Gtk.TreeViewColumn ();

        tree_view.headers_visible = false;
        tree_view.append_column (tree_view_column);

        var render_icon = new Gtk.CellRendererPixbuf ();
        var render_text = new Gtk.CellRendererText ();

        tree_view_column.pack_start (render_icon, false);
        tree_view_column.set_attributes (render_icon, "pixbuf", 0);
        tree_view_column.pack_start (render_text, true);
        tree_view_column.set_attributes (render_text, "text", 1);

        Geany.Ui.widget_modify_font_from_string (tree_view, geany_data.interface_prefs.tagbar_font);

        m_TreeStore = new Gtk.TreeStore (3, typeof (Gdk.Pixbuf), typeof (string), typeof (Item));

        tree_view.set_model (m_TreeStore);

        return tree_view;
    }

    private void
    create_project_pane ()
    {
        var scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
        scrolled_window.show ();

        m_TreeView = create_tree_view ();
        m_TreeView.show ();
        scrolled_window.add (m_TreeView);

        m_TreeView.row_activated.connect (on_row_activated);
        m_TreeView.button_press_event.connect (on_treeview_clicked);

        geany_data.main_widgets.sidebar_notebook.append_page (scrolled_window, new Gtk.Label ("GVT Project"));
    }

    private void
    on_open_project ()
    {
        var dialog = new Gtk.FileChooserDialog ("Open Project", geany_data.main_widgets.window,
                                                Gtk.FileChooserAction.OPEN |
                                                Gtk.FileChooserAction.SELECT_FOLDER,
                                                Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
                                                Gtk.Stock.OPEN, Gtk.ResponseType.OK);
        int response = dialog.run ();

        if (response == Gtk.ResponseType.OK)
        {
            m_Projects.insert (new Prj (this, dialog.get_filename ()));
            string[] c = {};
            foreach (unowned Prj p in m_Projects)
            {
                c += p.path;
            }
            c += null;
            m_GlobalPrefs.current_projects = c;
            m_GlobalPrefs.save ();
        }

        dialog.destroy ();
    }

    private bool
    on_treeview_clicked (Gdk.EventButton inEvent)
    {
        if (inEvent.button == 3)
        {
            Gtk.TreePath path;
            Gtk.TreeViewColumn column;
            int cell_x, cell_y;

            if (m_TreeView.get_path_at_pos ((int)inEvent.x, (int)inEvent.y, out path, out column, out cell_x, out cell_y))
            {
                m_TreeView.get_selection ().unselect_all ();
                m_TreeView.get_selection ().select_path (path);

                Gtk.TreeIter iter;
                m_TreeStore.get_iter (out iter, path);

                Item item;
                m_TreeStore.get (iter, 2, out item);

                if (item is Group || item is Target)
                {
                    create_popup_menu ((Node)item).popup (null, null, null, inEvent.button, inEvent.time);
                }

                return true;
            }
        }

        return false;
    }

    private void
    on_row_activated (Gtk.TreeView inView, Gtk.TreePath inPath, Gtk.TreeViewColumn inColumn)
    {
        Gtk.TreeIter iter;
        m_TreeStore.get_iter (out iter, inPath);

        unowned Item item;
        m_TreeStore.get (iter, 2, out item);
        if (item is Source)
        {
            unowned Source source = (Source)item;
            Geany.Document.open (source.filename);
        }
        else if (item is Data && ((Data)item).length == 0)
        {
            unowned Data data = (Data)item;
            Geany.Document.open (data.filename);
        }
        else if (item is Group || item is Project || item is Target || (item is Data && ((Data)item).length > 0))
        {
            if (inView.is_row_expanded (inPath))
                inView.collapse_row (inPath);
            else
                inView.expand_row (inPath, false);
        }
    }

    private void
    on_configure_response (Gtk.Dialog inDialog, int inResponse)
    {
        if (inResponse != Gtk.ResponseType.OK && inResponse != Gtk.ResponseType.APPLY)
            return;

        bool updated = false;
        unowned Gtk.SpinButton? nb_jobs = inDialog.get_data ("nb-jobs");
        int jobs = (int)nb_jobs.adjustment.value;

        if (jobs != m_GlobalPrefs.build_job)
        {
            m_GlobalPrefs.build_job = jobs;
            updated = true;
        }

        unowned Gtk.Entry? diff_tool = inDialog.get_data ("entry-diff");
        if (diff_tool.text != m_GlobalPrefs.diff_tool)
        {
            m_GlobalPrefs.diff_tool = diff_tool.text;
            updated = true;
        }

        if (updated)
        {
            m_GlobalPrefs.save ();
        }
    }

    public Gtk.Widget
    configure (Gtk.Dialog inDialog)
    {
        var vbox = new Gtk.VBox (false, 5);

        var frame_build = new Gtk.Frame ("Build");
        frame_build.show ();
        vbox.pack_start (frame_build, false, false, 0);

        var hbox_build = new Gtk.HBox (false, 5);
        hbox_build.show ();
        hbox_build.border_width = 5;
        frame_build.add (hbox_build);

        var label = new Gtk.Label ("Run several commands at a time:");
        label.show ();
        hbox_build.pack_start (label, false, false, 0);

        var spinbutton = new Gtk.SpinButton.with_range (1, 100, 1);
        spinbutton.set_digits(0);
        spinbutton.adjustment.value = (double)m_GlobalPrefs.build_job;
        spinbutton.show ();
        hbox_build.pack_start (spinbutton, false, false, 0);
        inDialog.set_data ("nb-jobs", spinbutton);

        var frame_tools = new Gtk.Frame ("Tools");
        frame_tools.show ();
        vbox.pack_start (frame_tools, false, false, 0);

        var hbox_tools = new Gtk.HBox (false, 5);
        hbox_tools.show ();
        hbox_tools.border_width = 5;
        frame_tools.add (hbox_tools);

        var label_diff = new Gtk.Label ("Diff:");
        label_diff.show ();
        hbox_tools.pack_start (label_diff, false, false, 0);

        var entry_diff = new Gtk.Entry ();
        entry_diff.text = m_GlobalPrefs.diff_tool;
        Geany.Ui.entry_add_clear_icon (entry_diff);
        entry_diff.show ();
        hbox_tools.pack_start (entry_diff, false, false, 0);
        inDialog.set_data ("entry-diff", entry_diff);

        var chooser_diff = new Gtk.FileChooserButton ("Diff", Gtk.FileChooserAction.OPEN);
        chooser_diff.show ();
        chooser_diff.file_set.connect (() => {
            entry_diff.text = chooser_diff.get_filename ();
        });
        hbox_tools.pack_start (chooser_diff, false, false, 0);

        inDialog.response.connect (on_configure_response);

        return vbox;
    }

    public void
    kb_find ()
    {
        unowned Geany.Document? document = Geany.Document.get_current ();
        if (document != null)
        {
            string filename = document.file_name;
            foreach (unowned Prj? prj in m_Projects)
            {
                if (filename.has_prefix (prj.path + "/"))
                {
                    debug ("Launch find in project %s", prj.name);
                    Geany.Search.show_find_in_files_dialog (prj.path);
                    break;
                }
            }
        }
    }

    public void
    kb_configure ()
    {
        unowned Geany.Document? document = Geany.Document.get_current ();
        if (document != null)
        {
            string filename = document.file_name;
            foreach (unowned Prj? prj in m_Projects)
            {
                if (filename.has_prefix (prj.path + "/"))
                {
                    bool ret = m_ConfigureDialog.main ();
                    if (ret)
                    {
                        prj.configure (m_ConfigureDialog.params, m_ConfigureDialog.regenerate);
                    }
                    break;
                }
            }
        }
    }

    public void
    kb_build_all ()
    {
        unowned Geany.Document? document = Geany.Document.get_current ();
        if (document != null)
        {
            string filename = document.file_name;
            debug ("Launch build all for %s", filename);
            foreach (unowned Prj? prj in m_Projects)
            {
                if (filename.has_prefix (prj.path + "/"))
                {
                    prj.build_all ();
                    break;
                }
            }
        }
    }

    public void
    kb_build ()
    {
        unowned Geany.Document? document = Geany.Document.get_current ();
        if (document != null)
        {
            string filename = document.file_name;
            debug ("Launch build for %s", filename);
            foreach (unowned Prj? prj in m_Projects)
            {
                if (filename.has_prefix (prj.path + "/") && prj.build_target_for_filename (filename))
                    break;
            }
        }
    }

    public void
    kb_clean ()
    {
        unowned Geany.Document? document = Geany.Document.get_current ();
        if (document != null)
        {
            string filename = document.file_name;
            debug ("Launch clean all for %s", filename);
            foreach (unowned Prj? prj in m_Projects)
            {
                if (filename.has_prefix (prj.path + "/"))
                {
                    prj.clean_all ();
                    break;
                }
            }
        }
    }

    public void
    kb_diff ()
    {
        unowned Geany.Document? document = Geany.Document.get_current ();
        if (document != null)
        {
            string filename = document.file_name;
            debug ("Launch build for %s", filename);
            foreach (unowned Prj? prj in m_Projects)
            {
                if (filename.has_prefix (prj.path + "/"))
                {
                    try
                    {
                        new Command (prj.path, m_GlobalPrefs.diff_tool + " .");
                    }
                    catch (GLib.Error err)
                    {
                        warning ("Error on launching difftool: %s", err.message);
                    }
                    break;
                }
            }
        }
    }
}
