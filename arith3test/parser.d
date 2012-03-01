module parser;

import hurt.algo.binaryrangesearch;
import hurt.container.deque;
import hurt.io.stdio;
import hurt.util.pair;
import hurt.util.slog;

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

	private Token getToken() {
		Token t = this.getNextToken();
		while(t.getTyp() == -99) {
			t = this.getNextToken();
		}
		return t;
	}

	private TableItem getAction(const Token input) const {
		auto retError = Pair!(int,TableItem)(int.min, 
			TableItem(TableType.Error, 0));

		log("%d %d", this.parseStack.back(), input.getTyp());

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

	private short getGoto(const int input) const {
		auto retError = Pair!(int,TableItem)(int.min, 
			TableItem(TableType.Error, 0));

		auto toSearch = Pair!(int,TableItem)(input, TableItem(false));
		auto row = gotoTable[this.parseStack.back()];
		bool found;
		size_t foundIdx;

		auto ret = binarySearch!(Pair!(int,TableItem))
			(row, toSearch, retError, row.length, found, foundIdx,
			function(Pair!(int,TableItem) a, Pair!(int,TableItem) b) {
				return a.first > b.first;
			}, 
			function(Pair!(int,TableItem) a, Pair!(int,TableItem) b) {
				return a.first == b.first; });

		return ret.second.getNumber();
	}

	private void printStack() const {
		foreach(const int it; this.parseStack) {
			printf("%d ", it);
		}
		println();
	}

	public void parse() {
		// we start at state (zero null none 0)
		this.parseStack.pushBack(0);

		TableItem action;
		auto input = this.getToken();
		
		while(true) { 
			this.printStack();
			action = this.getAction(input); 
			log("%s", action.toString());
			if(action.getTyp() == TableType.Accept) {
				log();
				break;
			} else if(action.getTyp() == TableType.Error) {
				log();
				assert(false, "ERROR");
			} else if(action.getTyp() == TableType.Shift) {
				log();
				this.parseStack.pushBack(action.getNumber());
				input = this.getToken();
			} else if(action.getTyp() == TableType.Reduce) {
				log();
				// do action
				// pop RHS of Production
				this.parseStack.popBack(rules[action.getNumber].length-1);
				this.parseStack.pushBack(
					this.getGoto(rules[action.getNumber][0]));
			}
		}
		this.printStack();
		log();
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
