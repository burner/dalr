module ast;

import hurt.container.deque;

import token;

struct ASTNode {
	private Token token;
	private Deque!(size_t) childs;

	this(Token token) {
		this.token = token;
		this.childs = new Deque!(size_t)(16);
	}
}
