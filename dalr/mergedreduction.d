module dalr.mergedreduction;

import hurt.container.deque;
import hurt.container.set;

class MergedReduction {
	private size_t finalSet;
	private Set!(int) followSet;
	private Set!(size_t) rules;
	private Set!(size_t) preMergedRules;

	this(size_t finalSet) {
		this.finalSet = finalSet;
	}

	public void insertRule(size_t rule) {
		this.rules.insert(rule);
	}

	public void insertPreMergedRule(size_t rule) {
		this.preMergedRules.insert(rule);
	}

}
