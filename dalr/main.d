module dalr.main;

import dalr.productionmanager;

import hurt.io.stdio;
import hurt.container.deque;

void main() {
	ProductionManager a = new ProductionManager();
	a.insertProduction(new Deque!(int)([0,3,2,5]));
	a.insertProduction(new Deque!(int)([0,6,2,7]));
	print(a.toString());
}
