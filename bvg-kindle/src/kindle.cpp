#include "kindle.h"
#include <cstdlib>

void prevent_sleep() {
    system("lipc-set-prop com.lab126.powerd preventScreenSaver 1");
}

void allow_sleep() {
    system("lipc-set-prop com.lab126.powerd preventScreenSaver 0");
}

void full_refresh() {
    system("eips -c");
}
