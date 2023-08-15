class Capnp < Formula
  desc "Data interchange format and capability-based RPC system"
  homepage "https://capnproto.org/"
  url "https://capnproto.org/capnproto-c++-1.0.0.tar.gz"
  sha256 "4829b3b5f5d03ea83cf6eabd18ceac04ab393398322427eda4411d9f1d017ea9"
  license "MIT"
  head "https://github.com/capnproto/capnproto.git", branch: "master"

  livecheck do
    url "https://capnproto.org/install.html"
    regex(/href=.*?capnproto-c\+\+[._-]v?(\d+(\.\d+)*)\.t/i)
  end

  bottle do
    sha256 arm64_ventura:  "33183d990517550b7a2a970c808a35e18125f1d82d3bb5fa214b723f0edec517"
    sha256 arm64_monterey: "987493ff3bd711e84174dd27142f63d07191f44debfb04f09060ec3e3ca5925b"
    sha256 arm64_big_sur:  "55acc6d86092f97869e0be531ebe3b2edb231c08c6d4dc7eb521f638e46086cf"
    sha256 ventura:        "58daba471c2ebb0002f0101e2e6915d327b2a52e5e5f2a0d6df6fda551dbe3d2"
    sha256 monterey:       "ee81c9e2af592979dcf1f7b5a986d403de9aa6d8b67bc5e63c35c477322aa889"
    sha256 big_sur:        "bb3ca39a54b2838388e8a6af0db16c05de38d49dc5699e70528528dcc6da806a"
    sha256 x86_64_linux:   "51e284ca5b57d16b50d398251b9a21903bcdcfa04f4694dc2a327b57f254b1ad"
  end

  depends_on "cmake" => :build
  uses_from_macos "zlib"

  on_linux do
    depends_on "openssl@3"
  end

  def install
    # Build shared library
    system "cmake", "-S", ".", "-B", "build_shared",
                    "-DBUILD_SHARED_LIBS=ON",
                    "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
                    "-DCMAKE_INSTALL_RPATH=#{rpath}",
                    "-DCMAKE_CXX_FLAGS=-fPIC",
                    *std_cmake_args
    system "cmake", "--build", "build_shared"
    system "cmake", "--install", "build_shared"

    # Build static library
    system "cmake", "-S", ".", "-B", "build_static",
                    "-DBUILD_SHARED_LIBS=OFF",
                    "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
                    "-DCMAKE_CXX_FLAGS=-fPIC",
                    *std_cmake_args
    system "cmake", "--build", "build_static"
    lib.install buildpath.glob("build_static/src/capnp/*.a")
    lib.install buildpath.glob("build_static/src/kj/*.a")
  end

  test do
    ENV["PWD"] = testpath.to_s

    file = testpath/"test.capnp"
    text = "\"Is a happy little duck\""

    file.write shell_output("#{bin}/capnp id").chomp + ";\n"
    file.append_lines "const dave :Text = #{text};"
    assert_match text, shell_output("#{bin}/capnp eval #{file} dave")

    (testpath/"person.capnp").write <<~EOS
      @0x8e0594c8abeb307c;
      struct Person {
        id @0 :UInt32;
        name @1 :Text;
        email @2 :Text;
      }
    EOS
    system "#{bin}/capnp", "compile", "-oc++", testpath/"person.capnp"

    (testpath/"test.cpp").write <<~EOS
      #include "person.capnp.h"
      #include <capnp/message.h>
      #include <capnp/serialize-packed.h>
      #include <iostream>
      void printPerson(int fd) {
        ::capnp::PackedFdMessageReader message(fd);
        Person::Reader person = message.getRoot<Person>();

        std::cout << person.getName().cStr() << ": "
                  << person.getEmail().cStr() << std::endl;
      }
    EOS
    system ENV.cxx, "-c", testpath/"test.cpp", "-I#{include}", "-o", "test.o", "-fPIC", "-std=c++1y"
    system ENV.cxx, "-shared", testpath/"test.o", "-L#{lib}", "-fPIC", "-lcapnp", "-lkj"
  end
end
