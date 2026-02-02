#ifndef CONFIG_H
#define CONFIG_H

#include <string>

struct StationConfig {
    std::string station_id;
    std::string station_name;
};

StationConfig load_config();
void save_config(const StationConfig& config);
std::string get_config_path();

#endif
