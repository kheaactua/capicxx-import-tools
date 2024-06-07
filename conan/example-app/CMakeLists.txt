cmake_policy(SET CMP0048 NEW)
cmake_minimum_required(VERSION 3.23)
project(
  capicxx-cmake-modules-example
  VERSION 1.0
  LANGUAGES CXX
)

set(CAPI_MIDDLEWARE
    SomeIP
    CACHE STRING "Middleware"
)

find_package(
  CommonAPIImporter REQUIRED
  COMPONENTS Core ${CAPI_MIDDLEWARE} gen
  MODULE
)

# Code generator macro
include(${CAPI_GENERATE_INCLUDE})

set(CAPI_GEN_OUTPUT_DIR
    ${PROJECT_BINARY_DIR}/capi-src-gen
    CACHE PATH "Output directory for generated CommonAPI build files"
)

SET_UP_GEN_FILES(
  FIDL_FILE ${PROJECT_SOURCE_DIR}/fidl/example.fidl
  FDEPL_FILE ${PROJECT_SOURCE_DIR}/fidl/example.fdepl
  OUTPUT_DIR ${CAPI_GEN_OUTPUT_DIR}
  VAR_PREFIX "EX"
  VERSION 1
  INTERFACES test.example.Example
)

add_executable(client_app)
target_compile_features(client_app PRIVATE cxx_std_17)
target_sources(
  client_app
  PRIVATE ${EX_TRANSPORT_PROXY_PKG_DIR}/Example${CAPI_MIDDLEWARE}Proxy.cpp src/client/main.cpp
  PRIVATE FILE_SET capi_gen_headers
                   TYPE
                   HEADERS
                   BASE_DIRS ${CAPI_GEN_OUTPUT_DIR}
                   FILES ${EX_CORE_COMMON_PKG_DIR}/Example.hpp
                         ${EX_CORE_PROXY_PKG_DIR}/ExampleProxyBase.hpp
                         ${EX_TRANSPORT_PROXY_PKG_DIR}/Example${CAPI_MIDDLEWARE}Proxy.hpp
                         ${EX_TRANSPORT_COMMON_PKG_DIR}/Example${CAPI_MIDDLEWARE}Deployment.hpp
)
target_link_libraries(client_app PUBLIC CommonAPI::Combined)
target_include_directories(client_app PUBLIC ${EX_CAPI_INCLUDE_DIRS})
set_target_properties(client_app PROPERTIES OUTPUT_NAME example-client)

add_executable(service_app)
target_compile_features(service_app PRIVATE cxx_std_17)
target_sources(
  service_app
  PRIVATE ${EX_TRANSPORT_STUB_PKG_DIR}/ExampleSomeIPStubAdapter.cpp
          ${EX_TRANSPORT_COMMON_PKG_DIR}/ExampleSomeIPDeployment.cpp
          src/service/ExampleStubImpl.cpp
          src/service/main.cpp
  PRIVATE FILE_SET capi_gen_headers
                   TYPE
                   HEADERS
                   BASE_DIRS ${CAPI_GEN_OUTPUT_DIR}
                   FILES ${EX_CORE_COMMON_PKG_DIR}/Example.hpp
                         ${EX_CORE_STUB_PKG_DIR}/ExampleStub.hpp
                         ${EX_TRANSPORT_STUB_PKG_DIR}/Example${CAPI_MIDDLEWARE}StubAdapter.hpp
                         ${EX_TRANSPORT_COMMON_PKG_DIR}/Example${CAPI_MIDDLEWARE}Deployment.hpp
)
target_link_libraries(service_app PUBLIC CommonAPI::Combined)
target_include_directories(service_app PUBLIC ${EX_CAPI_INCLUDE_DIRS})
set_target_properties(service_app PROPERTIES OUTPUT_NAME example-service)

install(TARGETS client_app service_app RUNTIME)

# vim: ts=2 sw=2 sts=0 expandtab ff=unix :
