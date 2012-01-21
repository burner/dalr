import util

class GrammerItem():
	def __init__(self, name):
		self.name = name

class GrammerRule():
	def __init__(self, start):
		self.start = start
		self.rules = []

	def addProduction(self, rule):
		print(rule)
		self.rules.append(rule)

	def __str__(self):
		ret = str(self.start).join(" := \n")
		for rule in self.rules:
			ret.join([str(it) for it in range(rule)])
			ret.join('\n')

		return ret


def parseFile(filename):
	f = open(filename, 'r')	
	productions = dict()

	States = util.enum("No", "Production", "Alternativ", "Action")
	state = States.No
	linenumber = 0
	last = None
	tmp = []
	# run over the complete file
	for line in f:
		linenumber += 1

		items = line.split()
		if len(items) == 0: # ignore empty lines
			continue

		newProdStart = -1
		alternativ = -1
		userCodeStart = -1
		userCodeEnd = -1
		semicolom = -1

		try:
			newProdStart = items.index(":=")
		except ValueError:
			pass

		try:
			alternativ = items.index("|")
		except ValueError:
			pass

		try:
			semicolom = items.index(";")
		except ValueError:
			pass

		try:
			actionStart = items.index("{:")
		except ValueError:
			pass

		try:
			actionEnd = items.index(":}")
		except ValueError:
			pass

		if state == States.No:
			if newProdStart != -1:
				prod = None
				if items[0] in productions:
					prod = productions[items[0]]
				else:
					prod = GrammerRule(items[0])
					productions[items[0]] = prod
					
				if semicolom != -1:
					prod.addProduction(items[2:semicolom])
				else:
					last = prod
					tmp.append(items[2:])
					state = States.Production
		elif state == States.Production:
			if semicolom != -1:
				tmp.append(items[:semicolom])
				last.addProduction(tmp)
				tmp = []
				if actionStart != -1 and actionEnd != -1:
					state = States.No
				elif actionStart != -1 and actionEnd == -1:
					state = States.Action


	return productions
		
if __name__ == "__main__":
	prod = parseFile("../examplegrammer.dlr")
	for key in prod:
		print(key, prod[key])
