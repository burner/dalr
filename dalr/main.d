module dalr.main;

import dalr.productionmanager;
import dalr.grammerparser;

import hurt.container.deque;
import hurt.io.stdio;

void main() {
	ProductionManager a = new ProductionManager();
	a.insertProduction(new Deque!(int)([0,3,2,5]));
	a.insertProduction(new Deque!(int)([0,6,2,7]));
	print(a.toString());
	GrammerParser gp = new GrammerParser();
}
