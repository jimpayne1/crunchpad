# SPDX-License-Identifier: GPL-2.0-or-later
#
# Builds the upstream SpeedCrunch math/evaluator core as a static library that
# depends only on QtCore, plus the C bridge consumed by the SwiftUI app.

cmake_minimum_required(VERSION 3.21)
set(CMAKE_OSX_DEPLOYMENT_TARGET 15.0 CACHE STRING "")
project(SpeedCrunchEngine LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core)

set(SC_SRC ${CMAKE_CURRENT_LIST_DIR}/../../src)

file(GLOB FLOATNUM_SOURCES ${SC_SRC}/math/floatnum/*.c)

add_library(scengine STATIC
    ${FLOATNUM_SOURCES}
    ${SC_SRC}/math/number.c
    ${SC_SRC}/math/hmath.cpp
    ${SC_SRC}/math/cmath.cpp
    ${SC_SRC}/math/cnumberparser.cpp
    ${SC_SRC}/math/rational.cpp
    ${SC_SRC}/math/quantity.cpp
    ${SC_SRC}/core/book.cpp
    ${SC_SRC}/core/pageserver.cpp
    ${SC_SRC}/core/constants.cpp
    ${SC_SRC}/core/evaluator.cpp
    ${SC_SRC}/core/functions.cpp
    ${SC_SRC}/core/mathdsl.cpp
    ${SC_SRC}/core/numberformatter.cpp
    ${SC_SRC}/core/opcode.cpp
    ${SC_SRC}/core/units.cpp
    ${SC_SRC}/core/unitdisplayformat.cpp
    ${SC_SRC}/core/userfunction.cpp
    ${SC_SRC}/core/userunit.cpp
    ${SC_SRC}/core/variable.cpp
    ${SC_SRC}/core/book.h
    ${SC_SRC}/core/pageserver.h
    ${SC_SRC}/core/constants.h
    ${SC_SRC}/core/evaluator.h
    ${SC_SRC}/core/functions.h
    settings_mac.cpp
    bridge.cpp
)

target_include_directories(scengine
    PUBLIC include
    PRIVATE ${SC_SRC} ${SC_SRC}/math ${SC_SRC}/core)
target_compile_definitions(scengine PRIVATE QT_NO_DEBUG_OUTPUT QT_NO_WARNING_OUTPUT)
target_link_libraries(scengine PUBLIC Qt6::Core)

add_executable(sccli cli.cpp)
target_link_libraries(sccli scengine)
