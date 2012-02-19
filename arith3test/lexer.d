module lexer;

import hurt.algo.binaryrangesearch;
import hurt.container.map;
import hurt.container.stack;
import hurt.container.deque;
import hurt.conv.conv;
import hurt.io.file;
import hurt.io.stdio;
import hurt.io.stream;
import hurt.string.formatter;
import hurt.string.stringbuffer;
import hurt.string.utf;
import hurt.util.slog;
import hurt.util.pair;

import lextable;
import parsetable;
import token;

class Lexer {
	private string filename;
	private hurt.io.stream.BufferedFile file;

	private size_t lineNumber;
	private size_t charIdx;
	private dchar[] currentLine;
	private StringBuffer!(dchar) lexText;
	private Stack!(dchar) inputChar;
	private immutable dchar eol = '\n';
	private immutable dchar eof = '\0';

	public Deque!(Token) deque;

	private Location loc;

	// false means single run, true means step be step
	private bool kind;

	this(string filename, bool kind = false) {
		this.filename = filename;
		this.lineNumber = 0;
		this.inputChar = new Stack!(dchar)();
		this.deque = new Deque!(Token)(128);

		if(!exists(this.filename)) {
			throw new Exception(__FILE__ ~ ":" ~ conv!(int,string)(__LINE__) ~
				this.filename ~ " does not exists");
		}

		this.file = null;
		this.file = new hurt.io.stream.BufferedFile(this.filename);
		this.lexText = new StringBuffer!(dchar)(128);
		this.getNextLine();

		this.kind = false;
	}

	~this() {
	}

	public void printFile() {
		foreach(char[] it; this.file) {
			foreach(char jt; it)
				print(jt);
			println();
		}
	}

	private dstring getCurrentLex() const {
		return this.lexText.getString();
	}

	private size_t getCurrentLineCount() const {
		return this.lineNumber;
	}

	private size_t getCurrentIndexInLine() const {
		return this.charIdx;
	}

	public string getFilename() const {
		return this.filename;
	}

	private bool isEOF() {
		return this.file.eof();	
	}

	private stateType getNextState(dchar inputChar, stateType currentState) 
			const {
		size_t column = binarySearchRange!(dchar,size_t)(inputRange, inputChar,
			-2);
		size_t row = stateMapping[conv!(stateType,size_t)(currentState)];
		if(column == -2) {
			return -1;
		}
		return lextable.table[row][column];
	}

	public bool isEmpty() {
		return this.isEOF() && (this.currentLine is null || 
			this.charIdx > this.currentLine.length);
	}

	private void getNextLine() {
		char[] tmp = this.file.readLine();
		if(tmp !is null) {
			this.currentLine = toUTF32Array(tmp);
			this.charIdx = 0;
		} else {
			this.currentLine = null;
		}
		this.lineNumber++;
	}

	private dchar getCurrentChar() {
		if(this.isEmpty()) {
			return eof;
		} else if(this.charIdx >= this.currentLine.length) {
			this.getNextLine();
			return eol;
		} else {
			return this.currentLine[this.charIdx];
		}
	}

	private dchar getNextChar() {
		if(!this.inputChar.isEmpty()) {
			return this.inputChar.pop();
		} else if(this.isEmpty()) {
			return eof;
		} else if(this.charIdx >= this.currentLine.length) {
			this.getNextLine();
			return eol;
		} else {
			assert(this.charIdx < this.currentLine.length, 
				conv!(size_t,string)(this.charIdx) ~ " " ~
				conv!(size_t,string)(this.currentLine.length));

			return this.currentLine[this.charIdx++];
		}
	}

	public void acceptingAction(stateType acceptingState) {
		switch(acceptingState) {
				mixin(acceptAction);
			default:
				assert(false, format("no action for %d defined",
					acceptingState));
		}
	}

	public Location getLoc() {
		return this.loc;
	}

	public void saveLocation() {
		this.loc = Location(this.filename, this.getCurrentLineCount(),
			this.getCurrentIndexInLine());
	}

	private bool errorFunction(stateType currentState, stateType nextState, 
			dchar input) {
		return false;
	}

	public void run() {
		stateType currentState = 0;
		stateType nextState = -1;
		this.saveLocation();
		while(!this.isEmpty()) {
			dchar nextChar = this.getNextChar();
			log("%c", nextChar);
			nextState = this.getNextState(nextChar, currentState);
			if(nextState != -1) { // simplie a next state
				currentState = nextState;
				lexText.pushBack(nextChar);
			// accepting state
			} else if(nextState == -1) { 
				stateType accept = isAcceptingState(currentState);
				if(accept != -1) {
					//log("%2d accept number %d", currentState, accept);
					inputChar.push(nextChar);
					this.acceptingAction(accept);
					this.lexText.clear();
					currentState = 0;
					this.saveLocation();
				} else {
					if(this.errorFunction(currentState, nextState, nextChar)) {
						currentState = 0;
						this.saveLocation();
						this.lexText.clear();
					} else {
						assert(false, 
							format("we failed with state %d and nextstate %d, 
							" ~ "inputchar was %c", currentState, 
							nextState, nextChar));
					}
				}
				if(this.kind) { // single step
					return;
				}
			}
		}

		// we are done but there their might be a state left
		if(currentState == 0) {
			//ok I guess
			return;
		} else if(isAcceptingState(currentState)) {
			this.acceptingAction(currentState);
			this.lexText.clear();
			return;
		} else {
			//hm not so cool
			assert(false, format("no more input when in state %d", 
				currentState));
		}
		this.file.close();
	}
}