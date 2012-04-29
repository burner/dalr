import hurt.io.stdio;
import hurt.util.slog;
import hurt.container.deque;
import hurt.time.stopwatch;
import hurt.io.stdio;
import hurt.util.getopt;
import hurt.util.slog;

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

	string file = "short.dpp";
	arg.setOption("-f", "--file", "pass a string do define the file you " ~
		"want to parse. Default is examplearith.dpp" , file);

	size_t numToken = 10;
	arg.setOption("-t", "--token", "the number of token lexed in one run of" ~
		" lexer. Default is 10" , numToken);

	StopWatch sw;
	sw.start();
	Parser p = new Parser(new Lexer(file, lpMulti, 10));

	bool succ = p.parse();
	log("%b", succ);
	if(succ) {
		p.getAst().toGraph("test1.dot");
	}
	//p.run();
	printfln("lexing and parsing took %f seconds", sw.stop());
}
