{
  mkShell,
  clang,
  libclang,
  zig,
  ...
}:
mkShell {
  packages = [
    clang
    zig
    libclang
  ];
}
