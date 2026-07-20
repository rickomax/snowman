cmake_minimum_required(VERSION 3.7)
project(Decompiler C CXX)

enable_testing()

# Show what's going on when running make.
#set(CMAKE_VERBOSE_MAKEFILE ON)

# Generate compilation database for YouCompleteMe.
set(CMAKE_EXPORT_COMPILE_COMMANDS YES)

# Link against qtmain.lib automatically.
cmake_policy(SET CMP0020 NEW)

#
# Include additional scripts.
#
set(CMAKE_MODULE_PATH  ${CMAKE_MODULE_PATH}  ${CMAKE_SOURCE_DIR}/../modules)

#
# Specify namespace with which Qt has been configured.
#
set(QT_NAMESPACE "" CACHE STRING "Qt Namespace")

set(NC_M32 OFF CACHE STRING "Make a 32-bit build")

#
# Profiling.
#
set(ENABLE_PROFILING FALSE CACHE BOOL "Enable profiling")

#
# Optimize and generate debug info by default.
#
if(NOT CMAKE_BUILD_TYPE)
    get_property(helpstring CACHE CMAKE_BUILD_TYPE PROPERTY HELPSTRING)
    set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "${helpstring}" FORCE)
    unset(helpstring)
endif()

if(${CMAKE_CXX_COMPILER_ID} MATCHES "Clang")

    #
    # Options for Clang.
    #

    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")
    add_definitions(-Wall -Wextra)

    if(${NC_M32})
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -m32")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -m32")
    endif()

elseif(${CMAKE_CXX_COMPILER_ID} MATCHES "GNU")

    #
    # Options for GCC.
    #

    if("${CMAKE_CXX_COMPILER_VERSION}" VERSION_LESS "4.7")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++0x")
    else()
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")
    endif()

    add_definitions(-Wall -Wextra)
    add_definitions(-fshow-column)

    # Boost often violates this :-(
    add_definitions(-fno-strict-aliasing)

    # GCC warns about optimizing expressions like x <= x + 1 also when these expressions
    # arise only after inlining, so there is sometimes no decent way to kill the warning.
    add_definitions(-Wno-strict-overflow)

    # GCC produces false positives with boost::optional
    add_definitions(-Wno-maybe-uninitialized)

    if(${ENABLE_PROFILING})
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -pg")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pg")
        set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -pg")
    endif()

    if(${NC_M32})
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -m32")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -m32")
    endif()

elseif(${MSVC})

    #
    # Options for MSVC.
    #

    # Target Windows XP.
    add_definitions(-DWINVER=0x0501)
endif()

#
# Sanitizers.
#
set(ENABLE_SANITIZER FALSE CACHE BOOL "Enable sanitizer")

if(${ENABLE_SANITIZER})
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fsanitize=address -fsanitize=leak -fsanitize=undefined")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsanitize=address -fsanitize=leak -fsanitize=undefined")
endif()

# Add source dir to includes.
include_directories(${CMAKE_SOURCE_DIR} ${CMAKE_SOURCE_DIR}/3rd-party)

# Find Boost (downloading the header-only distribution automatically if it is
# not installed on the system). See modules/BoostDependency.cmake.
include(BoostDependency)
include_directories(SYSTEM ${Boost_INCLUDE_DIRS})

# If CMake was not told where Qt lives, try to discover it from a qmake on the
# PATH. This makes the common "Qt is installed but its cmake config dir is not
# on CMAKE_PREFIX_PATH" case work out of the box.
if(NOT NC_QT5 AND NOT Qt5_DIR AND NOT Qt5Core_DIR AND NOT Qt6_DIR AND NOT DEFINED ENV{QTDIR})
    find_program(NC_QMAKE_EXECUTABLE NAMES qmake qmake-qt5 qmake6)
    if(NC_QMAKE_EXECUTABLE)
        execute_process(
            COMMAND "${NC_QMAKE_EXECUTABLE}" -query QT_INSTALL_PREFIX
            OUTPUT_VARIABLE NC_QT_PREFIX
            OUTPUT_STRIP_TRAILING_WHITESPACE
            RESULT_VARIABLE NC_QMAKE_RESULT)
        if(NC_QMAKE_RESULT EQUAL 0 AND NC_QT_PREFIX)
            message(STATUS "Qt: discovered installation at ${NC_QT_PREFIX} (via ${NC_QMAKE_EXECUTABLE}).")
            list(APPEND CMAKE_PREFIX_PATH "${NC_QT_PREFIX}")
        endif()
    endif()
endif()

# Choose which Qt version to look for. Prefer Qt5; fall back to Qt4 only when
# Qt4 is actually available, so that a missing/misconfigured Qt5 produces a
# helpful Qt5 error rather than a confusing Qt4 one.
if(NOT DEFINED NC_QT5)
    set(helpstring "Build using Qt5 rather than Qt4.")
    find_package(Qt5Core QUIET)
    if(Qt5Core_FOUND)
        set(NC_QT5 TRUE CACHE BOOL ${helpstring})
    else()
        find_package(Qt4 QUIET)
        if(Qt4_FOUND OR QT4_FOUND)
            set(NC_QT5 FALSE CACHE BOOL ${helpstring})
        else()
            set(NC_QT5 TRUE CACHE BOOL ${helpstring})
        endif()
    endif()
    unset(helpstring)
endif()

if(NC_QT5)
    # Find Qt5.
    find_package(Qt5Core QUIET)
    find_package(Qt5Widgets QUIET)
    if(NOT Qt5Core_FOUND OR NOT Qt5Widgets_FOUND)
        message(FATAL_ERROR
            "Qt5 (Core and Widgets) was not found, and Snowman needs Qt to build.\n"
            "Point CMake at your Qt installation in one of these ways:\n"
            "  * add Qt's bin directory to PATH (so qmake can be found), or\n"
            "  * -DCMAKE_PREFIX_PATH=<qt-prefix>   e.g. C:/Qt/5.15.2/msvc2019_64\n"
            "                                      or  $HOME/Qt/5.15.2/gcc_64, or\n"
            "  * -DQt5_DIR=<dir containing Qt5Config.cmake>.\n"
            "To build against Qt4 instead, configure with -DNC_QT5=OFF.\n"
            "See doc/build.asciidoc, section \"Obtaining the Dependencies\".")
    endif()

    set(CMAKE_AUTOMOC ON)

    macro(qt4_wrap_cpp)
    endmacro()

    set(NC_QT_CORE Qt5::Core)
    set(NC_QT_WIDGETS Qt5::Widgets)
else()
    # Find Qt4.
    find_package(Qt4 QUIET QtCore QtGui)
    if(NOT QT4_FOUND AND NOT Qt4_FOUND)
        message(FATAL_ERROR
            "Qt4 was not found (NC_QT5=OFF was requested or Qt5 was unavailable).\n"
            "Install Qt4 and point CMake at it via CMAKE_PREFIX_PATH, or build\n"
            "against Qt5 by configuring with -DNC_QT5=ON and a Qt5 installation.\n"
            "See doc/build.asciidoc, section \"Obtaining the Dependencies\".")
    endif()
    include(${QT_USE_FILE})

    # Too lazy to filter the right libraries from ${QT_LIBRARIES}.
    set(NC_QT_CORE ${QT_LIBRARIES})
    set(NC_QT_WIDGETS ${QT_LIBRARIES})

    # This is used to produce standalone bundles on Windows.
    include(DeployQt4)
endif()

if(QT_NAMESPACE)
    add_definitions(-DQT_NAMESPACE=${QT_NAMESPACE})
endif()

# Find IDA SDK.
find_package(IDA)

# Option for building IDA plug-in.
set(IDA_PLUGIN_ENABLED ${IDA_SDK_DIR} CACHE BOOL "Build IDA plug-in.")

# Position-independent code is necessary for the IDA plug-in.
if(${IDA_PLUGIN_ENABLED})
    set(CMAKE_C_FLAGS   "${CMAKE_C_FLAGS}   ${CMAKE_C_COMPILE_OPTIONS_PIC}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CMAKE_CXX_COMPILE_OPTIONS_PIC}")
endif()

# CMake rocks!
if(${IDA_PLUGIN_ENABLED})
    set(IDA_PLUGIN_DISABLED NO)
else()
    set(IDA_PLUGIN_DISABLED YES)
endif()

# Find x64dbg SDK.
find_package(x64dbg)

# Option for building x64dbg module.
set(X64DBG_MODULE_ENABLED ${X64DBG_SDK_FOUND} CACHE BOOL "Build x64dbg module.")

# Option for making multithreaded builds.
set(NC_USE_THREADS ${IDA_PLUGIN_DISABLED} CACHE BOOL "Enable threads.")

configure_file("${CMAKE_CURRENT_SOURCE_DIR}/nc/config.h.in" "${CMAKE_CURRENT_BINARY_DIR}/nc/config.h")
include_directories(${CMAKE_CURRENT_BINARY_DIR})

add_subdirectory(nc)
add_subdirectory(nocode)
add_subdirectory(snowman)
if(${IDA_PLUGIN_ENABLED})
    add_subdirectory(ida-plugin)
endif()

# Only build x64dbg when using MSVC (no support for other compilers in the SDK).
if(X64DBG_MODULE_ENABLED AND MSVC)
    add_subdirectory(x64dbg-module)
endif()

# Prevent 3rd-party modules from installing anything.
macro(install)
endmacro(install)

add_subdirectory(3rd-party)

# vim:set et sts=4 sw=4 nospell:
