#include "display.h"
#include <ctime>
#include <cstdio>

static GtkWidget* header_label = nullptr;
static GtkWidget* departures_box = nullptr;

static void clear_container(GtkWidget* container) {
    GList* children = gtk_container_get_children(GTK_CONTAINER(container));
    for (GList* iter = children; iter != nullptr; iter = g_list_next(iter)) {
        gtk_widget_destroy(GTK_WIDGET(iter->data));
    }
    g_list_free(children);
}

static GtkWidget* create_label(const char* text, const char* font, float xalign) {
    GtkWidget* label = gtk_label_new(text);

    PangoFontDescription* font_desc = pango_font_description_from_string(font);
    gtk_widget_modify_font(label, font_desc);
    pango_font_description_free(font_desc);

    gtk_misc_set_alignment(GTK_MISC(label), xalign, 0.5);

    return label;
}

GtkWidget* create_departure_display(GtkWidget* window) {
    GtkWidget* main_vbox = gtk_vbox_new(FALSE, 0);
    gtk_container_set_border_width(GTK_CONTAINER(main_vbox), 20);

    // Header row with station name and time
    GtkWidget* header_hbox = gtk_hbox_new(FALSE, 10);
    header_label = create_label("", "Monospace Bold 24", 0.0);
    gtk_box_pack_start(GTK_BOX(header_hbox), header_label, TRUE, TRUE, 0);
    gtk_box_pack_start(GTK_BOX(main_vbox), header_hbox, FALSE, FALSE, 10);

    // Separator
    GtkWidget* separator = gtk_hseparator_new();
    gtk_box_pack_start(GTK_BOX(main_vbox), separator, FALSE, FALSE, 5);

    // Departures container
    departures_box = gtk_vbox_new(FALSE, 8);
    gtk_box_pack_start(GTK_BOX(main_vbox), departures_box, TRUE, FALSE, 10);

    return main_vbox;
}

void update_departures(GtkWidget* container, const std::vector<Departure>& departures,
                       const char* station_name) {
    // Update header with station name and current time
    time_t now = time(nullptr);
    struct tm* tm_info = localtime(&now);
    char time_str[6];
    strftime(time_str, sizeof(time_str), "%H:%M", tm_info);

    char header_text[256];
    snprintf(header_text, sizeof(header_text), "%-30s %s", station_name, time_str);
    gtk_label_set_text(GTK_LABEL(header_label), header_text);

    // Clear and rebuild departures list
    clear_container(departures_box);

    if (departures.empty()) {
        GtkWidget* no_data = create_label("No departures available", "Monospace 18", 0.5);
        gtk_box_pack_start(GTK_BOX(departures_box), no_data, FALSE, FALSE, 20);
    } else {
        for (const auto& dep : departures) {
            GtkWidget* row = gtk_hbox_new(FALSE, 10);

            // Line name (e.g., "U2", "S5")
            char line_text[8];
            snprintf(line_text, sizeof(line_text), "%-4s", dep.line.c_str());
            GtkWidget* line_label = create_label(line_text, "Monospace Bold 20", 0.0);
            gtk_box_pack_start(GTK_BOX(row), line_label, FALSE, FALSE, 0);

            // Direction
            GtkWidget* dir_label = create_label(dep.direction.c_str(), "Monospace 20", 0.0);
            gtk_box_pack_start(GTK_BOX(row), dir_label, TRUE, TRUE, 0);

            // Time until departure
            char time_text[16];
            if (dep.minutes <= 0) {
                snprintf(time_text, sizeof(time_text), "now");
            } else {
                snprintf(time_text, sizeof(time_text), "%d min", dep.minutes);
            }
            GtkWidget* time_label = create_label(time_text, "Monospace Bold 20", 1.0);
            gtk_widget_set_size_request(time_label, 100, -1);
            gtk_box_pack_end(GTK_BOX(row), time_label, FALSE, FALSE, 0);

            gtk_box_pack_start(GTK_BOX(departures_box), row, FALSE, FALSE, 0);
        }
    }

    gtk_widget_show_all(departures_box);
}
