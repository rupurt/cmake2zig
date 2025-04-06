# Parse arguments with argc and execute the specified command
# Ensure we're in a dev shell before running a command if --ensure-devshell is passed
dev() {
	if [[ "$1" == "--ensure-devshell" ]]; then
		shift
		if [[ "$IN_NIX_DEVSHELL" -ne 1 ]]; then
			echo "Entering devshell, please try again once loaded..."
			nix develop . --impure --no-warn-dirty -c $SHELL
			return
		fi
	fi
	eval "$(argc --argc-eval "${0}" "$@")"
}

# Run something, and print exactly what we're running
runp() {
	echo "Running: $@"
	bash -c "$@"
}
