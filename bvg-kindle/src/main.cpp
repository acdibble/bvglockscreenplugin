#include <gtk/gtk.h>
#include <gdk/gdkkeysyms.h>
#include <cstring>
#include "bvg_api.h"
#include "display.h"
#include "config.h"
#include "kindle.h"

static GtkWidget* main_container = nullptr;
static StationConfig station_config;

static gboolean refresh_departures(gpointer data) {
    std::vector<Departure> departures = fetch_departures(station_config.station_id);
    update_departures(main_container, departures, station_config.station_name.c_str());
    return TRUE;
}

static void on_window_destroy(GtkWidget* widget, gpointer data) {
    allow_sleep();
    gtk_main_quit();
}

static gboolean on_key_press(GtkWidget* widget, GdkEventKey* event, gpointer data) {
    // Allow exit with Escape or 'q'
    if (event->keyval == GDK_Escape || event->keyval == GDK_q) {
        gtk_widget_destroy(widget);
        return TRUE;
    }
    return FALSE;
}

static void show_config_dialog(GtkWidget* parent) {
    GtkWidget* dialog = gtk_dialog_new_with_buttons(
        "Configure Station",
        GTK_WINDOW(parent),
        GTK_DIALOG_MODAL,
        GTK_STOCK_OK, GTK_RESPONSE_OK,
        GTK_STOCK_CANCEL, GTK_RESPONSE_CANCEL,
        NULL);

    GtkWidget* content = gtk_dialog_get_content_area(GTK_DIALOG(dialog));

    GtkWidget* id_hbox = gtk_hbox_new(FALSE, 10);
    GtkWidget* id_label = gtk_label_new("Station ID:");
    GtkWidget* id_entry = gtk_entry_new();
    gtk_entry_set_text(GTK_ENTRY(id_entry), station_config.station_id.c_str());
    gtk_box_pack_start(GTK_BOX(id_hbox), id_label, FALSE, FALSE, 5);
    gtk_box_pack_start(GTK_BOX(id_hbox), id_entry, TRUE, TRUE, 5);
    gtk_box_pack_start(GTK_BOX(content), id_hbox, FALSE, FALSE, 5);

    GtkWidget* name_hbox = gtk_hbox_new(FALSE, 10);
    GtkWidget* name_label = gtk_label_new("Station Name:");
    GtkWidget* name_entry = gtk_entry_new();
    gtk_entry_set_text(GTK_ENTRY(name_entry), station_config.station_name.c_str());
    gtk_box_pack_start(GTK_BOX(name_hbox), name_label, FALSE, FALSE, 5);
    gtk_box_pack_start(GTK_BOX(name_hbox), name_entry, TRUE, TRUE, 5);
    gtk_box_pack_start(GTK_BOX(content), name_hbox, FALSE, FALSE, 5);

    gtk_widget_show_all(dialog);

    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_OK) {
        station_config.station_id = gtk_entry_get_text(GTK_ENTRY(id_entry));
        station_config.station_name = gtk_entry_get_text(GTK_ENTRY(name_entry));
        save_config(station_config);
        refresh_departures(nullptr);
    }

    gtk_widget_destroy(dialog);
}

int main(int argc, char* argv[]) {
    gtk_init(&argc, &argv);

    // Load station configuration
    station_config = load_config();

    // Check for config mode
    bool config_mode = false;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--config") == 0) {
            config_mode = true;
            break;
        }
    }

    // Create main window with Kindle lipc format title
    GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window),
                         "L:A_N:application_ID:com.bvg.departures_PC:T");

    // Set white background for e-ink
    GdkColor white = {0, 0xFFFF, 0xFFFF, 0xFFFF};
    gtk_widget_modify_bg(window, GTK_STATE_NORMAL, &white);

    // Fullscreen
    gtk_window_fullscreen(GTK_WINDOW(window));

    // Connect signals
    g_signal_connect(window, "destroy", G_CALLBACK(on_window_destroy), NULL);
    g_signal_connect(window, "key-press-event", G_CALLBACK(on_key_press), NULL);

    // Create departure display
    main_container = create_departure_display(window);
    gtk_container_add(GTK_CONTAINER(window), main_container);

    // Show window
    gtk_widget_show_all(window);

    // Show config dialog if requested
    if (config_mode) {
        show_config_dialog(window);
    }

    // Prevent device sleep
    prevent_sleep();

    // Initial refresh
    refresh_departures(nullptr);

    // Set up periodic refresh (every 15 seconds)
    g_timeout_add_seconds(15, refresh_departures, nullptr);

    // Full e-ink refresh
    full_refresh();

    // Run main loop
    gtk_main();

    return 0;
}
