module dalr.itemsettrie;

import dalr.item;
import dalr.itemset;

import hurt.container.deque;
import hurt.container.map;
import hurt.container.isr;
import hurt.io.stdio;

private class TrieNode(T,S) {
	private Deque!(T) member;
	private Map!(S,TrieNode!(T,S)) follow;

	this() {
		this.follow = new Map!(S,TrieNode!(T,S))(ISRType.HashTable);
		this.member = new Deque!(T)();
	}

	bool insert(const(Deque!(S)) path, size_t idx, T object) {
		if(idx == path.getSize()-1) { // reached the end of the path
			this.member.pushBack(object);
			return true;
		} else if(idx < path.getSize()-1 && // path present
				follow.contains(path.opIndexConst(idx))) {
			return this.follow.find(path.opIndexConst(idx)).getData().
				insert(path, idx+1, object);
		} else if(idx < path.getSize()-1 && // path not present
				!follow.contains(path.opIndexConst(idx))) {
			TrieNode!(T,S) node = new TrieNode!(T,S)();
			this.follow.insert(path.opIndexConst(idx), node);
			return node.insert(path, idx+1, object);
		} else {
			assert(false, "shouldn't be reached");
		}
	}

	bool contains(const(Deque!(S)) path, size_t idx) {
		if(idx == path.getSize()-1) {
			return this.member.getSize() > 0;
		} else {
			return this.follow.find(path.opIndexConst(idx)).getData().
				contains(path, idx+1);
		}
	}
}

class Trie(T,S) {
	private Map!(S,TrieNode!(T,S)) follow;
	private size_t size;

	this() {
		this.size = 0;
		this.follow = new Map!(S,TrieNode!(T,S))(ISRType.HashTable);
	}

	bool insert(Deque!(S) path, T object) {
		assert(path.getSize() > 0);
		if(this.follow.contains(path[0])) { // first symbol allready present
			return this.follow.find(path[0]).getData().insert(path, 1, object);
		} else { // need to insert the first symbol into the root
			TrieNode!(T,S) node = new TrieNode!(T,S)();
			this.follow.insert(path[0], node);
			return node.insert(path, 1, object);
		}
		assert(this.follow.contains(path[0]));
	}

	bool contains(const(Deque!(S)) path) {
		// trie path must be at least one element long
		assert(path.getSize() > 0);
		if(this.follow.contains(path.opIndexConst(0))) { 
			return this.follow.find(path.opIndexConst(0)).getData().
				contains(path, 1);
		} else {
			return false;
		}
	}
}

unittest {
	Trie!(int,int) t = new Trie!(int,int)();
	t.insert(new Deque!(int)([1,2,3,4,5,6,7,8]), 99);
	t.insert(new Deque!(int)([1,2,3,4,5,6,7,8,9]), 999);
	assert(t.contains(new Deque!(int)([1,2,3,4,5,6,7,8])));
	assert(t.contains(new Deque!(int)([1,2,3,4,5,6,7,8,9])));
	printfln("itemsettrie passed");	
}
