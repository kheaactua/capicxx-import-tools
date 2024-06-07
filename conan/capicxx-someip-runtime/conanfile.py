import re

from conan import ConanFile
from conan.tools.cmake import CMakeToolchain, CMake, cmake_layout
from conan.tools.scm import Git


class CapicxxSomeipRuntimeConan(ConanFile):
    name = "capicxx-someip-runtime"
    package_type = "shared-library"
    settings = "os", "compiler", "build_type", "arch"
    license = "https://github.com/COVESA/capicxx-someip-runtime/blob/master/LICENSE"
    author = "https://github.com/COVESA/capicxx-someip-runtime/blob/master/AUTHORS"
    url = "https://github.com/covesa/capicxx-someip-runtime.git"
    description = "Middleware for CommonAPI"
    topics = ("tcp", "C++", "networking")
    version = "3.2.3r8"
    user = "covesa"
    channel = "stable"

    requires = {
        "vsomeip/[>=3.4]@covesa/stable",
        "capicxx-core-runtime/[>=3.2.3r7, include_prerelease]@covesa/stable",
    }

    options = {
        "verbose_makefile": [True, False],
    }
    default_options = {"verbose_makefile": False}

    tool_requires = ("cmake/[>=3.23]", "gtest/[>=1.10]")

    def layout(self):
        cmake_layout(self)

    def source(self):
        git = Git(self)
        git.clone(
            url="https://github.com/covesa/capicxx-someip-runtime.git", target="."
        )
        tag = re.sub(r"r", "-r", self.version)
        git.checkout(tag)

    def generate(self):
        tc = CMakeToolchain(self)

        if self.settings.os == "Neutrino":
            tc.cache_variables["PKG_CONFIG_EXECUTABLE"] = ""
        tc.cache_variables["CMAKE_VERBOSE_MAKEFILE"] = self.options.verbose_makefile

        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()

    def package(self):
        cmake = CMake(self)
        cmake.install()

    def package_info(self):
        self.cpp_info.libs = ["CommonAPI-SomeIP"]
        self.cpp_info.builddirs = ["lib/cmake"]
