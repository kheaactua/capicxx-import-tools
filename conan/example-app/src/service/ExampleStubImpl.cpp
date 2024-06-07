// #include <cstdint>
// #include <ctime>
// #include <iomanip>
#include <sstream>

#include <CommonAPI/CommonAPI.hpp>

// #include <v1/test/example/Example.hpp>

#include "ExampleStubImpl.hpp"

namespace example::main::service
{

using namespace v1::test::example;

ExampleStubImpl::ExampleStubImpl() = default;

void ExampleStubImpl::sayHello(
    std::shared_ptr<CommonAPI::ClientId> /* _client */,
    std::string name,
    sayHelloReply_t reply)
{
    std::stringstream message_stream;
    message_stream << "Hello " << name << "!";

    std::cout << "sayHello('" << name << "'): " << message_stream.str();

    reply(message_stream.str());
}
} // namespace example::main::service
