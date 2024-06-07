#ifndef EXAMPLESTUBIMPL_HPP_ABKIF271
#define EXAMPLESTUBIMPL_HPP_ABKIF271

#include <CommonAPI/CommonAPI.hpp>
#include <v1/test/example/ExampleStubDefault.hpp>

namespace example::main::service
{

class ExampleStubImpl : public v1::test::example::ExampleStubDefault
{
  public:
    ExampleStubImpl();
    ~ExampleStubImpl() override = default;

    auto
    sayHello(std::shared_ptr<CommonAPI::ClientId> client, std::string name, sayHelloReply_t reply)
        -> void override;
};

} // namespace example::main::service

#endif /* end of include guard: EXAMPLESTUBIMPL_HPP_ABKIF271 */
