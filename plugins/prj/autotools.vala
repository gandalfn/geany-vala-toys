/* -*- Mode: Vala; indent-tabs-mode: nil; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * autotools.vala
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

public class GVT.Autotools : Backend
{
    // static methods
    private static string?
    normalize_string (string? inData)
    {
        if (inData == null) return null;

        string res = inData.replace ("\n", " ");
        res = res.replace ("\t", " ");
        res = res.strip ();

        if (res.has_prefix ("[")) res = res.substring (1, res.length - 1);
        if (res.has_suffix ("]")) res = res.substring (0, res.length - 1);

        string old = null;
        while (old != res)
        {
            old = res;
            res = res.replace ("  ", " ");
            res = res.replace ("[", " ");
            res = res.replace ("]", " ");
        }
        res.strip ();

        return res;
    }

    // methods
    public Autotools ()
    {
    }

    private void
    setup_filemonitor (Group inGroup)
    {
        try
        {
            string makefile_am = inGroup.path + "/Makefile.am";
            if (GLib.FileUtils.test (makefile_am, GLib.FileTest.EXISTS))
            {
                GLib.File file = GLib.File.new_for_path (makefile_am);
                inGroup.monitor = file.monitor_file (GLib.FileMonitorFlags.NONE);
                inGroup.monitor.set_data ("group", inGroup);
                inGroup.monitor.changed.connect (on_makefile_am_changed);
            }
        }
        catch (GLib.Error err)
        {
            critical (err.message);
        }
    }

    private void
    on_makefile_am_changed (GLib.FileMonitor inSender, GLib.File inFile, GLib.File? inOtherFile, GLib.FileMonitorEvent inEventType)
    {
        if (!inSender.is_cancelled ())
        {
            if (inEventType == FileMonitorEvent.CHANGES_DONE_HINT)
            {
                unowned Group? group = inSender.get_data ("group");
                if (group != null)
                {
                    refresh_group (group);
                }
            }
        }
    }

    private void
    refresh_group (Group inGroup)
    {
        // Remove all targets and datas
        string[] to_remove = {};
        foreach (unowned Item child in inGroup)
        {
            if (child is Target || child is Data)
            {
                to_remove += child.name;
            }
        }
        foreach (string name in to_remove)
        {
            inGroup.remove (name);
        }

        // Remove all variables
        inGroup.clear_variables ();

        // Reparse makefile.am
        parse_file_am (inGroup, inGroup.path + "/Makefile.am");
        parse_targets (inGroup);
        parse_datas (inGroup);

        inGroup.updated ();
    }

    private string
    resolv_project_variable (Project inProject, string inVal)
    {
        string ret = inVal.strip ();

        try
        {
            GLib.Regex re = new GLib.Regex ("""([^\@]*)\@([^\@]+)\@([^\@]*)""");
            GLib.MatchInfo match;

            if (re.match (ret, RegexMatchFlags.NEWLINE_ANY, out match))
            {
                unowned Variable? resolv = inProject.variables.search<string> (match.fetch (2), (v, k) => {
                    return GLib.strcmp (v.name, k);
                });
                if (resolv != null)
                {
                    ret = match.fetch (1) + resolv_project_variable (inProject, resolv.val) + match.fetch (3);
                }
                else
                {
                    ret = match.fetch (1) + match.fetch (2) + match.fetch (3);
                }
            }
        }
        catch (GLib.Error err)
        {
            warning ("Error on resolving %s: %s", inVal, err.message);
        }

        return ret;
    }

    private string
    resolv_variable (Group inGroup, string inVal)
    {
        string ret = inVal.strip ();

        try
        {
            var re = new GLib.Regex ("""^([^\$]*)\$\(([^\:]+)\:([^\=]+)\=([^\)]+)\)(.*)""");
            GLib.MatchInfo match;
            if (re.match (ret, RegexMatchFlags.NEWLINE_ANY, out match))
            {
                ret = match.fetch(1) + resolv_variable (inGroup, "$(" + match.fetch(2) + ")") + match.fetch(4);
            }
            else
            {
                re = new GLib.Regex ("""^([^\$]*)\$(\(|\{)([^\)\}]+)(\)|\})(.*)""");

                if (re.match (ret, RegexMatchFlags.NEWLINE_ANY, out match))
                {
                    unowned Variable? resolv = inGroup.variables.search<string> (match.fetch (3), (v, k) => {
                        return GLib.strcmp (v.name, k);
                    });
                    if (resolv != null)
                    {
                        ret = match.fetch (1) + resolv_variable (inGroup, resolv.val) + match.fetch (5);
                    }
                    else
                    {
                        ret = "";
                    }
                }
                else if (ret.has_prefix ("$"))
                {
                    ret = "";
                }
            }
        }
        catch (GLib.Error err)
        {
            warning ("Error on resolving %s: %s", inVal, err.message);
        }

        return ret;
    }

    private void
    parse_targets (Group inGroup)
    {
        foreach (unowned Variable variable in inGroup.variables)
        {
            TargetType type = TargetType.UNKNOWN;

            if (variable.name.has_suffix ("_LTLIBRARIES") ||
                variable.name.has_suffix ("_LIBRARIES"))
                type = TargetType.LIBRARY;
            else if (variable.name.has_suffix ("_PROGRAMS"))
                type = TargetType.EXECUTABLE;

            if (type != TargetType.UNKNOWN)
            {
                string[] targets = variable.val.split (" ");
                foreach (unowned string target in targets)
                {
                    string target_name = target.strip ();
                    if (target_name.length > 0)
                    {
                        Target trg = new Target (inGroup, type, resolv_project_variable (inGroup.project, target_name));

                        string name = target_name.replace (".", "_").replace ("-", "_").replace ("/", "_");
                        unowned Variable? var_sources = inGroup.variables.search<string> (name + "_SOURCES", (v, k) => {
                            return GLib.strcmp (v.name, k);
                        });
                        if (var_sources != null)
                        {
                            string[] sources = var_sources.val.split (" ");
                            foreach (unowned string source in sources)
                            {
                                var source_name = source.strip ();
                                if (source_name.length > 0)
                                {
                                    Source src = new Source (trg, source_name);
                                    trg.add (src);
                                }
                            }
                        }

                        unowned Variable? var_valasources = inGroup.variables.search<string> (name + "_VALASOURCES", (v, k) => {
                            return GLib.strcmp (v.name, k);
                        });
                        if (var_valasources != null)
                        {
                            string[] valasources = var_valasources.val.split (" ");
                            foreach (unowned string valasource in valasources)
                            {
                                var valasource_name = valasource.strip ();
                                if (valasource_name.length > 0)
                                {
                                    Source src = new Source (trg, valasource_name);
                                    trg.add (src);
                                }
                            }
                        }

                        unowned Variable? var_headers = inGroup.variables.search<string> (name + "_HEADERS", (v, k) => {
                            return GLib.strcmp (v.name, k);
                        });
                        if (var_headers != null)
                        {
                            string[] headers = var_headers.val.split (" ");
                            foreach (unowned string header in headers)
                            {
                                var header_name = header.strip ();
                                if (header_name.length > 0)
                                {
                                    Source src = new Source (trg, header_name);
                                    trg.add (src);
                                }
                            }
                        }

                        inGroup.add (trg);
                    }
                }
            }
        }
    }

    private void
    parse_datas (Group inGroup)
    {
        foreach (unowned Variable variable in inGroup.variables)
        {
            if (variable.name == "EXTRA_DIST" || variable.name.has_suffix ("_DATA"))
            {
                Data data_group = new Data (inGroup, "");
                string[] datas = variable.val.split (" ");
                foreach (unowned string data in datas)
                {
                    string data_name = data.strip ();
                    if (data_name.length > 0)
                    {
                        Data dt = new Data (data_group, data_name);
                        data_group.add (dt);
                    }
                }
                if (data_group.length > 0) inGroup.add (data_group);
            }
        }
    }

    private void
    parse_file_am (Group inGroup, string inFilename)
    {
        try
        {
            GLib.MappedFile file = new GLib.MappedFile (inFilename, false);
            string[] lines = ((string)file.get_contents ()).split ("\n");
            string tmp = null;

            foreach (string line in lines)
            {
                if (line.has_prefix ("include "))
                {
                    string[] paths = line.substring ("include ".length).split ("/");
                    int cpt = 0;
                    foreach (string p in paths)
                    {
                        paths[cpt] = resolv_variable (inGroup, p);
                        ++cpt;
                    }
                    string filename = string.joinv ("/", paths);
                    parse_file_am (inGroup, filename);
                    continue;
                }

                if (tmp == null)
                {
                    tmp = normalize_string (line);
                }
                else
                {
                    tmp += " " + normalize_string (line);
                }

                if (tmp.has_suffix ("\\"))
                {
                    tmp = tmp.substring (0, tmp.length - 1);
                    continue;
                }

                if (tmp.has_prefix ("#") || tmp == "")
                {
                    tmp = null;
                    continue;
                }

                bool append = false;
                string[] toks = tmp.split ("=", 2);


                if (toks.length < 2) {
                    tmp = null;
                    continue;
                }

                if (toks[0].has_suffix ("+"))
                {
                    append = true;
                    toks[0] = toks[0].substring (0, toks[0].length - 1);
                }
                string[] lhs = toks[0].split (" ");
                string[] rhs = toks[1].split (" ");

                foreach (string lh in lhs)
                {
                    if (lh == null || lh == "")
                        continue;

                    string name = lh.strip ();

                    if (append)
                    {
                        unowned Variable? resolv = inGroup.variables.search<string> (name, (v, k) => {
                            return GLib.strcmp (v.name, k);
                        });
                        if (resolv != null)
                        {
                            int cpt = 0;
                            foreach (string rh in rhs)
                            {
                                rhs[cpt] = resolv_variable (inGroup, rh);
                                ++cpt;
                            }
                            resolv.val += string.joinv (" ", rhs);
                        }
                        else
                        {
                            append = false;
                        }
                    }
                    if (!append)
                    {
                        var variable = new Variable(inGroup, name);
                        int cpt = 0;
                        foreach (string rh in rhs)
                        {
                            rhs[cpt] = resolv_variable (inGroup, rh);
                            ++cpt;
                        }
                        variable.val = string.joinv (" ", rhs);
                        inGroup.variables.insert (variable);
                    }

                }

                tmp = null;
            }
        }
        catch (GLib.Error err)
        {
            warning ("Error on parsing %s: %s", inFilename, err.message);
        }
    }

    private void
    parse_makefile (Project inProject, string inMakefile)
    {
        if (GLib.Path.get_basename (inMakefile) == "Makefile" &&
            GLib.FileUtils.test (inProject.path + "/" + inMakefile + ".am", GLib.FileTest.EXISTS))
        {
            string groups_name = GLib.Path.get_dirname (inMakefile);

            if (groups_name == ".")
            {
                parse_file_am (inProject, inProject.path + "/Makefile.am");
                parse_targets (inProject);
                parse_datas (inProject);
            }
            else
            {
                string[] groups = groups_name.split ("/");
                if (groups.length > 0)
                {
                    string group_name = groups[groups.length - 1];
                    unowned Node? parent = inProject;

                    for (int cpt = 0; cpt < groups.length - 1; ++cpt)
                    {
                        unowned Item? item = parent [groups [cpt]];
                        if (item is Node) parent = (Node?)item;
                    }

                    if (parent == inProject && group_name != groups_name)
                    {
                        group_name = groups_name;
                    }

                    Group group = new Group (parent, group_name);
                    parent.add (group);
                    setup_filemonitor (group);
                    parse_file_am (group, group.path + "/Makefile.am");
                    parse_targets (group);
                    parse_datas (group);
                }
            }
        }
    }

    private Project?
    parse_configure (string inConfigure)
    {
        Project project = null;

        try
        {
            GLib.MappedFile file = new GLib.MappedFile (inConfigure, false);

            // Extract project name and version
            GLib.Regex reg = new GLib.Regex ("""AC_INIT\(([^\\,\)]+),([^\\,\)]+)(,[^\)]*)?\)""", RegexCompileFlags.MULTILINE);
            GLib.MatchInfo match;
            string name = null;
            string version = null;

            if (reg.match ((string)file.get_contents (), RegexMatchFlags.NEWLINE_ANY, out match))
            {
                name = match.fetch (1);
                version = match.fetch (2);
            }
            else
            {
                reg = new GLib.Regex ("""AC_INIT\(([^\\,\)]+)(,[^\)]*)?\)""", RegexCompileFlags.MULTILINE);
                if (reg.match ((string)file.get_contents (), RegexMatchFlags.NEWLINE_ANY, out match))
                {
                    name = match.fetch (1);
                }
            }

            if (name == null) return null;

            project = new Project (normalize_string (name),
                                   version != null ? normalize_string (version) : null,
                                   GLib.Path.get_dirname (inConfigure));

            // Extract m4define
            reg = new GLib.Regex ("""m4_define\(([^\,]+),([^\)]+)\)""");
            var m4defines = new Set<Variable> ();
            m4defines.compare_func = Variable.compare;

            if (reg.match ((string)file.get_contents (), RegexMatchFlags.NEWLINE_ANY, out match))
            {
                do
                {
                    string vname = normalize_string (match.fetch (1));
                    var variable = new Variable (project, vname);
                    variable.val = normalize_string (match.fetch (2).strip ());
                    m4defines.insert (variable);
                } while (match.next ());
            }

            // Try to resolv m4 define on project name
            unowned Variable? resolv = m4defines.search<string> (name, (v, k) => {
                return GLib.strcmp (v.name, k);
            });
            if (resolv != null)
            {
                project.name = resolv.val;
            }

            // Try to resolv m4 define on project version
            string[] vs = project.version.split (".");
            int i = 0;
            foreach (unowned string v in vs)
            {
                unowned Variable? r = m4defines.search<string> (v, (v, k) => {
                    return GLib.strcmp (v.name, k);
                });
                if (r != null)
                {
                    vs[i] = r.val;
                }
                i++;
            }
            project.version = string.joinv (".", vs);

            //Extract AC_SUBST variables
            reg = new GLib.Regex ("""AC_SUBST\(([^\)]*)\)""");
            if (reg.match ((string)file.get_contents (), RegexMatchFlags.NEWLINE_ANY, out match))
            {
                do
                {
                    string vname = normalize_string (match.fetch (1));
                    var re_val = new GLib.Regex (vname + """=(.*)""");
                    GLib.MatchInfo match_val;
                    if (re_val.match ((string)file.get_contents (), RegexMatchFlags.NEWLINE_ANY, out match_val))
                    {
                        var variable = new Variable (project, vname);
                        string val = normalize_string (match_val.fetch (1));
                        string[] vals = val.split(" ");
                        int cpt = 0;
                        foreach (unowned string v in vals)
                        {
                            vals[cpt] = resolv_variable (project, v);
                            cpt++;
                        }
                        variable.val = string.joinv (" ", vals);
                        project.variables.insert (variable);
                    }
                } while (match.next ());
            }

            //Extract AC_CONFIG_FILES
            reg = new GLib.Regex ("""AC_CONFIG_FILES\(\[([^\\\]]*)\]\)""", RegexCompileFlags.MULTILINE);
            bool res = reg.match ((string)file.get_contents (), RegexMatchFlags.NEWLINE_ANY, out match);
            if (!res)
            {
                reg = new GLib.Regex ("""AC_OUTPUT\(\[([^\\\]]*)\]\)""", RegexCompileFlags.MULTILINE);
                res = reg.match ((string)file.get_contents (), RegexMatchFlags.NEWLINE_ANY, out match);
            }
            if (res)
            {
                // Sort makefile list
                string tmp = normalize_string (match.fetch (1));
                string[] makefiles = tmp.split(" ");
                Set<unowned string> sorted_makefiles = new Set<unowned string> ();
                sorted_makefiles.compare_func = (a, b) => {
                    if (a.length < b.length)
                        return -1;
                    if (a.length > b.length)
                        return 1;
                    return GLib.strcmp (a, b);
                };

                foreach (unowned string makefile in makefiles)
                {
                    sorted_makefiles.insert (makefile);
                }

                foreach (unowned string makefile in sorted_makefiles)
                {
                    parse_makefile (project, makefile);
                }
            }
        }
        catch (GLib.Error err)
        {
            project = null;
            GLib.critical (err.message);
        }

        return project;
    }

    public override Project?
    parse (string inPath)
    {
        Project project = null;
        string configure_in = inPath + "/configure.in";
        string configure_ac = inPath + "/configure.ac";
        unowned string? configure = null;

        if (GLib.FileUtils.test (configure_in, GLib.FileTest.EXISTS))
            configure = configure_in;
        else if (GLib.FileUtils.test (configure_ac, GLib.FileTest.EXISTS))
            configure = configure_ac;

        if (configure != null)
        {
            project = parse_configure (configure);
        }

        return project;
    }

    public override bool
    configure (Project inProject, string inParams, bool inRegenerate)
    {
        bool ret = false;
        string configure = inRegenerate ? "./autogen.sh" : "./configure";

        if (GLib.FileUtils.test (inProject.path + "/" + configure, GLib.FileTest.EXISTS))
        {
            try
            {
                Command cmd = new Command (inProject.path, configure + " " + inParams);
                cmd.output.connect ((s) => {
                    message (s);
                });
                cmd.error.connect ((s) => {
                    error_message (s);
                });
                cmd.completed.connect ((r) => {
                    cmd = null;
                    completed (configure, r);
                });
                ret = true;
            }
            catch (GLib.Error err)
            {
                critical (err.message);
            }
        }

        return ret;
    }

    public override bool
    build (string inPath, string inParams)
    {
        bool ret = false;

        if (GLib.FileUtils.test (inPath + "/Makefile", GLib.FileTest.EXISTS))
        {
            try
            {
                Command cmd = new Command (inPath, "make " + inParams);
                cmd.output.connect ((s) => {
                    message (s);
                });
                cmd.error.connect ((s) => {
                    error_message (s);
                });
                cmd.completed.connect ((r) => {
                    cmd = null;
                    completed ("make " + inParams, r);
                });
                ret = true;
            }
            catch (GLib.Error err)
            {
                critical (err.message);
            }
        }

        return ret;
    }

    public override bool
    clean (string inPath)
    {
        bool ret = false;

        if (GLib.FileUtils.test (inPath + "/Makefile", GLib.FileTest.EXISTS))
        {
            try
            {
                Command cmd = new Command (inPath, "make clean");
                cmd.output.connect ((s) => {
                    message (s);
                });
                cmd.error.connect ((s) => {
                    error_message (s);
                });
                cmd.completed.connect ((r) => {
                    cmd = null;
                    completed ("make clean", r);
                });
                ret = true;
            }
            catch (GLib.Error err)
            {
                critical (err.message);
            }
        }

        return ret;
    }
}
