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

struct Parse {
	private int id;
	private long tokenBufIdx;
	private Parser parser;
	private Deque!(int) parseStack;
	private Deque!(Token) tokenStack;
	private AST ast;

	this(Parser parser, int id) {
		this.parser = parser;
		this.id = id;
		this.parseStack = new Deque!(int)(128);
		this.tokenStack = new Deque!(Token)(128);
		// we start at state (zero null none 0)
		this.parseStack.pushBack(0);

		this.ast = new AST();
		long tokenBufIdx = 0;
	}

	this(Parser parser, Parse toCopy) {
		this.parser = parser;
		this.parseStack = new Deque!(int)(toCopy.parseStack);
		this.tokenStack = new Deque!(Token)(toCopy.tokenStack);
		this.tokenBufIdx = toCopy.tokenBufIdx;
		this.ast = new AST(toCopy.ast);
		this.tokenBufIdx = toCopy.tokenBufIdx;
	}

	package AST getAst() {
		return this.ast;
	}

	private Token getToken() {
		return this.parser.increToNextToken(this.tokenBufIdx++);
	}

	private immutable(TableItem[]) getAction(const Token input) const {
		immutable(Pair!(int,immutable(immutable(TableItem)[]))) retError = 
			Pair!(int,immutable(immutable(TableItem)[]))(int.min, 
			[TableItem(TableType.Error, 0)]);

		//log("%d %d", this.parseStack.back(), input.getTyp());

		immutable(Pair!(int,immutable(immutable(TableItem)[]))) toSearch = 
			Pair!(int,immutable(immutable(TableItem)[]))(
			input.getTyp(), [TableItem(false)]);

		immutable(immutable(Pair!(int,immutable(immutable(TableItem)[])))[]) row
			= parseTable[this.parseStack.back()];

		bool found;
		size_t foundIdx;

		auto ret = binarySearch!((TitP))
			(row, toSearch, retError, row.length, found, foundIdx,
			function(immutable(Pair!(int,immutable(TableItem[]))) a, 
					immutable(Pair!(int,immutable(TableItem[]))) b) {
				return a.first > b.first;
			}, 
			function(immutable(Pair!(int,immutable(TableItem[]))) a, 
					immutable(Pair!(int,immutable(TableItem[]))) b) {
				return a.first == b.first; });

		return ret.second;
	}

	private short getGoto(const int input) const {
		immutable(Pair!(int,immutable(immutable(TableItem)[]))) retError = 
			Pair!(int,immutable(immutable(TableItem)[]))(int.min, 
			[TableItem(TableType.Error, 0)]);

		//log("%d %d", this.parseStack.back(), input.getTyp());

		immutable(Pair!(int,immutable(immutable(TableItem)[]))) toSearch = 
			Pair!(int,immutable(immutable(TableItem)[]))(
			input, [TableItem(false)]);

		/*immutable(Pair!(int,immutable(TableItem))) retError = 
			Pair!(int,immutable(TableItem))(int.min, 
			TableItem(TableType.Error, 0));

		immutable(Pair!(int,immutable(TableItem))) toSearch = 
			Pair!(int,immutable(TableItem))(input, TableItem(false));*/

		auto row = gotoTable[this.parseStack.back()];
		bool found;
		size_t foundIdx;

		auto ret = binarySearch!((TitP))
			(row, toSearch, retError, row.length, found, foundIdx,
			function(immutable(Pair!(int,immutable(TableItem[]))) a, 
					immutable(Pair!(int,immutable(TableItem[]))) b) {
				return a.first > b.first;
			}, 
			function(immutable(Pair!(int,immutable(TableItem[]))) a, 
					immutable(Pair!(int,immutable(TableItem[]))) b) {
				return a.first == b.first; });

		/*auto ret = binarySearch!(immutable(Pair!(int,immutable(TableItem))))
			(row, toSearch, retError, row.length, found, foundIdx,
			function(immutable(Pair!(int,immutable(TableItem))) a, 
					immutable(Pair!(int,immutable(TableItem))) b) {
				return a.first > b.first;
			}, 
			function(immutable(Pair!(int,immutable(TableItem))) a, 
					immutable(Pair!(int,immutable(TableItem))) b) {
				return a.first == b.first; });*/

		return ret.second[0].getNumber();
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

	public void parse(size_t actIdx) {
		TableItem action;
		Token input = this.getToken();
		//this.tokenStack.pushBack(input);
		//log("%s", input.toString());
		
		action = this.getAction(input)[0]; 
		assert(false, "look one line up idiot");
		//log("%s", action.toString());
		if(action.getTyp() == TableType.Accept) {
			//log("%s %s", action.toString(), input.toString());
			this.parseStack.popBack(rules[action.getNumber()].length-1);
			this.runAction(action.getNumber());
			return;
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
}

class Parser {
	private Lexer lexer;
	private Deque!(Token) tokenBuffer;
	private Deque!(Token) tokenStore;
	private Deque!(Parse) parses;
	private int nextId;

	public this(Lexer lexer) {
		this.lexer = lexer;	
		this.tokenBuffer = new Deque!(Token)(64);
		this.tokenStore = new Deque!(Token)(128);
		this.parses = new Deque!(Parse)(16);
		this.parses.pushBack(Parse(this,this.nextId++));
	} 

	public AST getAst() {
		assert(!this.parses.isEmpty());
		return this.parses.front().getAst();
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

	package Token increToNextToken(long idx) {
		if(idx + 1 == this.tokenStore.getSize()) {
			this.tokenStore.pushBack(this.getToken());
		}

		return this.tokenStore[idx++];
	}

	public void parse() {
	}
}
