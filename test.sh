#!/bin/bash
set -o errexit
set -o pipefail

main() {
true && local a=100
echo $a
}
main
