module parser;

import hurt.algo.binaryrangesearch;
import hurt.container.deque;
import hurt.io.stdio;
import hurt.util.pair;
import hurt.util.slog;
import hurt.util.util;
import hurt.string.formatter;
import hurt.string.stringbuffer;

import ast;
import lexer;
import lextable;
import parsetable;
import token;

class Parser {
	private Lexer lexer;
	private Deque!(Token) tokenBuffer;
	private Deque!(int) parseStack;
	private Deque!(Token) tokenStack;
	private bool lastTokenFound;
	private AST ast;

	public this(Lexer lexer) {
		this.lexer = lexer;	
		this.tokenBuffer = new Deque!(Token)(64);
		this.parseStack = new Deque!(int)(128);
		this.tokenStack = new Deque!(Token)(128);
		this.ast = new AST();
	} 

	public AST getAst() {
		return this.ast;
	}

	/** do not call this direct unless you want whitespace token
	 *  call getToken instead
	 */
	private Token getNextToken() { 
		if(this.lastTokenFound) {
			return Token(termdollar);
		}
		if(this.tokenBuffer.isEmpty()) {
			this.lexer.getToken(this.tokenBuffer);
		} 
		assert(!this.tokenBuffer.isEmpty());

		return this.tokenBuffer.popFront();
	}

	private Token getToken() {
		Token t = this.getNextToken();
		if(t.getTyp() == termdollar) {
			this.lastTokenFound = true;
		}
		while(t.getTyp() == -99) {
			if(t.getTyp() == termdollar) {
				this.lastTokenFound = true;
			}
			t = this.getNextToken();
		}
		return t;
	}

	private TableItem getAction(const Token input) const {
		immutable(Pair!(int,TableItem)) retError = Pair!(int,TableItem)(
			int.min, TableItem(TableType.Error, 0));


		//log("%d %d", this.parseStack.back(), input.getTyp());

		immutable(Pair!(int,TableItem)) toSearch = Pair!(int,TableItem)(
			input.getTyp(), TableItem(false));

		immutable(Pair!(int,TableItem)[]) row = cast(immutable)parseTable[
			this.parseStack.back()];

		bool found;
		size_t foundIdx;

		auto ret = binarySearch!(Pair!(int,TableItem))
			(row, toSearch, retError, row.length, found, foundIdx,
			function(immutable(Pair!(int,TableItem)) a, 
					immutable(Pair!(int,TableItem)) b) {
				return a.first > b.first;
			}, 
			function(immutable(Pair!(int,TableItem)) a, 
					immutable(Pair!(int,TableItem)) b) {
				return a.first == b.first; });

		return ret.second;
	}

	private short getGoto(const int input) const {
		immutable(Pair!(int,TableItem)) retError = Pair!(int,TableItem)(
			int.min, TableItem(TableType.Error, 0));

		immutable(Pair!(int,TableItem)) toSearch = Pair!(int,TableItem)(
			input, TableItem(false));
		auto row = gotoTable[this.parseStack.back()];
		bool found;
		size_t foundIdx;

		auto ret = binarySearch!(Pair!(int,TableItem))
			(row, toSearch, retError, row.length, found, foundIdx,
			function(immutable(Pair!(int,TableItem)) a, 
					immutable(Pair!(int,TableItem)) b) {
				return a.first > b.first;
			}, 
			function(immutable(Pair!(int,TableItem)) a, 
					immutable(Pair!(int,TableItem)) b) {
				return a.first == b.first; });

		/*auto ret = binarySearch!(Pair!(int,TableItem))
			(row, toSearch, retError, row.length, found, foundIdx,
			function(Pair!(int,TableItem) a, Pair!(int,TableItem) b) {
				return a.first > b.first;
			}, 
			function(Pair!(int,TableItem) a, Pair!(int,TableItem) b) {
				return a.first == b.first; });
		*/

		return ret.second.getNumber();
	}

	private void runAction(ulong actionNum) {
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

	private Token buildTreeWithLoc(immutable int retType, immutable(int[]) 
			tokens, size_t rule, Location loc) {

		assert(tokens !is null);
		assert(tokens.length > 0);

		// insert all the token that are not yet placed in the ast
		foreach(idx, it; tokens) {
			 if(!this.tokenStack[it].isPlacedInAst()) {
				size_t npos = this.ast.insert(
					this.tokenStack[it], // the token
					rules[rule][negIdx(rules[rule], it)]);
				this.tokenStack[it] = Token(this.tokenStack[it], npos);
				assert(this.tokenStack[it].getTreeIdx() == npos);
			 }
		}

		Token ret = Token(loc, retType);
		size_t pos = this.ast.insert(ret, retType);

		foreach(idx, it; tokens) {
			Token tmp = this.tokenStack[it];
			this.ast.append(tmp.getTreeIdx());
		}
		return Token(ret, pos);
	}

	private Token buildTree(immutable int retType, immutable(int[]) tokens, 
			size_t rule, immutable int startPosIdx = 0) {
		assert(tokens !is null);
		assert(tokens.length > 0);

		// insert all the token that are not yet placed in the ast
		foreach(idx, it; tokens) {
			if(idx == startPosIdx) { // ignore the head of the tree
				continue;
			 }
			 if(!this.tokenStack[it].isPlacedInAst()) {
				size_t npos = this.ast.insert(
					this.tokenStack[it], // the token
					rules[rule][negIdx(rules[rule], it)]);
				this.tokenStack[it] = Token(this.tokenStack[it], npos);
			 }
		}

		size_t pos = this.ast.insert(this.tokenStack[tokens[startPosIdx]],
			retType);

		foreach(idx, it; tokens) {
			if(idx == startPosIdx) { // ignore the head of the tree
				continue;
			}

			Token tmp = this.tokenStack[it];
			this.ast.append(tmp.getTreeIdx());
		}
		Token ret = Token(this.tokenStack[tokens[startPosIdx]].getLoc(), 
			retType, pos);
		return ret;
	}

	private void reportError(const Token input) const {
		printfln("%?1!1s in state %?1!1d on input %?1!1s", "ERROR", 
			this.parseStack.back(), input.toString());
		this.printStack();
	}

	public void funStuff() {
		log("HERE HERE HERE");
	}

	public bool parse() {
		// we start at state (zero null none 0)
		this.parseStack.pushBack(0);

		TableItem action;
		Token input = this.getToken();
		//this.tokenStack.pushBack(input);
		//log("%s", input.toString());
		
		while(true) { 
			//this.printStack();
			//this.printTokenStack();
			//println(this.ast.toString());
			action = this.getAction(input); 
			//log("%s", action.toString());
			if(action.getTyp() == TableType.Accept) {
				//log("%s %s", action.toString(), input.toString());
				this.parseStack.popBack(rules[action.getNumber()].length-1);
				this.runAction(cast(ulong)action.getNumber());
				break;
			} else if(action.getTyp() == TableType.Error) {
				//log();
				this.reportError(input);
				return false;
				//assert(false, "ERROR");
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
				this.runAction(cast(ulong)action.getNumber());
			}
		}
		log();
		//this.printStack();
		//this.printTokenStack();
		//log("%s", this.ast.toString());
		return true;
	}
}
