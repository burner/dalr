import hurt.io.stdio;
import hurt.util.slog;
import hurt.container.deque;

import lexer;
import token;

void main() {
	Lexer l = new Lexer("examplearith.dpp");
	l.run();
	Deque!(Token) token = l.deque;
	foreach(Token it; token) {
		println(it.toString());
	}
}
