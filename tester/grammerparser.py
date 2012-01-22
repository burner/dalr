import util

class GrammerItem():
	def __init__(self, name):
		self.name = name

class GrammerRule():
	def __init__(self, start):
		self.start = start
		self.rules = []

	def addProduction(self, rule):
		self.rules.append(rule)

	def __str__(self):
		ret = self.start +  " := \n"
		for rule in self.rules:
			for item in rule:
				ret = ret + item + ' '
			ret += '\n'

		return ret


def parseFile(filename):
	f = open(filename, 'r')	
	productions = dict()

	States = util.enum("No", "Production", "Alternativ", "UserCode")
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

		try:
			newProdStart = items.index(":=")
		except ValueError:
			pass

		try:
			alternativ = items.index("|")
		except ValueError:
			pass

		try:
			userCodeStart = items.index("{:")
		except ValueError:
			pass

		try:
			userCodeEnd = items.index(":}")
		except ValueError:
			pass

		if state == States.No:
			if newProdStart != -1: # a new production
				prod = None
				if items[0] in productions:
					prod = productions[items[0]]
				else:
					prod = GrammerRule(items[0])
					productions[items[0]] = prod

				if userCodeStart != -1:
					prod.addProduction(items[2:userCodeStart])
					state = States.UserCode
				else:
					tmp.extend(items[2:])
					state = States.Production
				last = prod # prod is the new last

				continue
			elif alternativ != -1: # a new alternativ to the last production
				if userCodeStart != -1:
					last.addProduction(items[1:userCodeStart])
					state = States.UserCode
				else:
					tmp.extend(items)
					state = States.Production

				continue
		elif state == States.Production:
			if newProdStart != -1: # found a new production so save the old
				last.addProduction(tmp)
				tmp = []
				if items[0] in productions:
					prod = productions[items[0]]
				else:
					prod = GrammerRule(items[0])
					productions[items[0]] = prod
				if userCodeStart != -1:
					prod.addProduction(items[2:userCodeStart])
					state = States.UserCode
				else:
					tmp.extend(items[2:])
					state = States.Production
				last = prod # prod is the new last
			elif alternativ != -1:
				last.addProduction(tmp)
				tmp = []
				if items[0] in productions:
					prod = productions[items[0]]
				else:
					prod = GrammerRule(items[0])
					productions[items[0]] = prod
				if userCodeStart != -1:
					prod.addProduction(items[2:userCodeStart])
					state = States.UserCode
				else:
					tmp.extend(items[2:])
					state = States.Production
				last = prod # prod is the new last
			elif userCodeStart != -1: # found a usercode
				tmp.extended(items[0:userCodeStart])
				last.addProductions(tmp)
				tmp = []
				state = States.UserCode
		#elif state == States.Alternativ:
		elif state == States.UserCode:
			if userCodeEnd != -1:
				state = States.No
			continue
		else:
			assert False, state	

	return productions
		
if __name__ == "__main__":
	prod = parseFile("../d2short.dlr")
	for key in prod:
		print(key, prod[key].rules)
