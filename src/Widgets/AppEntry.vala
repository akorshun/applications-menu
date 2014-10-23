// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//
//  Copyright (C) 2011-2012 Giulio Collura
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

public class Slingshot.Widgets.AppEntry : Gtk.Button {
    public Gtk.Label app_label;
    private Gdk.Pixbuf icon;
    private new Gtk.Image image;

    public string exec_name;
    public string app_name;
    public string desktop_id;
    public int icon_size;
    public string desktop_path;

    public signal void app_launched ();

    private bool dragging = false; //prevent launching

    private Backend.App application;
    private unowned SlingshotView view;

    public AppEntry (Backend.App app, SlingshotView view) {
        this.view = view;
        Gtk.TargetEntry dnd = {"text/uri-list", 0, 0};
        Gtk.drag_source_set (this, Gdk.ModifierType.BUTTON1_MASK, {dnd},
                             Gdk.DragAction.COPY);

        desktop_id = app.desktop_id;
        desktop_path = app.desktop_path;

        application = app;
        app_name = app.name;
        tooltip_text = app.description;
        exec_name = app.exec;
        icon_size = Slingshot.settings.icon_size;
        icon = app.icon;

        get_style_context ().add_class ("app");

        app_label = new Gtk.Label (app_name);
        app_label.halign = Gtk.Align.CENTER;
        app_label.justify = Gtk.Justification.CENTER;
        app_label.set_line_wrap (true);
        app_label.lines = 2;
        app_label.set_single_line_mode (false);
        app_label.set_ellipsize (Pango.EllipsizeMode.END);

        image = new Gtk.Image.from_pixbuf (icon);
        image.icon_size = icon_size;
        image.margin_top = 12;

        var grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.VERTICAL;
        grid.row_spacing = 6;
        grid.expand = true;
        grid.halign = Gtk.Align.CENTER;
        grid.add (image);
        grid.add (app_label);

        add (grid);
        set_size_request (Pixels.ITEM_SIZE, Pixels.ITEM_SIZE);

        this.clicked.connect (launch_app);

        this.button_release_event.connect ((e) => {
            if (e.button == Gdk.BUTTON_SECONDARY) {
                show_menu ();
                return true;
            }
            return false;
        });

        this.drag_begin.connect ( (ctx) => {
            this.dragging = true;
            Gtk.drag_set_icon_pixbuf (ctx, icon, 0, 0);
        });

        this.drag_end.connect ( () => {
            this.dragging = false;
        });

        this.drag_data_get.connect ( (ctx, sel, info, time) => {
            sel.set_uris ({File.new_for_path (desktop_path).get_uri ()});
        });

        app.icon_changed.connect (() => {
            icon = app.icon;
            image.set_from_pixbuf (icon);
        });

    }

    public override void get_preferred_width (out int minimum_width, out int natural_width) {
        minimum_width = Pixels.ITEM_SIZE;
        natural_width = Pixels.ITEM_SIZE;
    }

    public override void get_preferred_height (out int minimum_height, out int natural_height) {
        minimum_height = Pixels.ITEM_SIZE;
        natural_height = Pixels.ITEM_SIZE;
    }

    public void launch_app () {
        application.launch ();
        app_launched ();
    }

    private void show_menu () {
        // Display the apps static quicklist items in a popover menu
        if (application.actions == null) {
            try {
                application.init_actions ();
            } catch (KeyFileError e) {
                critical ("%s: %s", desktop_path, e.message);
            }
        }

        var menu = new PopoverMenu ();
        foreach (var action in application.actions) {
            var values = application.actions_map.get (action).split (";;");
            Gdk.Pixbuf? icon = null;
            var flags = Gtk.IconLookupFlags.FORCE_SIZE;

            try {
                if (values.length > 1 && values[1] != "" && values[1] != null)
                    icon = Slingshot.icon_theme.load_icon (values[1], 16, flags);
            } catch (Error e) {
                error ("Error loading quicklist icon");
            }

            var menuitem = new Widgets.PopoverMenuItem (action, icon);
            menu.add_menu_item (menuitem);

            menuitem.activated.connect (() => {
                try {
                    AppInfo.create_from_commandline (values[0], null, AppInfoCreateFlags.NONE).launch (null, null);
                    app_launched ();
                } catch (Error e) {
                    critical ("%s: %s", desktop_path, e.message);
                }
            });
        }

        if (menu.get_size () > 0)
            view.show_popover_menu (menu, this);
    }

}