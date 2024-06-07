find_package(CommonAPI-SomeIP ${CommonAPI_SomeIP_FIND_VERSION} EXACT REQUIRED
  CONFIG
  NO_CMAKE_PACKAGE_REGISTRY
  NO_SYSTEM_ENVIRONMENT_PATH
)

# Use the lib imported from the CommonAPI package
get_target_property(CommonAPI_SomeIP_LIBRARY CommonAPI-SomeIP LOCATION)

if(NOT vsomeip_FOUND)
  find_package(vsomeip3
    NO_CMAKE_PACKAGE_REGISTRY
    NO_SYSTEM_ENVIRONMENT_PATH
  )
endif()

get_property(vSomeIP_INCLUDE_DIRS TARGET vsomeip3 PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
get_property(COMMONAPI_SOMEIP_INCLUDE_DIRS TARGET CommonAPI-SomeIP PROPERTY INTERFACE_INCLUDE_DIRECTORIES)

# Normalise variables (buildroot has symlinks which can cause some problems here)
foreach(var IN ITEMS COMMONAPI_SOMEIP_INCLUDE_DIRS CommonAPI_SomeIP_LIBRARY vSomeIP_INCLUDE_DIRS)
  if (NOT "${${var}}" STREQUAL "")
    get_filename_component(${var} "${${var}}" ABSOLUTE)
  endif()
endforeach()

mark_as_advanced(COMMONAPI_SOMEIP_INCLUDE_DIRS COMMONAPI_SOMEIP_VERSION CommonAPI_SomeIP_LIBRARY)

list(APPEND COMMON_API_COMPONENT_REQUIRED_VARS
  COMMONAPI_SOMEIP_INCLUDE_DIRS
  CommonAPI_SomeIP_LIBRARY
)

# Make the Genivi::dlt target available in case vsomeip depends on it
if(NOT TARGET Genivi::dlt)
  find_package(automotive-dlt QUIET)
  if(automotive-dlt_FOUND)
    message(STATUS "automotive-dlt found")
  else()
    message(STATUS "automotive-dlt not found")
  endif()
endif()


if(NOT TARGET common_api_someip)
  add_library(common_api_someip INTERFACE IMPORTED)
  target_link_libraries(common_api_someip INTERFACE
    CommonAPI-SomeIP
    vsomeip3
  )

  add_library(common_api_someip-static INTERFACE IMPORTED)
  target_link_libraries(common_api_someip-static INTERFACE
    CommonAPI-SomeIP-static
    vsomeip3-static
  )
  if(NOT TARGET Boost::system)
    # Static builds require Boost
    find_package(Boost
      COMPONENTS
        system thread filesystem
      OPTIONAL_COMPONENTS
        stacktrace_basic
    )
    if(Boost_FOUND)
      target_link_libraries(common_api_someip-static INTERFACE
        Boost::system Boost::thread Boost::filesystem
      )
      if(TARGET Boost::stacktrace_basic)
        target_link_libraries(common_api_someip-static INTERFACE Boost::stacktrace_basic)
      endif()
    else()
      message(NOTICE "Boost is required for static CommonAPI assets but cannot be found.  Please define BOOST_ROOT (and Boost_USE_STATIC_LIBS) in order for find_package(Boost) to work.")
    endif()
  endif()

  set_property(
    TARGET
      common_api_someip
      common_api_someip-static
    PROPERTY
      INTERFACE_SYSTEM_INCLUDE_DIRECTORIES
        "${COMMONAPI_SOMEIP_INCLUDE_DIRS};${vSomeIP_INCLUDE_DIRS}"
  )

  set(_dep_libs)
  get_property(_tmp TARGET CommonAPI-SomeIP PROPERTY LOCATION)
  list(APPEND _dep_libs ${_tmp})
  get_property(_tmp TARGET vsomeip3 PROPERTY LOCATION)
  list(APPEND _dep_libs ${_tmp})

  set(_dep_incs)
  get_property(_tmp TARGET common_api_someip PROPERTY INTERFACE_SYSTEM_INCLUDE_DIRECTORIES)
  list(APPEND _dep_incs ${_tmp})

  unset(_tmp)

  set(_tmp_out_msg "Found middleware transport runtime CommonAPI::SomeIP
   inc:")
   foreach(inc IN LISTS _dep_incs)
    set(_tmp_out_msg "${_tmp_out_msg}\n     - ${inc}")
  endforeach()
  set(_tmp_out_msg "${_tmp_out_msg}\n   lib:")
  foreach(lib IN LISTS _dep_libs)
    set(_tmp_out_msg "${_tmp_out_msg}\n     - ${lib}")
  endforeach()
  message(STATUS ${_tmp_out_msg})
  unset(_tmp_out_msg)
  unset(_tmp_int_dirs)
  unset(_dep_libs)
  unset(_dep_incs)
endif()

# vim: ts=2 sw=2 sts=0 expandtab ff=unix :
