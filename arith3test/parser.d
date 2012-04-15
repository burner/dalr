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

class Parse {
	private int id;
	private long tokenBufIdx;
	private Parser parser;
	private Deque!(int) parseStack;
	private Deque!(Token) tokenStack;
	private AST ast;
	private Token input;

	this(Parser parser, int id) {
		this.parser = parser;
		this.id = id;
		this.parseStack = new Deque!(int)(128);
		this.tokenStack = new Deque!(Token)(128);
		// we start at state (zero null none 0)
		this.parseStack.pushBack(0);

		this.ast = new AST();
		this.tokenBufIdx = 0;
		this.input = this.getToken();
	}

	this(Parser parser, Parse toCopy, int id) {
		this.parser = parser;
		this.parseStack = new Deque!(int)(toCopy.parseStack);
		this.tokenStack = new Deque!(Token)(toCopy.tokenStack);
		this.tokenBufIdx = toCopy.tokenBufIdx;
		this.ast = new AST(toCopy.ast);
		this.tokenBufIdx = toCopy.tokenBufIdx;
		this.input = toCopy.input;
		this.id = id;
	}

	package int getId() const {
		return this.id;
	}

	package AST getAst() {
		return this.ast;
	}

	private Token getToken() {
		return this.parser.increToNextToken(this.tokenBufIdx++);
	}

	//public immutable(TableItem[]) getAction(const Token input) const {
	public immutable(TableItem[]) getAction() const {
		immutable(Pair!(int,immutable(immutable(TableItem)[]))) retError = 
			Pair!(int,immutable(immutable(TableItem)[]))(int.min, 
			[TableItem(TableType.Error, 0)]);

		//log("%d %d", this.parseStack.back(), input.getTyp());

		immutable(Pair!(int,immutable(immutable(TableItem)[]))) toSearch = 
			Pair!(int,immutable(immutable(TableItem)[]))(
			this.input.getTyp(), [TableItem(false)]);

		immutable(immutable(Pair!(int,immutable(TableItem[])))[]) row
			= parseTable[this.parseStack.back()];

		bool found;
		size_t foundIdx;

		auto ret = binarySearch!(TitP)
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

		immutable(Pair!(int,immutable(immutable(TableItem)[]))) toSearch = 
			Pair!(int,immutable(immutable(TableItem)[]))(
			input, [TableItem(false)]);

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


		assert(ret.second.length == 1);
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

	public bool step(immutable(TableItem[]) actionTable, size_t actIdx) {
		TableItem action = actionTable[actIdx];
		//Token input = this.getToken();
		//this.tokenStack.pushBack(input);
		//log("%s", input.toString());
		
		//action = this.getAction(input)[actIdx]; 
		//log("%s", action.toString());
		if(action.getTyp() == TableType.Accept) {
			//log("%s %s", action.toString(), input.toString());
			this.parseStack.popBack(rules[action.getNumber()].length-1);
			this.runAction(action.getNumber());
			return true;
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
		return false;
	}
}

class Parser {
	private Lexer lexer;
	private Deque!(Token) tokenBuffer;
	private Deque!(Token) tokenStore;
	private Deque!(Parse) parses;
	private Deque!(Parse) newParses;
	private Deque!(Parse) acceptingParses;
	private Deque!(int) toRemove;
	private int nextId;

	public this(Lexer lexer) {
		this.lexer = lexer;	
		this.tokenBuffer = new Deque!(Token)(64);
		this.tokenStore = new Deque!(Token)(128);
		this.parses = new Deque!(Parse)(16);
		this.parses.pushBack(new Parse(this,this.nextId++));
		this.newParses = new Deque!(Parse)(16);
		this.acceptingParses = new Deque!(Parse)(16);
		this.toRemove = new Deque!(int)(16);
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
		while(!this.parses.isEmpty()) {
			for(size_t i = 0; i < this.parses.getSize(); i++) {
				immutable(TableItem[]) actions = this.parses[i].getAction();
				if(actions.length > 1) {
					for(size_t j = 1; j < actions.length; j++) {
						Parse tmp = new Parse(this, this.parses[i], 
							this.nextId++);
						if(tmp.step(actions, j)) {
							this.acceptingParses.pushBack(this.parses[i]);
						} else {
							this.newParses.pushBack(tmp);
						}
					}
				}
				if(this.parses[i].step(actions, 0)) {
					this.toRemove.pushBack(this.parses[i].getId);
					this.acceptingParses.pushBack(this.parses[i]);
				}
				
			}
			// copy all new parses
			while(!this.newParses.isEmpty()) {
				this.parses.pushBack(this.newParses.popBack());
			}

			// remove all accepting parses
			this.parses.removeFalse(delegate(Parse a) {
				return this.toRemove.containsNot(a.getId()); });

			// call merge function for all parse that are equal
		}
	}
}
