// SPDX-License-Identifier: GPL-2.0-or-later
// Tiny REPL over the C bridge, used to smoke-test the engine without the app.

#include "SpeedCrunchEngine.h"

#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <string>

int main(int argc, char** argv)
{
    sc_init();
    // --constants: print the constants list (JSON) and exit.
    if (argc > 1 && std::string(argv[1]) == "--constants") {
        char* out = sc_constants();
        std::printf("%s\n", out);
        sc_free(out);
        return 0;
    }
    // SC_SETTINGS='{"complexNumbers":false}' exercises sc_apply_settings.
    if (const char* json = std::getenv("SC_SETTINGS"))
        sc_apply_settings(json);
    std::string line;
    while (std::getline(std::cin, line)) {
        char* out = sc_evaluate(line.c_str());
        std::printf("%s\n", out);
        sc_free(out);
    }
    return 0;
}
