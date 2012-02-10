module dalr.filewriter;

import hurt.io.stream;
import hurt.container.deque;
import hurt.string.stringbuffer;
import hurt.string.formatter;
import hurt.util.slog;
import hurt.util.pair;
import hurt.algo.sorting;

import dalr.finalitem;
import dalr.productionmanager;
import dalr.symbolmanager;

abstract class Writer {
	private string filename;
	private string modulename;
	private File file;
	private SymbolManager sm;
	private ProductionManager pm;

	this(string filename, string modulename, 
			SymbolManager sm, ProductionManager pm) {
		// save the parameter
		this.filename = filename;
		this.modulename = modulename;
		this.sm = sm;
		this.pm = pm;

		// create the output file
		log();
		this.file = new File(this.filename, FileMode.OutNew);
		log();
		this.writeHeader();
		log();
		this.file.write('\n');
		log();
	}

	private void writeHeader() {
		this.file.writeString(format("module %s;\n\n", this.modulename));
		this.file.writeString("import hurt.util.pair;\n");
	}

	public void close() {
		this.file.close();
	}

	public void write();
}

final class RuleWriter : Writer {
	private bool glr;
	this(string filename, string modulename, 
			SymbolManager sm, ProductionManager pm,
			bool glr) {
		super(filename, modulename, sm, pm);
		this.glr = glr;
	}

	public override void write() {
		log();
		this.writeStackItemAndStackItemEnum();
		log();
		this.writeTable();
		log();
		//this.writeTable();
		this.file.write('\n');
	}

	private void writeStackItemAndStackItemEnum() {
		// the StackType Enum
		this.file.writeString(
			"public enum StackType : byte {\n" ~
				"\tAccept,\n" ~
				"\tError,\n" ~
				"\tReduce,\n" ~
				"\tShift\n" ~
			"}\n");

		this.file.write('\n');

		// this is the kind of item that is placed on the stack
		this.file.writeString(
			"public struct StackItem {\n" ~
				"\tpublic StackType typ;\n" ~
				"\tpublic ushort number;\n" ~
			"}\n\n");
	}

	private void writeTable() {
		Deque!(Deque!(Deque!(FinalItem))) table = this.pm.getFinalTable();
		StringBuffer!(char) sb = new StringBuffer!(char)(1024);
		if(this.glr) {
			sb.pushBack(format(
				"public static immutable(Pair!(int,StackItem[][][%u])) " ~
				"table = [\n", table.getSize()-1));
		} else {
			sb.pushBack(format(
				"public static immutable(Pair!(int,StackItem[][%u])) " ~
				"table = [\n", table.getSize()-1));
		}

		foreach(size_t idx, Deque!(Deque!(FinalItem)) row; table) {
			if(idx == 0) { // don't need the items
				continue;
			}
			
			// to sort it for the binary search
			Deque!(Pair!(int,Deque!(FinalItem))) tmp = 
				new Deque!(Pair!(int,Deque!(FinalItem)))(row.getSize()); 

			foreach(size_t jdx, Deque!(FinalItem) jt; row) {
				if(jdx == 0) { // don't need the itemset number
					continue;
				}
				tmp.pushBack(Pair!(int,Deque!(FinalItem))
					(table[0][jdx][0].number, jt));
			}

			// sort it
			sortDeque(tmp, function(in Pair!(int,Deque!(FinalItem)) a,
				in Pair!(int,Deque!(FinalItem)) b) {
					return a.first > b.first;
				});

			size_t 

			if(this.glr) {
				sb.pushBack(\n"[Pair!(int,StackItem)[]\n");
			} else {
				sb.pushBack(\n"[\n");
			}

			foreach(size_t jdx, Deque!(FinalItem jt), tmp) {
			}

		}
		sb.pushBack("]\n");
			
		this.file.writeString(sb.getString());
		sb.clear();
			
/*
		foreach(size_t idx, Deque!(Deque!(FinalItem)) it; table) {
			if(idx == 0) { // first row contains names
				continue;
			}

			// run the row, but only print items present
			inner: foreach(size_t jdx, Deque!(FinalItem) jt; it) {
				if(jdx == 0) {
					ret.pushBack(format("ItemSet %u: ", jt[0].number));
				} else {
					if(jt.getSize() > 0 && !allTypsAreError(jt)) {
						ret.pushBack(format("{%s:", 
							sm.getSymbolName(table[0][jdx][0].number)));
					} else {
						continue inner;
					}
					foreach(size_t kdx, FinalItem kt; jt) {
						if(kt.typ == Type.Accept) {
							ret.pushBack("$,");
						} else if(kt.typ == Type.Shift) {
							ret.pushBack(format("s%d,", kt.number));
						} else if(kt.typ == Type.Reduce) {
							ret.pushBack(format("r%d,", kt.number));
						} else if(kt.typ == Type.Goto) {
							ret.pushBack(format("g%d,", kt.number));
						} else {
							//assert(false, typeToString(kt.typ));
							//ret.pushBack(format("e%d,", kt.number));
						}
					}
					ret.popBack();
					ret.pushBack("},");
				}
			}
			ret.popBack();
			ret.pushBack("\n");
		}
		ret.pushBack("\n");
		return ret.getString();
		*/
	}
}
