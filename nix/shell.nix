{ pkgs, example }:

with pkgs;
with ocamlPackages;
mkShell {
  OCAMLRUNPARAM = "o=40";
  inputsFrom = [ example ];
  packages = [ nixfmt utop ocamlformat ocaml findlib dune odoc ocaml-lsp ];
}
