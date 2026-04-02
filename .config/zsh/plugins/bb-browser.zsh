# Route interactive bb-browser invocations through the Dotfiles wrapper.
if (( $+commands[bb-browser-user] )); then alias bb-browser='bb-browser-user'; fi
