#!/usr/bin/env nix-shell
#! nix-shell -i bash -p cabal2nix elm2nix

set -eu -o pipefail

# remove generated files
rm -f nix/server.nix nix/elm-srcs.nix nix/versions.dat

# regenerate haskell
cabal2nix . > nix/server.nix

# regenerate elm
pushd nix; elm2nix snapshot; popd
pushd client; elm2nix convert > ../nix/elm-srcs.nix; popd
