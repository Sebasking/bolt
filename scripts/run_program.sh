#!/bin/bash
make pre-build
rm -rf "${1%.bolt}.ir"
if [ $# -eq 0 ]; then
 dune exec -- src/frontend/main.exe -help
else
  (dune exec -- src/frontend/main.exe $*)
  if [ -f "${1%.bolt}.ir" ]; then
    echo -e "Frontend type-checking completed \033[0;32msuccessfully".
    echo -e "\033[0m"
    bazel-bin/src/llvm-backend/main "${1%.bolt}.ir" > "${1%.bolt}.ll" && echo -e "LLVM IR Codegen completed \033[0;32msuccessfully".
    echo -e "\033[0m"
    clang -O3 -pthread "${1%.bolt}.ll" -o "${1%.bolt}" && echo  -e "Native binary compiled \033[0;32msuccessfully".
     echo -e "\033[0m"
    ./${1%.bolt}
  fi
fi
