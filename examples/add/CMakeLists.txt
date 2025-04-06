cmake_minimum_required(VERSION 3.10)
project(add)

add_executable(add src/main.cpp src/add.cpp)

target_include_directories(add PRIVATE include)

target_compile_options(add PRIVATE -std=c++17 -Wall -Wextra)

target_link_libraries(add PRIVATE pthread)
