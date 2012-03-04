import hurt.io.stdio;
import hurt.util.slog;
import hurt.container.deque;
import hurt.time.stopwatch;
import hurt.io.stdio;
import hurt.util.getopt;

import lexer;
import token;
import parser;

void main(string[] args) {
	Args arg = Args(args);
	bool lpMulti = true; // true means multithreaded
	arg.setOption("-l", "--lpMulti", "if false is passed" ~
		" a single threaded lexer parser combination will be created." ~
		" if nothing or true is passed the lexer parser combination will" ~
		" be multithreaded.", lpMulti);

	StopWatch sw;
	sw.start();
	Parser p = new Parser(new Lexer("short.dpp", lpMulti, 10));

	p.parse();
	p.getAST().toGraph("test1.dot");
	//p.run();
	printfln("lexing and parsing took %f seconds", sw.stop());
}
