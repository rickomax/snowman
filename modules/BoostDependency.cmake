# BoostDependency.cmake
#
# Makes Boost available to the build with zero manual setup.
#
# Snowman uses Boost in a *header-only* fashion (see the boost/*.hpp includes
# under src/), so no compiled Boost libraries are needed.  This module:
#
#   1. Looks for Boost already installed on the system (system packages,
#      BOOST_ROOT, vcpkg, Conan, ...).
#   2. If it is not found and downloading is allowed, fetches the header-only
#      Boost distribution automatically using CMake's FetchContent.
#
# After this module has run the following variables are set and can be used
# exactly as with a plain find_package(Boost):
#
#   Boost_FOUND         - TRUE
#   Boost_INCLUDE_DIRS  - directory containing the boost/ header tree
#   Boost_LIBRARIES     - libraries to link (empty - Boost is used header-only)
#
# Relevant options / cache variables:
#
#   SNOWMAN_DOWNLOAD_BOOST   - allow the automatic download (default ON)
#   SNOWMAN_BOOST_VERSION    - Boost version to download (default 1.87.0)
#   SNOWMAN_BOOST_URL        - override the archive URL (optional)
#   SNOWMAN_BOOST_URL_HASH   - expected hash "ALGO=value" of the archive
#                              (optional but recommended, e.g. SHA256=...)

set(SNOWMAN_BOOST_MIN_VERSION 1.46.0)

option(SNOWMAN_DOWNLOAD_BOOST
    "Download the Boost headers automatically if Boost is not found on the system." ON)

set(SNOWMAN_BOOST_VERSION "1.87.0" CACHE STRING
    "Version of Boost to download when it is not found on the system.")
set(SNOWMAN_BOOST_URL "" CACHE STRING
    "Override URL of the Boost source archive to download (optional).")
set(SNOWMAN_BOOST_URL_HASH "" CACHE STRING
    "Expected hash of the downloaded Boost archive, e.g. SHA256=<hex> (optional but recommended).")

# Newer CMake (>= 3.30) removed the bundled FindBoost module in favour of the
# upstream BoostConfig.cmake.  Selecting NEW keeps find_package(Boost) working
# on both old and new CMake without noisy deprecation warnings.
if(POLICY CMP0167)
    cmake_policy(SET CMP0167 NEW)
endif()

# Use the extraction time for downloaded/extracted archives (CMake >= 3.24).
# This silences the CMP0135 developer warning during the download fallback.
if(POLICY CMP0135)
    cmake_policy(SET CMP0135 NEW)
endif()

#
# 1. Try to use a Boost that is already present.
#
find_package(Boost ${SNOWMAN_BOOST_MIN_VERSION} QUIET)

if(Boost_FOUND)
    if(Boost_VERSION_STRING)
        message(STATUS "Boost: using system installation (version ${Boost_VERSION_STRING}).")
    else()
        message(STATUS "Boost: using system installation.")
    endif()
else()
    #
    # 2. Fall back to downloading the header-only Boost distribution.
    #
    if(NOT SNOWMAN_DOWNLOAD_BOOST)
        message(FATAL_ERROR
            "Boost >= ${SNOWMAN_BOOST_MIN_VERSION} was not found and automatic download is "
            "disabled (SNOWMAN_DOWNLOAD_BOOST=OFF).\n"
            "Options:\n"
            "  * install Boost (headers only) and/or set BOOST_ROOT, or\n"
            "  * re-enable the download with -DSNOWMAN_DOWNLOAD_BOOST=ON, or\n"
            "  * build with the vcpkg manifest (see doc/build.asciidoc).")
    endif()

    if(CMAKE_VERSION VERSION_LESS 3.11)
        message(FATAL_ERROR
            "Boost was not found and automatic download needs CMake >= 3.11 "
            "(FetchContent). Please install Boost manually or upgrade CMake.")
    endif()

    # Build the default download URL from the requested version.
    if(SNOWMAN_BOOST_URL)
        set(_boost_url "${SNOWMAN_BOOST_URL}")
    else()
        string(REPLACE "." "_" _boost_ver_underscore "${SNOWMAN_BOOST_VERSION}")
        set(_boost_url
            "https://archives.boost.io/release/${SNOWMAN_BOOST_VERSION}/source/boost_${_boost_ver_underscore}.tar.bz2")
    endif()

    message(STATUS "Boost: not found on the system - downloading headers from ${_boost_url}")

    include(FetchContent)

    if(SNOWMAN_BOOST_URL_HASH)
        FetchContent_Declare(boost URL "${_boost_url}" URL_HASH "${SNOWMAN_BOOST_URL_HASH}")
    else()
        message(STATUS
            "Boost: no SNOWMAN_BOOST_URL_HASH set - the download is verified by HTTPS only. "
            "Set -DSNOWMAN_BOOST_URL_HASH=SHA256=<hex> to pin the archive.")
        FetchContent_Declare(boost URL "${_boost_url}")
    endif()

    # We only need the headers, so populate the archive without adding Boost's
    # own build system (add_subdirectory) - that keeps configuration fast and
    # avoids compiling any Boost libraries we do not use.
    FetchContent_GetProperties(boost)
    if(NOT boost_POPULATED)
        FetchContent_Populate(boost)
    endif()

    # In the official release archives the whole header tree lives directly
    # under the extracted root (e.g. boost_1_87_0/boost/array.hpp), and CMake
    # strips the single leading directory during extraction.
    set(Boost_INCLUDE_DIRS "${boost_SOURCE_DIR}" CACHE PATH "Boost include directory" FORCE)
    set(Boost_LIBRARIES "" CACHE STRING "Boost libraries (header-only)" FORCE)
    set(Boost_FOUND TRUE)

    message(STATUS "Boost: downloaded headers available at ${boost_SOURCE_DIR}")
endif()

# vim:set et sts=4 sw=4 nospell:
