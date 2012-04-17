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
		log();
		this.input = this.getToken();
		log();
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

	public override bool opEquals(Object o) @trusted {
		Parse p = cast(Parse)o;

		if(this.tokenBufIdx != p.tokenBufIdx) {
			return false;
		}

		// no need to compare every element if the size is not equal
		if(this.parseStack.getSize() != p.parseStack.getSize()) {
			return false;
		}

		// compare the parseStack from the back to the front
		// because the difference should be at the back
		for(auto it = this.parseStack.cEnd(), jt = p.parseStack.cEnd(); 
				it.isValid() && jt.isValid(); it--, jt--) {
			if(*it != *jt) {
				return false;
			}
		}

		return true;
	}

	package const(Token) getCurrentInput() const {
		return this.input;
	}

	package int getTos() const {
		return this.parseStack[this.parseStack.getSize()-1];
	}

	package AST getAst() {
		return this.ast;
	}

	private Token getToken() {
		return this.parser.increToNextToken(this.tokenBufIdx++);
	}

	private Token buildTree(immutable int retType, immutable(int[]) tokens, 
			immutable int startPosIdx = 0) {

		assert(tokens !is null);
		assert(tokens.length > 0);
		size_t pos = this.ast.insert(this.tokenStack[tokens[startPosIdx]],
			retType);

		foreach(idx, it; tokens) {
			if(idx == startPosIdx) { // ignore the head of the tree
				continue;
			}

			Token tmp = this.tokenStack[it];
			this.ast.append(tmp.getTreeIdx());
		}
		return Token(this.tokenStack[tokens[startPosIdx]].getLoc(), retType, 
			pos);
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
		log("%s", ret.toString());
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
		printfln("%?1!1s in state %?1!1d on input %?1!1s this is parse %d", 
			"ERROR", this.parseStack.back(), input.toString(), this.id);
		this.printStack();
	}

	public int step(immutable(TableItem[]) actionTable, size_t actIdx) {
		TableItem action = actionTable[actIdx];
		//Token input = this.getToken();
		//this.tokenStack.pushBack(input);
		//log("%s", input.toString());
		
		//action = this.getAction(input)[actIdx]; 
		//log("%s", action.toString());
		if(action.getTyp() == TableType.Accept) {
			log("%s %s", action.toString(), input.toString());
			this.parseStack.popBack(rules[action.getNumber()].length-1);
			this.runAction(action.getNumber());
			return 1;
		} else if(action.getTyp() == TableType.Error) {
			//log();
			this.reportError(input);
			return -1;
		} else if(action.getTyp() == TableType.Shift) {
			log("%s", input.toString());
			//log();
			this.parseStack.pushBack(action.getNumber());
			this.tokenStack.pushBack(input);
			input = this.getToken();
		} else if(action.getTyp() == TableType.Reduce) {
			log("%d %d %d", this.id, rules[action.getNumber()].length-1, 
				this.parseStack.getSize());
			// do action
			// pop RHS of Production
			this.parseStack.popBack(rules[action.getNumber()].length-1);
			this.parseStack.pushBack(
				this.getGoto(rules[action.getNumber()][0]));

			// tmp token stack stuff
			this.runAction(action.getNumber());
			log();
		}
		printfln("id %d ast %s", this.id, this.ast.toStringGraph());
		return 0;
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
		log();
		this.lexer = lexer;	
		this.tokenBuffer = new Deque!(Token)(64);
		this.tokenStore = new Deque!(Token);
		assert(this.tokenStore.isEmpty());
		assert(this.tokenStore.getSize() == 0, 
			format("%d", this.tokenStore.getSize()));
		this.parses = new Deque!(Parse)(16);
		log();
		this.nextId = 0;
		this.parses.pushBack(new Parse(this,this.nextId++));
		this.newParses = new Deque!(Parse)(16);
		this.acceptingParses = new Deque!(Parse)(16);
		this.toRemove = new Deque!(int)(16);
		log();
	} 

	public AST getAst() {
		assert(!this.acceptingParses.isEmpty());
		return this.acceptingParses.front().getAst();
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
		//log("%d %d", idx, this.tokenStore.getSize());
		if(idx + 1 >= this.tokenStore.getSize()) {
			//log();
			this.tokenStore.pushBack(this.getToken());
		}
		//log("%u", this.tokenStore.getSize());

		return this.tokenStore[idx++];
	}

	private int merge(Parse a, Parse b) {
		return a.getId();
	}

	private void mergeRun(Deque!(Parse) parse) {
		// early exit if only one parse is left
		if(parse.getSize() <= 1) {
			return;
		}
		// remove all accepting parses or merged away parses
		// call merge function for all parse that are equal
		for(size_t i = 0; i < parse.getSize() - 1; i++) {
			if(this.toRemove.contains(parse[i].getId())) {
				continue;
			}
			for(size_t j = i+1; j < parse.getSize(); j++) {
				if(this.toRemove.contains(parse[j].getId())) {
					continue;
				}

				// for every tow parse that are equal call the merge 
				// function
				if(parse[i] == parse[j]) {
					this.toRemove.pushBack(
						this.merge(parse[i], parse[j]) 
					);
				}
			}
		}
	}

	public void parse() {
		log();
		while(!this.parses.isEmpty()) {
			// for every parse
			for(size_t i = 0; i < this.parses.getSize(); i++) {
				// get all actions
				immutable(TableItem[]) actions = this.parses[i].getAction();
				// if there are more than one action we found a conflict
				if(actions.length > 1) {
					log("fork at id %d, tos %d, input %s, number of actions %d",
						this.parses[i].getId(), this.parses[i].getTos(),
						this.parses[i].getCurrentInput().toString(), 
						actions.length);
					for(size_t j = 1; j < actions.length; j++) {
						Parse tmp = new Parse(this, this.parses[i], 
							this.nextId++);
						int rslt = tmp.step(actions, j);
						if(rslt == 1) {
							this.acceptingParses.pushBack(this.parses[i]);
							this.toRemove.pushBack(this.parses[i].getId);
						} else if(rslt == -1) {
							this.toRemove.pushBack(this.parses[i].getId);
						} else {
							this.newParses.pushBack(tmp);
						}
					}
				}

				// after all one action is left
				int rslt = this.parses[i].step(actions, 0);
				if(rslt == 1) {
					this.acceptingParses.pushBack(this.parses[i]);
					this.toRemove.pushBack(this.parses[i].getId);
				} else if(rslt == -1) {
					this.toRemove.pushBack(this.parses[i].getId);
				} 
			}
			// copy all new parses
			while(!this.newParses.isEmpty()) {
				this.parses.pushBack(this.newParses.popBack());
			}

			this.mergeRun(this.parses);

			this.parses.removeFalse(delegate(Parse a) {
				return this.toRemove.containsNot(a.getId()); });
		}
		log();

		// this is necessary because their might be more than one accepting 
		// parse
		this.mergeRun(this.acceptingParses);
	}
}
