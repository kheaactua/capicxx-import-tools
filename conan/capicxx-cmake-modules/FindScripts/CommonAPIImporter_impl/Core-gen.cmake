find_package(CapiGenerator REQUIRED CONFIG)

get_target_property(CAPI_CORE_GEN_LOCATION common_api_core_gen LOCATION)
message(STATUS "Found core generator CommonAPI::Core::gen: ${CAPI_CORE_GEN_LOCATION}")

# vim: ts=2 sw=2 sts=0 expandtab ff=unix :
