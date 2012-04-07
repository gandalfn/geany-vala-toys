/* -*- Mode: Vala; indent-tabs-mode: nil; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * command.vala
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

public class GVT.Command : GLib.Object
{
    // properties
    private GLib.IOChannel m_Stdout;
    private GLib.IOChannel m_Stderr;

    // signals
    public signal void output (string inMessage);
    public signal void error (string inMessage);
    public signal void completed (int inStatus);

    // methods
    public Command (string inPath, string inCommand) throws GLib.Error
    {
        string[] argv = {};
        argv += "/bin/sh";
        argv += "-c";
        argv += inCommand;
        argv += null;

        GLib.Pid pid;
        int fd_stdout, fd_stderr;

        if (GLib.Process.spawn_async_with_pipes (inPath, argv, null,
                                                 GLib.SpawnFlags.DO_NOT_REAP_CHILD,
                                                 null, out pid,
                                                 null, out fd_stdout, out fd_stderr))
        {
            m_Stdout = new GLib.IOChannel.unix_new (fd_stdout);
            m_Stdout.set_flags (m_Stdout.get_flags () | GLib.IOFlags.NONBLOCK);
            m_Stdout.set_encoding (null);
            m_Stdout.set_close_on_unref (true);
            m_Stdout.add_watch (GLib.IOCondition.IN | GLib.IOCondition.HUP, on_output_message);

            m_Stderr = new GLib.IOChannel.unix_new (fd_stderr);
            m_Stderr.set_flags (m_Stderr.get_flags () | GLib.IOFlags.NONBLOCK);
            m_Stderr.set_encoding (null);
            m_Stderr.set_close_on_unref (true);
            m_Stderr.add_watch (GLib.IOCondition.IN | GLib.IOCondition.HUP, on_output_message);

            GLib.ChildWatch.add (pid, on_child_finished);
        }
        else
        {
            critical ("error on spawn %s", inCommand);
        }
    }

    private void
    on_child_finished (GLib.Pid inPid, int inStatus)
    {
        completed (inStatus);
    }

    private bool
    on_output_message (GLib.IOChannel inChannel, GLib.IOCondition inCondition)
    {
        if (inCondition == GLib.IOCondition.HUP)
            return false;
        try
        {
            string message;
            size_t length, terminator;
            if (inChannel.read_line (out message, out length, out terminator) == GLib.IOStatus.NORMAL)
            {
                ((char[])message)[terminator] = '\0';
                if (inChannel == m_Stdout)
                    output (message);
                else
                    error (message);
            }
        }
        catch (GLib.Error err)
        {
            critical (err.message);
        }

        return true;
    }
}
