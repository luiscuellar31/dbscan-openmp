cmake_minimum_required(VERSION 3.16)

project(dbscan-openmp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

if(MSVC)
    add_compile_options($<$<CONFIG:Release>:/O2>)
else()
    add_compile_options($<$<CONFIG:Release>:-O3>)
endif()

add_executable(dbscan_serial
    src/dbscan_serial.cpp
)

add_executable(dbscan_omp_indivisible
    src/dbscan_omp_indivisible.cpp
)

add_executable(dbscan_omp_cuadrantes
    src/dbscan_omp_cuadrantes.cpp
)

set(USE_APPLE_OPENMP OFF)

if(MSVC)
    set(OPENMP_FLAG /openmp)
elseif(APPLE AND CMAKE_CXX_COMPILER_ID MATCHES "AppleClang")
    set(USE_APPLE_OPENMP ON)
    if(DEFINED ENV{HOMEBREW_PREFIX})
        set(HOMEBREW_PREFIX "$ENV{HOMEBREW_PREFIX}")
    else()
        set(HOMEBREW_PREFIX "/opt/homebrew")
    endif()
    set(OPENMP_INCLUDE_DIR "${HOMEBREW_PREFIX}/opt/libomp/include")
    set(OPENMP_LIB_DIR "${HOMEBREW_PREFIX}/opt/libomp/lib")
    set(OPENMP_RUNTIME_LIB omp)
else()
    find_package(OpenMP REQUIRED)
endif()

function(link_openmp target_name)
    if(MSVC)
        target_compile_options(${target_name} PRIVATE ${OPENMP_FLAG})
    elseif(USE_APPLE_OPENMP)
        target_include_directories(${target_name} PRIVATE "${OPENMP_INCLUDE_DIR}")
        target_compile_options(${target_name} PRIVATE -Xpreprocessor -fopenmp)
        target_link_directories(${target_name} PRIVATE "${OPENMP_LIB_DIR}")
        target_link_libraries(${target_name} PRIVATE ${OPENMP_RUNTIME_LIB})
        set_target_properties(${target_name} PROPERTIES
            BUILD_RPATH "${OPENMP_LIB_DIR}"
            INSTALL_RPATH "${OPENMP_LIB_DIR}")
    else()
        target_link_libraries(${target_name} PRIVATE OpenMP::OpenMP_CXX)
    endif()
endfunction()

link_openmp(dbscan_omp_indivisible)
link_openmp(dbscan_omp_cuadrantes)
