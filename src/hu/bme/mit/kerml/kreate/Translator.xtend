package hu.bme.mit.kerml.kreate

import java.util.List
import org.omg.sysml.lang.sysml.Classifier
import org.omg.sysml.lang.sysml.Feature
import org.omg.sysml.util.FeatureUtil
import org.omg.sysml.lang.sysml.LiteralInteger
import org.omg.sysml.lang.sysml.LiteralInfinity
import java.util.Collection
import org.eclipse.emf.ecore.EObject

class Translator {
	
	def static String translate(Classifier classifier, Collection<EObject> objects) {
		return hu.bme.mit.kerml.kreate.Translator.classifierTemplate(classifier) +
			classifier.relevantFeatures.map[translate(it.mostSpecificNonFeatureType, objects)].join
	}
	
	def static String classifierTemplate(Classifier classifier) {
		val featureDefinitions = classifier.relevantFeatures
			.map[featureTemplate(
				it,
				classifier,
				it.mostSpecificNonFeatureType
			)]
			.join("\n")
		return '''
		Classifier(«classifier.name»).
		directSuperclass(«classifier.name», Anything).
		directSpecializedType(«classifier.name», Anything).

		''' + featureDefinitions
	}
	def private static String featureTemplate(Feature feature, Classifier featuringType, Classifier featureType) {
		return '''
		Feature(«feature.declaredName»).
		typeFeaturing(«featuringType.declaredName», «feature.declaredName»).
		directSubsettedFeature(«feature.declaredName», things).
		directSpecializedType(«feature.declaredName», things).
		featureTyping(«feature.declaredName», «featureType.declaredName»).
		directSpecializedType(«feature.declaredName», «featureType.declaredName»).
		lowerBound(«feature.declaredName»): «feature.lower».
		upperBound(«feature.declaredName»): «feature.upper».
		'''
	}
	
	def private static List<Feature> relevantFeatures(Classifier classifier) {
		return classifier.feature.filter[it |
			"self" != it.declaredName &&
			"that" != it.declaredName
		].toList
	}
	
	def private static Classifier mostSpecificNonFeatureType(Feature feature) {
		var classifierTypes = feature.type.filter[it instanceof Classifier].map[it as Classifier]
		
		for (Classifier classifier : classifierTypes) {
			if (!classifierTypes.map[classifier.allSupertypes.contains(it)].contains(true)) {
				return classifier
			}
		}
		throw new RuntimeException('''No most specific classifier type found for «feature.type».''')
	}
	
	def private static int upper(Feature feature) {
		var ub = FeatureUtil.getMultiplicityRangeOf(feature.multiplicity).upperBound
		if (ub instanceof LiteralInteger) {
			return (ub as LiteralInteger).value
		} else if (ub instanceof LiteralInfinity) {
			return 999
		} else {
			throw new RuntimeException("Upper multiplicity was not LiteralInteger or LiteralInfinity.")
		} 
	}

	def private static int lower(Feature feature) {
		var lb = FeatureUtil.getMultiplicityRangeOf(feature.multiplicity).lowerBound
		if (lb === null) {
			lb = FeatureUtil.getMultiplicityRangeOf(feature.multiplicity).upperBound
		}
		if (lb instanceof LiteralInteger) {
			return (lb as LiteralInteger).value
		} else if (lb instanceof LiteralInfinity) {
			return 0
		} else {
			return -1
		}
	}
}