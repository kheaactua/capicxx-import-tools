#include <iostream>

#include <CommonAPI/CommonAPI.hpp>

#include <v1/test/example/ExampleProxy.hpp>

auto main() -> int
{
    auto runtime = CommonAPI::Runtime::get();
    CommonAPI::Runtime::setProperty("LogApplication", "example-client");

    std::cout << "Creating proxy\n";
    auto proxy =
        runtime->buildProxy<v1::test::example::ExampleProxy>("local", "alpha", "example-client");
    if (!proxy)
    {
        std::cout << "Cannot create Example proxy" << std::endl;
        return 1;
    }

    std::cout << "Waiting on service" << std::endl;
    proxy->isAvailableBlocking();
    std::cout << "Proxy is available" << std::endl;

    return 0;
}
