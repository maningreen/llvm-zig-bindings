{
  mkShell,
  clang,
  libclang,
  zlib,
  llvmPackages_19,
  zstd,
  zig,
  ...
}:
mkShell {
  packages = [
    clang
    zig
    libclang
    llvmPackages_19.libllvm
    zlib
    zstd
  ];
}
