package hu.bme.mit.kerml.kreate

import java.util.List
import org.omg.sysml.lang.sysml.Classifier
import org.omg.sysml.lang.sysml.Feature

class Templates {
	static def String classifier(Classifier classifier) {
		val featureDefinitions = classifier.relevantFeatures
			.map[feature(
				it.declaredName,
				Translator.mostSpecificNonFeatureType(it.type).declaredName,
				classifier.declaredName
			)].join("\n")
		return '''
		Classifier(«classifier.name»).
		directSuperclass(«classifier.name», Anything).
		directSpecializedType(«classifier.name», Anything).

		''' + featureDefinitions
	}
	
	private static def String feature(String name, String typeName, String classifierName) {
		return '''
		Feature(«name»).
		typeFeaturing(«classifierName», «name»).
		directSubsettedFeature(«name», things).
		directSpecializedType(«name», things).
		featureTyping(«name», «typeName»).
		directSpecializedType(«name», «typeName»).
		'''
	}
	
	private static def List<Feature> relevantFeatures(Classifier classifier) {
		return classifier.feature.filter[it |
			"self" != it.declaredName &&
			"that" != it.declaredName
		].toList
	}
	
}