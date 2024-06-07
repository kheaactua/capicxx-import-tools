#include <iostream>
#include <unistd.h>

#include <CommonAPI/CommonAPI.hpp>

#include "ExampleStubImpl.hpp"

auto main() -> int
{
    auto runtime = CommonAPI::Runtime::get();
    CommonAPI::Runtime::setProperty("LogApplication", "example-service");

    auto service = std::make_shared<example::main::service::ExampleStubImpl>();
    auto successfully_registered =
        runtime->registerService("local", "alpha", service, "example-service");

    pause();

    return 0;
}
