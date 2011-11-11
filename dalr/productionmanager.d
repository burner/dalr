module dalr.productionmanager;

import hurt.container.deque;
import hurt.conv.conv;
import hurt.io.stdio;
import hurt.string.formatter;
import hurt.string.stringbuffer;

class ProductionManager {
	private Deque!(Deque!(int)) prod;

	this() {
		this.prod = new Deque!(Deque!(int));
	}

	private bool doesProductionExists(Deque!(int) toTest) {
		foreach(it; prod) {
			if(it == toTest) {
				return true;
			}
		}
		return false;
	}

	public void insertProduction(Deque!(int) toInsert) {
		assert(toInsert.getSize() > 0, "empty production not allowed");
		if(this.doesProductionExists(toInsert)) {
			throw new Exception(
				format("production %s does allready exist", 
					this.productionToString(toInsert)));
		} else {
			assert(this.prod !is null);
			size_t oldSize = this.prod.getSize();
			this.prod.pushBack(toInsert);
			assert(oldSize+1 == this.prod.getSize());
		}
	}

	public string productionToString(Deque!(int) pro) {
		assert(pro.getSize() > 0);
		StringBuffer!(char) sb = new StringBuffer!(char)(pro.getSize() * 4);
		Iterator!(int) it = pro.begin();
		assert(it.isValid());
		for(size_t idx = 0;it.isValid(); it++, idx++) {
			string tmp = this.productionItemToString(*it);
			assert(tmp != "");
			sb.pushBack(tmp);	
			if(idx == 0) {
				sb.pushBack(" -> ");
			} else {
				sb.pushBack(" ");
			}
		}
		sb.pushBack("\n");
		string ret = sb.getString();
		assert(ret != "");
		return ret;
	}

	public string productionItemToString(const int item) const {
		return conv!(int,string)(item);
	}
	
	public override string toString() {
		assert(this.prod.getSize() > 0);
		StringBuffer!(char) sb = 
			new StringBuffer!(char)(this.prod.getSize()*10);
		Iterator!(Deque!(int)) it = this.prod.begin();
		assert(it.isValid());
		for(;it.isValid(); it++) {
			sb.pushBack(this.productionToString(*it));
		}
		return sb.getString();
	}
}

unittest {
	ProductionManager pm = new ProductionManager();
	assert("1" == pm.productionItemToString(1));
}
