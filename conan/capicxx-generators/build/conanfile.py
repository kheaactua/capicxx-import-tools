import os

from conan import ConanFile
from conan.tools.cmake import CMakeToolchain, CMake, cmake_layout
from conan.tools.scm import Git


class CapicxxGeneratorsConan(ConanFile):
    name = "capicxx-generators"
    package_type = "application"
    settings = "os", "build_type", "arch"
    license = "https://github.com/COVESA/capicxx-someip-tools/blob/master/LICENSE"
    author = "https://github.com/COVESA/capicxx-someip-tools/blob/master/AUTHORS"
    url = "https://github.com/covesa/capicxx-someip-tools.git"
    description = "Generators for CommonAPI"
    topics = ("tcp", "C++", "networking")

    version = "3.2.14"
    user = "kheaactua"
    channel = "stable"

    exports_sources = ("CMakeLists.txt", "CapiGeneratorConfig.cmake.in", "compose.yaml", "docker-entrypoint-build.sh")

    def layout(self):
        cmake_layout(self, build_folder="bld")

    def generate(self):
        tc = CMakeToolchain(self)
        tc.generate()

    def source(self):
        if not os.path.exists("workspace"):
            os.makedirs("workspace")

        for tool in ["core", "someip"]:
            if os.path.exists(os.path.join("workspace", f"capicxx-{tool}-tools")):
                continue

            dest = os.path.join(
                self.source_folder, "workspace", f"capicxx-{tool}-tools"
            )
            git = Git(self)
            git.clone(
                url=f"https://github.com/covesa/capicxx-{tool}-tools.git",
                target=dest,
            )
            git.folder = dest
            git.checkout(self.version)

    def build(self):
        self.run("docker-compose run app")

        out_os = "linux"
        if self.settings.os == "Linux":
            out_os = "linux"
        elif self.settings.os == "Windows":
            out_os = "win32"
        elif self.settings.os == "Macos":
            out_os = "macosx"
        else:
            raise Exception(f"Unsupported OS: {self.settings.os}")

        cmake = CMake(self)
        cmake.configure(
            variables={
                "CAPI_CORE_GEN": os.path.join(
                    self.source_folder,
                    "workspace",
                    "capicxx-core-tools",
                    "org.genivi.commonapi.core.cli.product",
                    "target",
                    "products",
                    "org.genivi.commonapi.core.cli.product",
                    out_os,
                    "gtk",
                    str(self.settings.arch),
                    f"commonapi-core-generator-{out_os}-{self.settings.arch}",
                ),
                "CAPI_SOMEIP_GEN": os.path.join(
                    self.source_folder,
                    "workspace",
                    "capicxx-someip-tools",
                    "org.genivi.commonapi.someip.cli.product",
                    "target",
                    "products",
                    "org.genivi.commonapi.someip.cli.product",
                    out_os,
                    "gtk",
                    str(self.settings.arch),
                    f"commonapi-someip-generator-{out_os}-{self.settings.arch}",
                ),
            },
        )

    def package(self):
        cmake = CMake(self)
        cmake.install()

    def package_info(self):
        self.cpp_info.builddirs = ["lib/cmake"]
