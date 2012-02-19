module parsetable;

import hurt.conv.conv;
import hurt.string.stringbuffer;
import hurt.util.pair;

public enum TableType : byte {
	Accept,
	Error,
	Reduce,
	Goto,
	Shift
}

public struct TableItem {
	public TableType typ;
	public short number;
	private byte padding; // align to 32 bit

	this(TableType st, short number) {
		this.typ = st;
		this.number = number;
	}

	public string toString() const {
		scope StringBuffer!(char) ret = new StringBuffer!(char)(16);
		
		final switch(this.typ) {
			case TableType.Accept:
				ret.pushBack("Accept:");
				break;
			case TableType.Error:
				ret.pushBack("Error:");
				break;
			case TableType.Reduce:
				ret.pushBack("Reduce:");
				break;
			case TableType.Goto:
				ret.pushBack("Goto:");
				break;
			case TableType.Shift:
				ret.pushBack("Shift:");
				break;
		}

		ret.pushBack(conv!(short,string)(this.number));

		return ret.getString();
	}
}

public static immutable int termdecrement = 10;
public static immutable int termdiv = 6;
public static immutable int termdollar = -1;
public static immutable int termepsilon = -2;
public static immutable int termfloat = 12;
public static immutable int termincrement = 9;
public static immutable int terminteger = 11;
public static immutable int termminus = 4;
public static immutable int termmodulo = 7;
public static immutable int termplus = 3;

public static immutable(Pair!(int,TableItem)[][23]) table = [
[Pair!(int,TableItem)(3,TableItem(TableType.Shift, 3)), 
Pair!(int,TableItem)(4,TableItem(TableType.Shift, 4)), 
Pair!(int,TableItem)(9,TableItem(TableType.Shift, 7)), 
Pair!(int,TableItem)(10,TableItem(TableType.Shift, 8)), 
Pair!(int,TableItem)(11,TableItem(TableType.Shift, 9)), 
Pair!(int,TableItem)(12,TableItem(TableType.Shift, 10))],

[Pair!(int,TableItem)(-1,TableItem(TableType.Accept, -1)), 
Pair!(int,TableItem)(3,TableItem(TableType.Shift, 11)), 
Pair!(int,TableItem)(4,TableItem(TableType.Shift, 12))],

[Pair!(int,TableItem)(-1,TableItem(TableType.Reduce, 1)), 
Pair!(int,TableItem)(3,TableItem(TableType.Reduce, 1)), 
Pair!(int,TableItem)(4,TableItem(TableType.Reduce, 1)), 
Pair!(int,TableItem)(6,TableItem(TableType.Shift, 13)), 
Pair!(int,TableItem)(7,TableItem(TableType.Shift, 14))],

[Pair!(int,TableItem)(3,TableItem(TableType.Shift, 3)), 
Pair!(int,TableItem)(4,TableItem(TableType.Shift, 4)), 
Pair!(int,TableItem)(9,TableItem(TableType.Shift, 7)), 
Pair!(int,TableItem)(10,TableItem(TableType.Shift, 8)), 
Pair!(int,TableItem)(11,TableItem(TableType.Shift, 9)), 
Pair!(int,TableItem)(12,TableItem(TableType.Shift, 10))],

[Pair!(int,TableItem)(3,TableItem(TableType.Shift, 3)), 
Pair!(int,TableItem)(4,TableItem(TableType.Shift, 4)), 
Pair!(int,TableItem)(9,TableItem(TableType.Shift, 7)), 
Pair!(int,TableItem)(10,TableItem(TableType.Shift, 8)), 
Pair!(int,TableItem)(11,TableItem(TableType.Shift, 9)), 
Pair!(int,TableItem)(12,TableItem(TableType.Shift, 10))],

[Pair!(int,TableItem)(-1,TableItem(TableType.Reduce, 4)), 
Pair!(int,TableItem)(3,TableItem(TableType.Reduce, 4)), 
Pair!(int,TableItem)(4,TableItem(TableType.Reduce, 4)), 
Pair!(int,TableItem)(6,TableItem(TableType.Reduce, 4)), 
Pair!(int,TableItem)(7,TableItem(TableType.Reduce, 4))],

[Pair!(int,TableItem)(-1,TableItem(TableType.Reduce, 7)), 
Pair!(int,TableItem)(3,TableItem(TableType.Reduce, 7)), 
Pair!(int,TableItem)(4,TableItem(TableType.Reduce, 7)), 
Pair!(int,TableItem)(6,TableItem(TableType.Reduce, 7)), 
Pair!(int,TableItem)(7,TableItem(TableType.Reduce, 7))],

[Pair!(int,TableItem)(3,TableItem(TableType.Shift, 3)), 
Pair!(int,TableItem)(4,TableItem(TableType.Shift, 4)), 
Pair!(int,TableItem)(9,TableItem(TableType.Shift, 7)), 
Pair!(int,TableItem)(10,TableItem(TableType.Shift, 8)), 
Pair!(int,TableItem)(11,TableItem(TableType.Shift, 9)), 
Pair!(int,TableItem)(12,TableItem(TableType.Shift, 10))],

[Pair!(int,TableItem)(3,TableItem(TableType.Shift, 3)), 
Pair!(int,TableItem)(4,TableItem(TableType.Shift, 4)), 
Pair!(int,TableItem)(9,TableItem(TableType.Shift, 7)), 
Pair!(int,TableItem)(10,TableItem(TableType.Shift, 8)), 
Pair!(int,TableItem)(11,TableItem(TableType.Shift, 9)), 
Pair!(int,TableItem)(12,TableItem(TableType.Shift, 10))],

[Pair!(int,TableItem)(-1,TableItem(TableType.Reduce, 12)), 
Pair!(int,TableItem)(3,TableItem(TableType.Reduce, 12)), 
Pair!(int,TableItem)(4,TableItem(TableType.Reduce, 12)), 
Pair!(int,TableItem)(6,TableItem(TableType.Reduce, 12)), 
Pair!(int,TableItem)(7,TableItem(TableType.Reduce, 12))],

[Pair!(int,TableItem)(-1,TableItem(TableType.Reduce, 13)), 
Pair!(int,TableItem)(3,TableItem(TableType.Reduce, 13)), 
Pair!(int,TableItem)(4,TableItem(TableType.Reduce, 13)), 
Pair!(int,TableItem)(6,TableItem(TableType.Reduce, 13)), 
Pair!(int,TableItem)(7,TableItem(TableType.Reduce, 13))],

[Pair!(int,TableItem)(3,TableItem(TableType.Shift, 3)), 
Pair!(int,TableItem)(4,TableItem(TableType.Shift, 4)), 
Pair!(int,TableItem)(9,TableItem(TableType.Shift, 7)), 
Pair!(int,TableItem)(10,TableItem(TableType.Shift, 8)), 
Pair!(int,TableItem)(11,TableItem(TableType.Shift, 9)), 
Pair!(int,TableItem)(12,TableItem(TableType.Shift, 10))],

[Pair!(int,TableItem)(3,TableItem(TableType.Shift, 3)), 
Pair!(int,TableItem)(4,TableItem(TableType.Shift, 4)), 
Pair!(int,TableItem)(9,TableItem(TableType.Shift, 7)), 
Pair!(int,TableItem)(10,TableItem(TableType.Shift, 8)), 
Pair!(int,TableItem)(11,TableItem(TableType.Shift, 9)), 
Pair!(int,TableItem)(12,TableItem(TableType.Shift, 10))],

[Pair!(int,TableItem)(3,TableItem(TableType.Shift, 3)), 
Pair!(int,TableItem)(4,TableItem(TableType.Shift, 4)), 
Pair!(int,TableItem)(9,TableItem(TableType.Shift, 7)), 
Pair!(int,TableItem)(10,TableItem(TableType.Shift, 8)), 
Pair!(int,TableItem)(11,TableItem(TableType.Shift, 9)), 
Pair!(int,TableItem)(12,TableItem(TableType.Shift, 10))],

[Pair!(int,TableItem)(3,TableItem(TableType.Shift, 3)), 
Pair!(int,TableItem)(4,TableItem(TableType.Shift, 4)), 
Pair!(int,TableItem)(9,TableItem(TableType.Shift, 7)), 
Pair!(int,TableItem)(10,TableItem(TableType.Shift, 8)), 
Pair!(int,TableItem)(11,TableItem(TableType.Shift, 9)), 
Pair!(int,TableItem)(12,TableItem(TableType.Shift, 10))],

[Pair!(int,TableItem)(-1,TableItem(TableType.Reduce, 11)), 
Pair!(int,TableItem)(3,TableItem(TableType.Reduce, 11)), 
Pair!(int,TableItem)(4,TableItem(TableType.Reduce, 11)), 
Pair!(int,TableItem)(6,TableItem(TableType.Reduce, 11)), 
Pair!(int,TableItem)(7,TableItem(TableType.Reduce, 11))],

[Pair!(int,TableItem)(-1,TableItem(TableType.Reduce, 10)), 
Pair!(int,TableItem)(3,TableItem(TableType.Reduce, 10)), 
Pair!(int,TableItem)(4,TableItem(TableType.Reduce, 10)), 
Pair!(int,TableItem)(6,TableItem(TableType.Reduce, 10)), 
Pair!(int,TableItem)(7,TableItem(TableType.Reduce, 10))],

[Pair!(int,TableItem)(-1,TableItem(TableType.Reduce, 8)), 
Pair!(int,TableItem)(3,TableItem(TableType.Reduce, 8)), 
Pair!(int,TableItem)(4,TableItem(TableType.Reduce, 8)), 
Pair!(int,TableItem)(6,TableItem(TableType.Reduce, 8)), 
Pair!(int,TableItem)(7,TableItem(TableType.Reduce, 8))],

[Pair!(int,TableItem)(-1,TableItem(TableType.Reduce, 9)), 
Pair!(int,TableItem)(3,TableItem(TableType.Reduce, 9)), 
Pair!(int,TableItem)(4,TableItem(TableType.Reduce, 9)), 
Pair!(int,TableItem)(6,TableItem(TableType.Reduce, 9)), 
Pair!(int,TableItem)(7,TableItem(TableType.Reduce, 9))],

[Pair!(int,TableItem)(-1,TableItem(TableType.Reduce, 2)), 
Pair!(int,TableItem)(3,TableItem(TableType.Reduce, 2)), 
Pair!(int,TableItem)(4,TableItem(TableType.Reduce, 2)), 
Pair!(int,TableItem)(6,TableItem(TableType.Shift, 13)), 
Pair!(int,TableItem)(7,TableItem(TableType.Shift, 14))],

[Pair!(int,TableItem)(-1,TableItem(TableType.Reduce, 3)), 
Pair!(int,TableItem)(3,TableItem(TableType.Reduce, 3)), 
Pair!(int,TableItem)(4,TableItem(TableType.Reduce, 3)), 
Pair!(int,TableItem)(6,TableItem(TableType.Shift, 13)), 
Pair!(int,TableItem)(7,TableItem(TableType.Shift, 14))],

[Pair!(int,TableItem)(-1,TableItem(TableType.Reduce, 5)), 
Pair!(int,TableItem)(3,TableItem(TableType.Reduce, 5)), 
Pair!(int,TableItem)(4,TableItem(TableType.Reduce, 5)), 
Pair!(int,TableItem)(6,TableItem(TableType.Reduce, 5)), 
Pair!(int,TableItem)(7,TableItem(TableType.Reduce, 5))],

[Pair!(int,TableItem)(-1,TableItem(TableType.Reduce, 6)), 
Pair!(int,TableItem)(3,TableItem(TableType.Reduce, 6)), 
Pair!(int,TableItem)(4,TableItem(TableType.Reduce, 6)), 
Pair!(int,TableItem)(6,TableItem(TableType.Reduce, 6)), 
Pair!(int,TableItem)(7,TableItem(TableType.Reduce, 6))]];


public static immutable(Pair!(int,TableItem)[][23]) gotoTable = [
[Pair!(int,TableItem)(1,TableItem(TableType.Goto, 1)), 
Pair!(int,TableItem)(2,TableItem(TableType.Goto, 2)), 
Pair!(int,TableItem)(5,TableItem(TableType.Goto, 5)), 
Pair!(int,TableItem)(8,TableItem(TableType.Goto, 6))],

[],

[],

[Pair!(int,TableItem)(5,TableItem(TableType.Goto, 15)), 
Pair!(int,TableItem)(8,TableItem(TableType.Goto, 6))],

[Pair!(int,TableItem)(5,TableItem(TableType.Goto, 16)), 
Pair!(int,TableItem)(8,TableItem(TableType.Goto, 6))],

[],

[],

[Pair!(int,TableItem)(5,TableItem(TableType.Goto, 17)), 
Pair!(int,TableItem)(8,TableItem(TableType.Goto, 6))],

[Pair!(int,TableItem)(5,TableItem(TableType.Goto, 18)), 
Pair!(int,TableItem)(8,TableItem(TableType.Goto, 6))],

[],

[],

[Pair!(int,TableItem)(2,TableItem(TableType.Goto, 19)), 
Pair!(int,TableItem)(5,TableItem(TableType.Goto, 5)), 
Pair!(int,TableItem)(8,TableItem(TableType.Goto, 6))],

[Pair!(int,TableItem)(2,TableItem(TableType.Goto, 20)), 
Pair!(int,TableItem)(5,TableItem(TableType.Goto, 5)), 
Pair!(int,TableItem)(8,TableItem(TableType.Goto, 6))],

[Pair!(int,TableItem)(5,TableItem(TableType.Goto, 21)), 
Pair!(int,TableItem)(8,TableItem(TableType.Goto, 6))],

[Pair!(int,TableItem)(5,TableItem(TableType.Goto, 22)), 
Pair!(int,TableItem)(8,TableItem(TableType.Goto, 6))],

[],

[],

[],

[],

[],

[],

[],

[]];

