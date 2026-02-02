#ifndef BVG_API_H
#define BVG_API_H

#include <string>
#include <vector>

struct Departure {
    std::string line;
    std::string direction;
    std::string when;
    int minutes;
};

std::vector<Departure> fetch_departures(const std::string& station_id);

#endif
