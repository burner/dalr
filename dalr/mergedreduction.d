module dalr.mergedreduction;

import hurt.container.deque;
import hurt.container.set;
import hurt.container.map;

class MergedReduction {
	private size_t finalSet;
	private Map!(int, Set!(size_t)) follow;

	this(size_t finalSet) {
		this.finalSet = finalSet;
		this.follow = new Map!(int, Set!(size_t))();
	}

	public void insert(int followItem, size_t followRule) {
		MapItem!(int, Set!(size_t)) mi = follow.find(followItem);
		if(mi !is null) {
			mi.getData().insert(followRule);
		} else {
			Set!(size_t) tmp = new Set!(size_t)();
			tmp.insert(followRule);
			this.follow.insert(followItem, tmp);
		}
	}

	public Map!(int, Set!(size_t)) getFollowMap() {
		return this.follow;
	}
}
