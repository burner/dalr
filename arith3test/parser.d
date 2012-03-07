module parser;

import hurt.algo.binaryrangesearch;
import hurt.container.deque;
import hurt.io.stdio;
import hurt.util.pair;
import hurt.util.slog;
import hurt.string.formatter;

import ast;
import lexer;
import parsetable;
import token;

class Parser {
	private Lexer lexer;
	private Deque!(Token) tokenBuffer;
	private Deque!(int) parseStack;
	private Deque!(Token) tokenStack;
	private AST ast;

	public this(Lexer lexer) {
		this.lexer = lexer;	
		this.tokenBuffer = new Deque!(Token)(64);
		this.parseStack = new Deque!(int)(128);
		this.tokenStack = new Deque!(Token)(128);
		this.ast = new AST();
	} 

	AST getAST() {
		return this.ast;
	}

	/** do not call this direct unless you want whitespace token
	 */
	private Token getNextToken() { 
		if(this.tokenBuffer.isEmpty()) {
			this.lexer.getToken(this.tokenBuffer);
		} 
		assert(!this.tokenBuffer.isEmpty());

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

		//log("%d %d", this.parseStack.back(), input.getTyp());

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

	private void runAction(short actionNum) {
		Token ret;
		switch(actionNum) {
			mixin(actionString);
			default:
				assert(false, format("no action for %d defined", actionNum));
		}
		//log("%s", ret.toString());
		this.tokenStack.popBack(rules[actionNum].length-1);
		this.tokenStack.pushBack(ret);
	}

	private void printStack() const {
		printf("parse stack: ");
		foreach(it; this.parseStack) {
			printf("%d ", it);
		}
		println();
	}

	private void printTokenStack() const {
		printf("token stack: ");
		foreach(it; this.tokenStack) {
			printf("%s ", it.toStringShort());
		}
		println();
	}

	private void reportError(const Token input) const {
		printfln("%?1!1s in state %?1!1d on input %?1!1s", "ERROR", 
			this.parseStack.back(), input.toString());
		this.printStack();
	}

	public void parse() {
		// we start at state (zero null none 0)
		this.parseStack.pushBack(0);

		TableItem action;
		Token input = this.getToken();
		//this.tokenStack.pushBack(input);
		//log("%s", input.toString());
		
		while(true) { 
			this.printStack();
			this.printTokenStack();
			//println(this.ast.toString());
			action = this.getAction(input); 
			//log("%s", action.toString());
			if(action.getTyp() == TableType.Accept) {
				//log("%s %s", action.toString(), input.toString());
				this.parseStack.popBack(rules[action.getNumber()].length-1);
				this.runAction(action.getNumber());
				break;
			} else if(action.getTyp() == TableType.Error) {
				//log();
				this.reportError(input);
				assert(false, "ERROR");
			} else if(action.getTyp() == TableType.Shift) {
				log("%s", input.toString());
				//log();
				this.parseStack.pushBack(action.getNumber());
				this.tokenStack.pushBack(input);
				input = this.getToken();
			} else if(action.getTyp() == TableType.Reduce) {
				log();
				// do action
				// pop RHS of Production
				this.parseStack.popBack(rules[action.getNumber()].length-1);
				this.parseStack.pushBack(
					this.getGoto(rules[action.getNumber()][0]));

				// tmp token stack stuff
				this.runAction(action.getNumber());
			}
		}
		log();
		this.printStack();
		this.printTokenStack();
		//log("%s", this.ast.toString());
	}

	public void run() {
		outer: while(true) {
			auto it = this.getToken();
			if(it.getTyp() == -99) {
				continue;
			}
			//log("%s %d", it.toString(), it.getTyp());
			if(it.getTyp() == termdollar) {
				break outer;
			}
		}
	}
}
