is_global_mode() {
    [ "$1" = 'global' ]
}

is_chnroute_mode() {
    [ "$1" = 'chnroute' ]
}

if is_global_mode global || is_chnroute_mode chnroute; then
    echo true
fi
