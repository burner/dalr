import hurt.io.stdio;
import hurt.util.slog;
import hurt.container.deque;

import lexer;
import token;
import parser;

void main() {
	/*Lexer l = new Lexer("examplearith.dpp");
	l.run();
	Deque!(Token) token = l.deque;
	foreach(Token it; token) {
		println(it.toString());
	}*/

	Parser p = new Parser(new Lexer("examplearith.dpp", true, 100));

	p.run();
}
