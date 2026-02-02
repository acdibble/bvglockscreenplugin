#include "bvg_api.h"
#include <curl/curl.h>
#include <json.h>
#include <ctime>
#include <cstring>

static size_t write_callback(void* contents, size_t size, size_t nmemb, void* userp) {
    std::string* str = static_cast<std::string*>(userp);
    str->append(static_cast<char*>(contents), size * nmemb);
    return size * nmemb;
}

static int parse_minutes_until(const char* when_str) {
    if (!when_str) return -1;

    struct tm when_tm = {};
    // Parse ISO 8601 format: 2024-01-15T14:32:00+01:00
    if (strptime(when_str, "%Y-%m-%dT%H:%M:%S", &when_tm) == nullptr) {
        return -1;
    }

    time_t when_time = mktime(&when_tm);
    time_t now = time(nullptr);

    int diff_seconds = static_cast<int>(difftime(when_time, now));
    return diff_seconds / 60;
}

std::vector<Departure> fetch_departures(const std::string& station_id) {
    std::vector<Departure> departures;

    CURL* curl = curl_easy_init();
    if (!curl) return departures;

    std::string url = "https://v6.bvg.transport.rest/stops/" + station_id +
                      "/departures?duration=30&results=8";
    std::string response;

    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 10L);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);

    CURLcode res = curl_easy_perform(curl);
    curl_easy_cleanup(curl);

    if (res != CURLE_OK) return departures;

    json_object* root = json_tokener_parse(response.c_str());
    if (!root) return departures;

    json_object* deps_array = nullptr;
    if (json_object_object_get_ex(root, "departures", &deps_array) &&
        json_object_is_type(deps_array, json_type_array)) {

        int count = json_object_array_length(deps_array);
        for (int i = 0; i < count && i < 8; i++) {
            json_object* dep = json_object_array_get_idx(deps_array, i);

            Departure d;

            json_object* line_obj = nullptr;
            if (json_object_object_get_ex(dep, "line", &line_obj)) {
                json_object* name_obj = nullptr;
                if (json_object_object_get_ex(line_obj, "name", &name_obj)) {
                    d.line = json_object_get_string(name_obj);
                }
            }

            json_object* direction_obj = nullptr;
            if (json_object_object_get_ex(dep, "direction", &direction_obj)) {
                d.direction = json_object_get_string(direction_obj);
            }

            json_object* when_obj = nullptr;
            if (json_object_object_get_ex(dep, "when", &when_obj)) {
                const char* when_str = json_object_get_string(when_obj);
                if (when_str) {
                    d.when = when_str;
                    d.minutes = parse_minutes_until(when_str);
                } else {
                    d.minutes = -1;
                }
            } else {
                d.minutes = -1;
            }

            if (!d.line.empty() && d.minutes >= 0) {
                departures.push_back(d);
            }
        }
    }

    json_object_put(root);
    return departures;
}
