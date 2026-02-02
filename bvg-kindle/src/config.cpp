#include "config.h"
#include <fstream>
#include <cstdlib>

std::string get_config_path() {
    return "/mnt/us/extensions/bvg/config.txt";
}

StationConfig load_config() {
    StationConfig config;
    // Default to Alexanderplatz
    config.station_id = "900100003";
    config.station_name = "Alexanderplatz";

    std::ifstream file(get_config_path());
    if (!file.is_open()) return config;

    std::string line;
    while (std::getline(file, line)) {
        size_t eq_pos = line.find('=');
        if (eq_pos == std::string::npos) continue;

        std::string key = line.substr(0, eq_pos);
        std::string value = line.substr(eq_pos + 1);

        if (key == "station_id") {
            config.station_id = value;
        } else if (key == "station_name") {
            config.station_name = value;
        }
    }

    return config;
}

void save_config(const StationConfig& config) {
    std::ofstream file(get_config_path());
    if (!file.is_open()) return;

    file << "station_id=" << config.station_id << "\n";
    file << "station_name=" << config.station_name << "\n";
}
