module dalr.mergedreduction;

import hurt.container.deque;
import hurt.container.set;
import hurt.container.map;
import hurt.container.isr;
import hurt.string.formatter;

class MergedReduction {
	private size_t finalSet;
	private Map!(int, Set!(size_t)) follow; // needed
	private Map!(int, Set!(size_t)) extFollow; // debug, this are the old rule
		// numbers of reduction step 1

	this(size_t finalSet) {
		this.finalSet = finalSet;
		this.follow = new Map!(int, Set!(size_t))();
		this.extFollow = new Map!(int, Set!(size_t))();
	}

	public void insert(int followItem, size_t followRule, size_t extRule) {
		// the followRule rule
		MapItem!(int, Set!(size_t)) mi = follow.find(followItem);
		if(mi !is null) {
			mi.getData().insert(followRule);
		} else {
			Set!(size_t) tmp = new Set!(size_t)();
			tmp.insert(followRule);
			this.follow.insert(followItem, tmp);
		}

		// the old rule
		MapItem!(int, Set!(size_t)) mj = extFollow.find(followItem);
		if(mj !is null) {
			mj.getData().insert(extRule);
		} else {
			Set!(size_t) tmp = new Set!(size_t)();
			tmp.insert(extRule);
			this.extFollow.insert(followItem, tmp);
		}
	}

	public size_t getFinalSet() const {
		return this.finalSet;
	}

	public Map!(int, Set!(size_t)) getFollowMap() {
		return this.follow;
	}

	public ISRIterator!(size_t) iterator(int it) {
		auto mi = this.follow.find(it);
		if(mi !is null) {
			return mi.getData().begin();
		} else {
			return null;
		}
	}

	public Map!(int, Set!(size_t)) getExtFollowMap() {
		return this.extFollow;
	}
}
