module parser;

import hurt.algo.binaryrangesearch;
import hurt.io.stdio;
import hurt.container.deque;
import hurt.util.slog;
import hurt.util.pair;

import parsetable;
import lexer;
import lextable;
import token;

class Parser {
	private Lexer lexer;
	private Deque!(Token) tokenBuffer;
	private Deque!(int) parseStack;

	public this(Lexer lexer) {
		this.lexer = lexer;	
		this.tokenBuffer = new Deque!(Token)(64);
		this.parseStack = new Deque!(int)(128);
	} 

	private Token getNextToken() {
		if(this.tokenBuffer.isEmpty()) {
			this.lexer.getToken(this.tokenBuffer);
		}
		assert(!this.tokenBuffer.isEmpty(), "the buffer should not be empty");
		return this.tokenBuffer.popFront();
	}

	private TableItem getAction(Token input) {
		auto retError = Pair!(int,TableItem)(int.min, TableItem(false));
		auto toSearch = Pair!(int,TableItem)(input.getTyp(), TableItem(false));
		auto row = parseTable[this.parseStack.back()];
		bool found;
		size_t foundIdx;

		auto ret = binarySearch!(Pair!(int,TableItem))
			(row, toSearch, retError, row.length, found, foundIdx,
			function(Pair!(int,TableItem) a, Pair!(int,TableItem) b) {
				return a.first > b.first;
			}, 
			function(Pair!(int,TableItem) a, Pair!(int,TableItem) b) {
				return a.first == b.first; });

		return ret.second;
	}

	public void parse() {
		Token token = this.getNextToken();
		// we start at state (zero null none 0)
		this.parseStack.pushBack(0);

		TableItem action;
		
		while(true) {


		}
	}

	public void run() {
		outer: while(true) {
			auto it = this.getNextToken();
			if(it.getTyp() == -99) {
				continue;
			}
			log("%s %d", it.toString(), it.getTyp());
			if(it.getTyp() == termdollar) {
				break outer;
			}
		}
	}
}
