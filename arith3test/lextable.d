module lextable;

import hurt.algo.binaryrangesearch;
import hurt.string.formatter;

public struct Location {
	private string file;
	private size_t row;
	private size_t column;

	public this(string file, size_t row, size_t column) {
		this.file = file;
		this.row = row;
		this.column = column;
	}
	
	public string getFile() const {
		return this.file;
	}

	public size_t getRow() const {
		return this.row;
	}

	public size_t getColumn() const {
		return this.column;
	}
}

alias byte stateType;

immutable byte[] stateMapping = [
 0, 1, 2, 3, 3, 4, 5, 3, 6, 1, 3, 3];

public static immutable(byte[][]) table = [
[  2,  3,  4,  5,  6, -1,  7,  8],
[ -1, -1, -1, -1, -1, -1, -1,  9],
[  2, -1, -1, -1, -1, -1, -1, -1],
[ -1, -1, -1, -1, -1, -1, -1, -1],
[ -1, -1, -1, 11, -1, -1, -1, -1],
[ -1, -1, -1, -1, 10, -1, -1, -1],
[ -1, -1, -1, -1, -1,  1, -1,  8]];

public static stateType isAcceptingState(stateType state) {
	switch(state) {
		case -1:
			return -1;
		case 0:
			return 10;
		case 1:
			return -1;
		case 2:
			return 10;
		case 3:
			return 6;
		case 4:
			return 5;
		case 5:
			return 7;
		case 6:
			return 4;
		case 7:
			return 3;
		case 8:
			return 8;
		case 9:
			return 9;
		case 10:
			return 2;
		case 11:
			return 1;
		default:
			assert(false, format("an invalid state with id %d was passed",
				state));
	}
}

public static immutable(Range!(dchar,size_t)[9]) inputRange = [
	Range!(dchar,size_t)('\t','\n',0),Range!(dchar,size_t)(' ',0),
	Range!(dchar,size_t)('%',1),Range!(dchar,size_t)('*',2),
	Range!(dchar,size_t)('+',3),Range!(dchar,size_t)('-',4),
	Range!(dchar,size_t)('.',5),Range!(dchar,size_t)('/',6),
	Range!(dchar,size_t)('0','9',7)];

public static immutable(string) acceptAction = 
`	case 1: {
 this.deque.pushBack(Token(this.getLoc(), termdecrement)); 
		}
		break;
	case 2: {
 this.deque.pushBack(Token(this.getLoc(), termincrement)); 
		}
		break;
	case 3: {
 this.deque.pushBack(Token(this.getLoc(), termdiv)); 
		}
		break;
	case 4: {
 this.deque.pushBack(Token(this.getLoc(), termminus)); 
		}
		break;
	case 5: {
 this.deque.pushBack(Token(this.getLoc(), termstar)); 
		}
		break;
	case 6: {
 this.deque.pushBack(Token(this.getLoc(), termmodulo)); 
		}
		break;
	case 7: {
 this.deque.pushBack(Token(this.getLoc(), termplus)); 
		}
		break;
	case 8: {
 this.deque.pushBack(Token(this.getLoc(), terminteger, this.getCurrentLex())); 
		}
		break;
	case 9: {
 this.deque.pushBack(Token(this.getLoc(), terminteger, this.getCurrentLex())); 
		}
		break;
	case 10: {
 
		}
		break;
`;