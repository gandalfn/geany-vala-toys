/* libdevhelp-2.0.vapi generated by vapigen, do not modify. */

[CCode (cprefix = "Dh", lower_case_cprefix = "dh_")]
namespace Dh {
    [CCode (cheader_filename = "devhelp/dh-assistant.h")]
    public class Assistant : Gtk.Window, Atk.Implementor, Gtk.Buildable {
        [CCode (type = "GtkWidget*", has_construct_function = false)]
        public Assistant (Dh.Base @base);
        public bool search (string str);
    }
    [CCode (cheader_filename = "devhelp/dh-assistant-view.h")]
    public class AssistantView : WebKit.WebView, Atk.Implementor, Gtk.Buildable {
        [CCode (type = "GtkWidget*", has_construct_function = false)]
        public AssistantView ();
        public unowned Dh.Base get_base ();
        public bool search (string str);
        public void set_base (Dh.Base @base);
        public bool set_link (Dh.Link link);
    }
    [CCode (cheader_filename = "devhelp/dh-base.h")]
    public class Base : GLib.Object {
        [CCode (has_construct_function = false)]
        public Base ();
        [CCode (type = "GtkWidget*", has_construct_function = false)]
        public Base.assistant (Dh.Base @base);
        public static unowned Dh.Base @get ();
        public unowned Dh.BookManager get_book_manager ();
        public unowned Gtk.Widget get_window ();
        public unowned Gtk.Widget get_window_on_current_workspace ();
        public void quit ();
        [CCode (type = "GtkWidget*", has_construct_function = false)]
        public Base.window (Dh.Base @base);
    }
    [CCode (cheader_filename = "devhelp/dh-book.h")]
    public class Book : GLib.Object {
        [CCode (has_construct_function = false)]
        public Book (string book_path);
        public int cmp_by_name (Dh.Book b);
        public int cmp_by_path (Dh.Book b);
        public int cmp_by_title (Dh.Book b);
        public bool get_enabled ();
        public unowned GLib.List get_keywords ();
        public unowned string get_name ();
        public unowned string get_title ();
        public unowned GLib.Node get_tree ();
        public void set_enabled (bool enabled);
    }
    [CCode (cheader_filename = "devhelp/dh-book-manager.h")]
    public class BookManager : GLib.Object {
        [CCode (has_construct_function = false)]
        public BookManager ();
        public unowned Dh.Book get_book_by_name (string name);
        public unowned GLib.List get_books ();
        public void populate ();
        public void update ();
        public virtual signal void disabled_book_list_updated ();
    }
    [CCode (cheader_filename = "devhelp/dh-book-tree.h")]
    public class BookTree : Gtk.TreeView, Atk.Implementor, Gtk.Buildable {
        [CCode (type = "GtkWidget*", has_construct_function = false)]
        public BookTree (Dh.BookManager book_manager);
        public unowned string get_selected_book_title ();
        public void select_uri (string uri);
        public virtual signal void link_selected (void* p0);
    }
    [CCode (cheader_filename = "devhelp/dh-keyword-model.h")]
    public class KeywordModel : GLib.Object, Gtk.TreeModel {
        [CCode (has_construct_function = false)]
        public KeywordModel ();
        public unowned Dh.Link filter (string str, string book_id);
        public void set_words (Dh.BookManager book_manager);
    }
    [Compact]
    [CCode (cheader_filename = "devhelp/dh-keyword-model.h")]
    public class KeywordModelPriv {
    }
    [Compact]
    [CCode (ref_function = "dh_link_ref", unref_function = "dh_link_unref", type_id = "DH_TYPE_LINK", cheader_filename = "devhelp/dh-link.h")]
    public class Link {
        [CCode (has_construct_function = false)]
        public Link (Dh.LinkType type, string @base, string id, string name, Dh.Link book, Dh.Link page, string filename);
        public static int compare (void* a, void* b);
        public unowned string get_book_id ();
        public unowned string get_book_name ();
        public unowned string get_file_name ();
        public Dh.LinkFlags get_flags ();
        public Dh.LinkType get_link_type ();
        public unowned string get_name ();
        public unowned string get_page_name ();
        public unowned string get_type_as_string ();
        public unowned string get_uri ();
        public void set_flags (Dh.LinkFlags flags);
    }
    [CCode (cheader_filename = "devhelp/dh-search.h")]
    public class Search : Gtk.VBox, Atk.Implementor, Gtk.Buildable, Gtk.Orientable {
        [CCode (type = "GtkWidget*", has_construct_function = false)]
        public Search (Dh.BookManager book_manager);
        public void set_search_string (string str, string? book_id);
        public virtual signal void link_selected (void* link);
    }
    [CCode (cheader_filename = "devhelp/dh-window.h")]
    public class Window : Gtk.Window, Atk.Implementor, Gtk.Buildable {
        [CCode (type = "GtkWidget*", has_construct_function = false)]
        public Window (Dh.Base @base);
        public void focus_search ();
        public void search (string str, string book_id);
        public virtual signal void open_link (string location, Dh.OpenLinkFlags flags);
    }
    [Compact]
    [CCode (cheader_filename = "devhelp/dh-window.h")]
    public class WindowPriv {
    }
    [CCode (cprefix = "DH_ERROR_", has_type_id = false, cheader_filename = "devhelp/dh-error.h")]
    public enum Error {
        FILE_NOT_FOUND,
        MALFORMED_BOOK,
        INVALID_BOOK_TYPE,
        INTERNAL_ERROR
    }
    [CCode (cprefix = "DH_LINK_FLAGS_", has_type_id = false, cheader_filename = "devhelp/dh-link.h")]
    public enum LinkFlags {
        NONE,
        DEPRECATED
    }
    [CCode (cprefix = "DH_LINK_TYPE_", has_type_id = false, cheader_filename = "devhelp/dh-link.h")]
    public enum LinkType {
        BOOK,
        PAGE,
        KEYWORD,
        FUNCTION,
        STRUCT,
        MACRO,
        ENUM,
        TYPEDEF
    }
    [CCode (cprefix = "DH_OPEN_LINK_NEW_", has_type_id = false, cheader_filename = "devhelp/dh-window.h")]
    public enum OpenLinkFlags {
        WINDOW,
        TAB
    }
    [CCode (cheader_filename = "dl-error.h")]
    public static GLib.Quark error_quark ();
}