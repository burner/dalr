import lexer;
import hurt.io.stdio;
import hurt.util.slog;

void main() {
	log();
	Lexer l = new Lexer("examplearith.dpp");
	log();
	l.run();
	log();
}
