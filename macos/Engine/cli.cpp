// SPDX-License-Identifier: GPL-2.0-or-later
// Tiny REPL over the C bridge, used to smoke-test the engine without the app.

#include "SpeedCrunchEngine.h"

#include <cstdio>
#include <iostream>
#include <string>

int main()
{
    sc_init();
    std::string line;
    while (std::getline(std::cin, line)) {
        char* out = sc_evaluate(line.c_str());
        std::printf("%s\n", out);
        sc_free(out);
    }
    return 0;
}
