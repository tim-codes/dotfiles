function chrome-squad --description 'Start the Chrome a squad Claude context uses: its own profile, CDP on 127.0.0.1'
    set -l ctx $argv[1]
    switch "$ctx"
        case reserve
            set port 9231
        case exxo
            set port 9232
        case personal
            set port 9233
        case '*'
            echo "chrome-squad: unknown context '$ctx' (reserve, exxo, personal)" >&2
            return 2
    end
    set -l dir "$HOME/Library/Application Support/Google/Chrome-Squad-$ctx"
    mkdir -p "$dir"
    open -na "Google Chrome" --args --user-data-dir="$dir" --remote-debugging-port=$port
    echo "chrome-squad: $ctx on 127.0.0.1:$port ($dir); check: curl -s http://127.0.0.1:$port/json/version"
end
