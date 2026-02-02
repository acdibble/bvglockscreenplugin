#ifndef DISPLAY_H
#define DISPLAY_H

#include <gtk/gtk.h>
#include <vector>
#include "bvg_api.h"

GtkWidget* create_departure_display(GtkWidget* window);
void update_departures(GtkWidget* container, const std::vector<Departure>& departures,
                       const char* station_name);

#endif
