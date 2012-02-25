module parser;

import hurt.io.stdio;
import hurt.container.deque;
import hurt.util.slog;

import parsetable;
import lexer;
import lextable;
import token;

class Parser {
	private Lexer lexer;

	public this(Lexer lexer) {
		this.lexer = lexer;	
	} 

	public void run() {
		Deque!(Token) tmp = new Deque!(Token)(16);
		outer: while(true) {
			lexer.getToken(tmp);
			while(!tmp.isEmpty()) {
				auto it = tmp.popFront();
				if(it.getTyp() == -99) {
					continue;
				}
				log(false, "%s %d", it.toString(), it.getTyp());
				if(it.getTyp() == termdollar) {
					break outer;
				}
			}
		}
	}
}
