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
	
	def static String getUserModelComment() {
		return '''
		% Translated user model
		
		'''
	}
	def static String getMetaModel() {
		return '''
		% Require existence of root element

		Atom::of(toExecute, ToExecute).
		
		
		% SysML v2 - M2 element definitions

		abstract class Type {
		    Type[0..*] directSpecializedType
		}

		default !directSpecializedType(*, *).
		
		pred specializedType(Type sub, Type super) <->
		    directSpecializedType+(sub, super)
		.
		

		class Classifier extends Type {
		    Classifier[0..*] directSuperclass subsets directSpecializedType
		    Feature[0..*] typeFeaturing
		}

		!exists(Classifier::new).
		default !typeFeaturing(*, *).

		pred superclass(Classifier sub, Classifier super) <->
		    directSuperclass+(sub, super)
		.
		
		Classifier(Anything). atom Anything.
		

		class Feature extends Type {
		    Classifier[1..*] featureTyping subsets directSpecializedType
		    Feature[0..*] directSubsettedFeature subsets directSpecializedType
		    Feature[0..*] directRedefinedFeature subsets directSubsettedFeature
		    int lowerBound
		    int upperBound
		}

		!exists(Feature::new).
		default !featureTyping(*, *).
		default !directSubsettedFeature(*, *).
		default !directRedefinedFeature(*, *).

		pred subsettedFeature(Feature sub, Feature super) <->
		    directSubsettedFeature+(sub, super)
		.

		pred redefinedFeature(Feature sub, Feature super) <->
		    directRedefinedFeature(sub, super)
		.
		
		Feature(things). atom things.
		typeFeaturing(Anything, things).
		featureTyping(things, Anything).
		directSpecializedType(things, Anything).
		

		class Atom {
		    Classifier[1] of
		}
		
		@decide(false)
		class FeatureAtom {
		    Feature[1] of
		    Atom[1] domain
		    Atom[1] value
		}
		
		
		
		% SysML v2 - Atom constraints and execution rules
		import builtin::strategy.

		pred CorrectFeatureAtom(FeatureAtom a) <->
		    typeFeaturing(tft, f),
		    featureTyping(f, ftt),
		    FeatureAtom::of(a, f),
		    FeatureAtom::domain(a, da),
		    FeatureAtom::value(a, va),
		    Atom::of(da, tft),
		    Atom::of(va, ftt)
		.

		pred specificFeatureAtom(domainAtom, featureAtom, feature, valueAtom) <->
		    FeatureAtom::of(featureAtom, feature),
		    domain(featureAtom, domainAtom),
		    value(featureAtom, valueAtom)
		.
		
		pred featureAtomOfType(domainAtom, feature, valueAtom) <->
		    specificFeatureAtom(domainAtom, _, feature, valueAtom)
		.
		
		error invalidDomainType(domainAtom, featureAtom) <->
		    specificFeatureAtom(domainAtom, featureAtom, feature, _),
		    Atom::of(domainAtom, type),
		    !typeFeaturing(type, feature)
		.
		
		error invalidValueType(featureAtom, valueAtom) <->
		    specificFeatureAtom(_, featureAtom, feature, valueAtom),
		    Atom::of(valueAtom, type),
		    !featureTyping(feature, type)
		.
		
		error duplicateFeatureAtom(domainAtom, valueAtom) <->
		    featureAtomOfType(domainAtom, feature, valueAtom),
		    count { featureAtomOfType(domainAtom, feature, valueAtom) } > 1
		.
		
		error invalidMultiplicity(domainAtom, feature) <->
		    Atom::of(domainAtom, type),
		    typeFeaturing(type, feature),
		    c is count { featureAtomOfType(domainAtom, feature, _) },
		    c < lowerBound(feature) || c > upperBound(feature)
		.
		
		@priority(2)
		decision rule addFeatureAtomToLowerBound(domainAtom, @focus featureAtom, feature, valueType, @focus valueAtom) <->
		    Atom::of(domainAtom, domainType),
		    typeFeaturing(domainType, feature),
		    featureTyping(feature, valueType),
		    count { must featureAtomOfType(a, feature, _) } < lowerBound(feature),
		    !must featureAtomOfType(domainAtom, feature, valueAtom)
		==>
		    FeatureAtom::of(featureAtom, feature),
		    domain(featureAtom, domainAtom),
		    value(featureAtom, valueAtom),
		    Atom::of(valueAtom, valueType)
		.

		decision rule addOptionalFeatureAtom(domainAtom, @focus featureAtom, feature, valueType, @focus valueAtom) <->
		    Atom::of(domainAtom, domainType),
		    typeFeaturing(domainType, feature),
		    featureTyping(feature, valueType),
		    count { must featureAtomOfType(domainAtom, feature, _) } < upperBound(feature),
		    !must featureAtomOfType(domainAtom, feature, valueAtom)
		==>
		    FeatureAtom::of(featureAtom, feature),
		    domain(featureAtom, domainAtom),
		    value(featureAtom, valueAtom),
		    Atom::of(valueAtom, valueType)
		.
		'''
	}
}