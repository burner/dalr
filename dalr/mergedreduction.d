module dalr.mergedreduction;

import hurt.container.deque;
import hurt.container.set;

class MergedReduction {
	private int finalSet;
	private Set!(int) followSet;
	private Set!(int) rules;
	private Set!(int) preMergedRules;

	this(int finalSet) {
		this.finalSet = finalSet;
	}
}
