import os

from conan import ConanFile
from conan.tools.files import get
from conan.tools.cmake import CMakeToolchain, CMake


class CapicxxGeneratorsConan(ConanFile):
    name = "capicxx-generators"
    package_type = "application"
    settings = "os", "build_type"
    license = "https://github.com/COVESA/capicxx-someip-tools/blob/master/LICENSE"
    author = "https://github.com/COVESA/capicxx-someip-tools/blob/master/AUTHORS"
    url = "https://github.com/covesa/capicxx-someip-tools.git"
    description = "Generators for CommonAPI"
    topics = ("tcp", "C++", "networking")
    version = "3.2.14"
    user = "kheaactua"
    channel = "stable"

    exports_sources = ("CMakeLists.txt", "CapiGeneratorConfig.cmake.in")

    def generate(self):
        tc = CMakeToolchain(self)
        tc.generate()

    def source(self):
        for tool in "core", "someip":
            get(
                self, **self.conan_data["sources"][self.version][tool], destination=tool
            )

    def build(self):
        cmake = CMake(self)
        cmake.configure(
            variables={
                "CAPI_CORE_GEN": os.path.join(
                    self.source_folder, "core", "commonapi-core-generator-linux-x86_64"
                ),
                "CAPI_SOMEIP_GEN": os.path.join(
                    self.source_folder,
                    "someip",
                    "commonapi-someip-generator-linux-x86_64",
                ),
            },
        )

    def package(self):
        cmake = CMake(self)
        cmake.install()

    def package_info(self):
        self.cpp_info.builddirs = ["lib/cmake"]
