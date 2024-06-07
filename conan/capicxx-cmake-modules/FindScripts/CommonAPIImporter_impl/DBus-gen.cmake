find_program(CAPI_DBus_GEN
  NAME
    commonapi-dbus-generator-linux-x86_64
  HINTS
    $ENV{QNX_HOST}/usr/bin/capi_gen/dbus
)

list(APPEND COMMON_API_COMPONENT_REQUIRED_VARS CAPI_DBus_GEN)

if(NOT TARGET common_api_dbus_gen)
  add_executable(common_api_dbus_gen IMPORTED GLOBAL)
  set_target_properties(common_api_dbus_gen PROPERTIES IMPORTED_LOCATION ${CAPI_DBus_GEN})
  message(STATUS "Found middleware transport generator CommonAPI::DBus::gen: ${CAPI_DBus_GEN}")
endif()

# vim: ts=2 sw=2 sts=0 expandtab ff=unix :
