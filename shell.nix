{
  pkgs ? import <nixpkgs> { },
}:
with pkgs;
let
  elixir = beam.packages.erlang_27.elixir_1_17;
  elixir-ls = beam.packages.erlang_27.elixir-ls;
  erlang = beam.interpreters.erlang_27;
in
mkShell {
  nativeBuildInputs = [
    erlang
    elixir
    elixir-ls
    postgresql_16
    clang
    gcc
    autoconf
    automake
    inotify-tools
    ngrok
    awscli2
    varnish
    flyctl
  ];
}
