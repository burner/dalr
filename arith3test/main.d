import hurt.io.stdio;
import hurt.util.slog;
import hurt.container.deque;

import lexer;
import token;
import parser;

void main() {
	Parser p = new Parser(new Lexer("examplearith.dpp", true, 100));

	p.parse();
}
