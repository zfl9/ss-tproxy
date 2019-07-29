{ echo 1; echo 2; echo @3; echo @66 | cut -c2-; } | while read line; do echo "$line"; done
