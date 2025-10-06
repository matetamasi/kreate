package hu.bme.mit.kerml.kreate

import hu.bme.mit.kerml.kreate.model.Graph

class Backannotator {
	
	def static String toKerml(String concreteModel, String packageName) {
 		var graph = Graph.generate(concreteModel)
		var r = '''
		package «packageName» {
			private import test::*;
			private import Atoms::*;

			«FOR i : graph.atoms.sortBy[it.generatedName]»
					«var featureAtoms = graph.featureAtoms»
					#atom
					classifier «i.generatedName» specializes «i.of.name»«
					IF !featureAtoms.map[it.domain].contains(i)»;
					«ELSE» {
						«var features = featureAtoms.filter[it.domain == i].map[it.of].toSet»
						«FOR f : features»
						«IF graph.featureAtoms.filter[it.domain == i && it.of == f].size == 1»
						 «var fa = graph.featureAtoms.filter[it.domain == i && it.of == f].get(0)»
						feature «fa.generatedName» : «fa.value.generatedName» redefines «f.name» [«featureAtoms.filter[it.domain == i && it.of == f].size»];
						«ELSE»
						feature redefines «f.name» [«featureAtoms.filter[it.domain == i && it.of == f].size»];
						«FOR a : graph.featureAtoms.filter[it.domain == i]»
							feature «a.generatedName» : «a.value.generatedName» [1] :> «f.name»;
						«ENDFOR»
						«ENDIF»
						«ENDFOR»
					}«ENDIF»«ENDFOR»
		}
		'''
		return r

	}
	
}