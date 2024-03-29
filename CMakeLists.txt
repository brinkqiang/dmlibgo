cmake_minimum_required(VERSION 3.2)

###################################################################################
IF(UNIX)
    SET(CMAKE_TOOLCHAIN_FILE "${CMAKE_SOURCE_DIR}/../dmvcpkg/vcpkg/scripts/buildsystems/vcpkg.cmake")
ENDIF(UNIX)

project(libgo)

LIST(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
INCLUDE(cmake/ModuleImport.cmake)
INCLUDE(cmake/ModuleCompileOptions.cmake)
ModuleSetCompileOptions()

IF(UNIX)
    #find_package(Boost COMPONENTS context REQUIRED)
    #include_directories(${Boost_INCLUDE_DIRS})

    #find_package(CURL CONFIG REQUIRED)
    #include_directories(${CURL_INCLUDE_DIRS})
ENDIF(UNIX)

enable_language(C ASM)

if (CMAKE_BUILD_TYPE)
else()
    set(CMAKE_BUILD_TYPE RELEASE)
    #set(CMAKE_BUILD_TYPE DEBUG)
endif()

message("------------ Options -------------")
message("  CMAKE_BUILD_TYPE: ${CMAKE_BUILD_TYPE}")
message("  CMAKE_COMMAND: ${CMAKE_COMMAND}")

option(ENABLE_DEBUGGER "enable debugger" OFF)
if (ENABLE_DEBUGGER)
    set(ENABLE_DEBUGGER 1)
    message ("  enable_debugger: yes")
else()
    set(ENABLE_DEBUGGER 0)
    message ("  enable_debugger: no")
endif()

option(DISABLE_HOOK "disable hook" OFF)
option(BUILD_DYNAMIC "build dynamic hook" OFF)

if (DISABLE_HOOK)
    set(ENABLE_HOOK 0)
    message ("  enable_hook: no")
else()
    set(ENABLE_HOOK 1)
    message ("  enable_hook: yes")
endif()

if (BUILD_DYNAMIC)
    message ("  build dynamic lib: yes")
else()
    message ("  build dynamic lib: no")
endif()

message("-------------- Env ---------------")
message("  CMAKE_SOURCE_DIR: ${CMAKE_SOURCE_DIR}")
message("  CMAKE_BINARY_DIR: ${CMAKE_BINARY_DIR}")
message("----------------------------------")

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/src/libgo/common/cmake_config.h.in ${CMAKE_CURRENT_SOURCE_DIR}/src/libgo/common/cmake_config.h)
message("----------------------------------")

if (UNIX)
    set(CMAKE_CXX_FLAGS "-std=c++11 -D__const__=  -fPIC -fno-strict-aliasing -Wall ${CMAKE_CXX_FLAGS}")
    set(CMAKE_CXX_FLAGS_DEBUG "-g")
    set(CMAKE_CXX_FLAGS_RELEASE "-g -O3 -DNDEBUG")

    execute_process(COMMAND "chmod" "+x" "${PROJECT_SOURCE_DIR}/thirdparty/select_asm.sh")
    execute_process(COMMAND "chmod" "+x" "${PROJECT_SOURCE_DIR}/thirdparty/boost.context/bootstrap.sh")
    execute_process(COMMAND "chmod" "+x" "${PROJECT_SOURCE_DIR}/thirdparty/boost.context/tools/build/src/engine/build.sh")
	
    set(CMAKE_ASM_SOURCE_FILE_EXTENSIONS S)
    message("--> select asm source file, please wait about 5 seconds ...")
    execute_process(COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/select_asm.sh" "${CMAKE_CURRENT_SOURCE_DIR}" "jump" OUTPUT_VARIABLE jump_asm_file)
    execute_process(COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/select_asm.sh" "${CMAKE_CURRENT_SOURCE_DIR}" "make" OUTPUT_VARIABLE make_asm_file)
elseif (WIN32)
    # windows platform
    add_definitions(-D_CRT_SECURE_NO_WARNINGS)
    add_definitions(/utf-8)
    add_definitions(/wd4828)
    set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /MTd /EHsc")
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /MT /EHsc")
endif()

message("------------ Cxx flags -------------")
message("  CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE}: ${CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE}}")
message("------------------------------------")

include_directories(${CMAKE_CURRENT_SOURCE_DIR})
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/src)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/src/libgo)

aux_source_directory(${CMAKE_CURRENT_SOURCE_DIR}/src/libgo CO_SRC_LIST)
aux_source_directory(${CMAKE_CURRENT_SOURCE_DIR}/src/libgo/common CO_SRC_LIST)
aux_source_directory(${CMAKE_CURRENT_SOURCE_DIR}/src/libgo/context CO_SRC_LIST)
aux_source_directory(${CMAKE_CURRENT_SOURCE_DIR}/src/libgo/task CO_SRC_LIST)
aux_source_directory(${CMAKE_CURRENT_SOURCE_DIR}/src/libgo/scheduler CO_SRC_LIST)
aux_source_directory(${CMAKE_CURRENT_SOURCE_DIR}/src/libgo/sync CO_SRC_LIST)
aux_source_directory(${CMAKE_CURRENT_SOURCE_DIR}/src/libgo/timer CO_SRC_LIST)
aux_source_directory(${CMAKE_CURRENT_SOURCE_DIR}/src/libgo/cls CO_SRC_LIST)
aux_source_directory(${CMAKE_CURRENT_SOURCE_DIR}/src/libgo/defer CO_SRC_LIST)
aux_source_directory(${CMAKE_CURRENT_SOURCE_DIR}/src/libgo/pool CO_SRC_LIST)
aux_source_directory(${CMAKE_CURRENT_SOURCE_DIR}/src/libgo/debug CO_SRC_LIST)

if (NOT DISABLE_HOOK)
    if (UNIX)
        aux_source_directory(${CMAKE_CURRENT_SOURCE_DIR}/src/libgo/netio/unix CO_SRC_LIST)
    elseif (WIN32)
	    include_directories(${CMAKE_CURRENT_SOURCE_DIR}/src/libgo/netio/windows)
        aux_source_directory(${CMAKE_CURRENT_SOURCE_DIR}/src/libgo/netio/windows CO_SRC_LIST)
	    aux_source_directory(${CMAKE_CURRENT_SOURCE_DIR}/src/libgo/context/fiber CO_SRC_LIST)
	    list(APPEND CO_SRC_LIST ${CMAKE_CURRENT_SOURCE_DIR}/src/libgo/netio/windows/xhook/xhook.cpp)
    endif()
else()
    aux_source_directory(${CMAKE_CURRENT_SOURCE_DIR}/src/libgo/netio/disable_hook CO_SRC_LIST)
endif()

set(TARGET "libgo")
set(STATIC_T "libgo_static")
set(STATIC_HOOK "static_hook")

list(APPEND CO_SRC_LIST ${jump_asm_file})
list(APPEND CO_SRC_LIST ${make_asm_file})

message("CO_SRC_LIST: ${CO_SRC_LIST}")

add_library("${STATIC_T}" STATIC ${CO_SRC_LIST})
set_target_properties("${STATIC_T}" PROPERTIES OUTPUT_NAME "${TARGET}")

if (UNIX)
    install(TARGETS ${STATIC_T} LIBRARY DESTINATION "lib" ARCHIVE DESTINATION "lib")
    install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/src/libgo/ DESTINATION "include/libgo" FILES_MATCHING PATTERN "*.h")
        #PATTERN "windows" EXCLUDE

    add_library("${STATIC_HOOK}" STATIC "${CMAKE_CURRENT_SOURCE_DIR}/src/libgo/netio/unix/static_hook/static_hook.cpp")

    if (BUILD_DYNAMIC)
        set(SHARED_T "libgo_dynamic")
        add_library("${SHARED_T}" SHARED ${CO_SRC_LIST})
        set_target_properties("${SHARED_T}" PROPERTIES OUTPUT_NAME "${TARGET}")
        target_link_libraries("${SHARED_T}" ${LINK_LIBS} -ldl)
        install(TARGETS ${SHARED_T} LIBRARY DESTINATION "lib" ARCHIVE DESTINATION "lib")
    endif()

    add_custom_target(debug
        COMMAND ${CMAKE_COMMAND} -DCMAKE_BUILD_TYPE=DEBUG ${CMAKE_SOURCE_DIR}
        COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target all
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        COMMENT "Switch CMAKE_BUILD_TYPE to Debug"
    )

    add_custom_target(release
        COMMAND ${CMAKE_COMMAND} -DCMAKE_BUILD_TYPE=RELEASE ${CMAKE_SOURCE_DIR}
        COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target all
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        COMMENT "Switch CMAKE_BUILD_TYPE to Release"
    )

    set(PROFILE_FLAGS "-pg ${CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE}}")

    #message("PROFILE_FLAGS: ${PROFILE_FLAGS}")
    add_custom_target(profile
        COMMAND ${CMAKE_COMMAND} -DCMAKE_BUILD_TYPE=PROFILE -DCMAKE_CXX_FLAGS_PROFILE=\\'${PROFILE_FLAGS}\\' ${CMAKE_SOURCE_DIR}
        COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target all
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        COMMENT "Switch CMAKE_BUILD_TYPE to PROFILE"
    )

    add_custom_target(uninstall
        COMMAND rm ${CMAKE_INSTALL_PREFIX}/lib/lib/libgo.a ${CMAKE_INSTALL_PREFIX}/lib/lib/libgo.so ${CMAKE_INSTALL_PREFIX}/lib/lib/libgo_main.a -f
        COMMAND rm ${CMAKE_INSTALL_PREFIX}/include/libgo -rf
    )

elseif (WIN32)
    set_target_properties("${STATIC_T}" PROPERTIES COMPILE_FLAGS "/wd4819 /wd4267")
endif()

IF(WIN32)
ExeImport("example" "libgo_static")
ELSE(UNIX)
#ExeImport("example" "libgo_static;${Boost_LIBRARIES};${CURL_LIBRARIES}")
ExeImport("example" "libgo_static")
ENDIF(WIN32)