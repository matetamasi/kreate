package hu.bme.mit.kerml.kreate

import java.util.List
import org.omg.sysml.lang.sysml.Classifier
import org.omg.sysml.lang.sysml.Feature
import org.omg.sysml.util.FeatureUtil
import org.omg.sysml.lang.sysml.LiteralInteger
import org.omg.sysml.lang.sysml.LiteralInfinity
import java.util.Collection
import org.eclipse.emf.ecore.EObject
import java.util.Set
import java.util.HashSet

class Translator {

	def static String translate(Classifier classifier, Collection<EObject> objects) {
		var classifiersToTranslate = new HashSet
		var newClassifiers = Set.of(classifier)
		while (classifiersToTranslate.size < newClassifiers.size) {
			classifiersToTranslate.addAll(newClassifiers)
			val superClasses = classifiersToTranslate.flatMap[it.superclasses]
//			val features = classifiersToTranslate.flatMap[it.relevantFeatures]
			val featureClasses = classifiersToTranslate
				.flatMap[it.relevantFeatures]
				.flatMap[FeatureUtil.getAllTypesOf(it)]
				.filter[it instanceof Classifier]
				.map[it as Classifier]
			newClassifiers = (superClasses + featureClasses).toSet
		}
		
		return classifiersToTranslate.map[classifierTemplate(it)].join("\n") + "\n" + 
		classifiersToTranslate.map[c |
			c.relevantFeatures.map[f |
				featureTemplate(f, c)
			]
		].flatten.join("\n")

	}
	
	def static String classifierTemplate(Classifier classifier) {
		return '''
		Classifier(«classifier.name»).
		«FOR superclass : classifier.superclasses»
		directSuperclass(«classifier.name», «superclass.name»).
		directSpecializedType(«classifier.name», «superclass.name»).
		«ENDFOR»
		«IF classifier.abstract»
		isAbstract(«classifier.name»).
		«ENDIF»

		'''
	}
	def private static String featureTemplate(Feature feature, Classifier featuringType) {
		return '''
		Feature(«feature.declaredName»).
		typeFeaturing(«featuringType.declaredName», «feature.declaredName»).
«««		directSubsettedFeature(«feature.declaredName», things).
«««		directSpecializedType(«feature.declaredName», things).
		«IF !FeatureUtil.getRedefinedFeaturesOf(feature).empty»
		«FOR redefined : FeatureUtil.getRedefinedFeaturesOf(feature)»
		directRedefinedFeature(«feature.declaredName», «redefined.declaredName»).
		directSpecializedType(«feature.declaredName», «redefined.declaredName»).
		«ENDFOR»
		«ENDIF»
		«IF !FeatureUtil.getSubsettedFeaturesOf(feature).empty»
		«FOR subsetted : FeatureUtil.getSubsettedFeaturesOf(feature)»
		directSubsettedFeature(«feature.declaredName», «subsetted.declaredName»).
		directSpecializedType(«feature.declaredName», «subsetted.declaredName»).
		«ENDFOR»
		«ENDIF»
		«FOR featureType : FeatureUtil.getAllTypesOf(feature).filter[it instanceof Classifier]»
		featureTyping(«feature.declaredName», «featureType.declaredName»).
		directSpecializedType(«feature.declaredName», «featureType.declaredName»).
		«ENDFOR»
		lowerBound(«feature.declaredName»): «feature.lower».
		upperBound(«feature.declaredName»): «feature.upper».
		«IF feature.abstract»
		isAbstract(«feature.name»).
		«ENDIF»
		'''
	}
	
	def private static List<Feature> relevantFeatures(Classifier classifier) {
		return classifier.feature.filter[it |
			"self" != it.declaredName &&
			"that" != it.declaredName
		].toList
	}
	
	def private static int upper(Feature feature) {
		var mul = FeatureUtil.getMultiplicityRangeOf(feature.multiplicity)
		if (mul === null) {
			return 1
		}
		var ub = mul.upperBound
		if (ub instanceof LiteralInteger) {
			return (ub as LiteralInteger).value
		} else if (ub instanceof LiteralInfinity) {
			return 999
		} else {
			throw new RuntimeException("Upper multiplicity was not LiteralInteger or LiteralInfinity.")
		} 
	}
	
	def private static List<Classifier> superclasses(Classifier c) {
		return c.allSupertypes.filter[it instanceof Classifier].map[it as Classifier].toList
	}

	def private static int lower(Feature feature) {
		var mul = FeatureUtil.getMultiplicityRangeOf(feature.multiplicity)
		if (mul === null) {
			return 1
		}
		var lb = mul.lowerBound
		if (lb === null) {
			lb = mul.upperBound
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
		    boolean isAbstract
		}

		default !isAbstract(*).
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
		lowerBound(things): 0.
		upperBound(things): 999.
		typeFeaturing(Anything, things).
		featureTyping(things, Anything).
		directSpecializedType(things, Anything).


		class Atom {
		    @decide(false)
		    Classifier[1..*] of
		}

		@decide(false)
		class FeatureAtom {
		    @decide(false)
		    Feature[1..*] of
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

		error invalidDomainType(FeatureAtom featureAtom) <->
		    FeatureAtom::of(featureAtom, feature),
		    typeFeaturing(classifier, feature),
		    domain(featureAtom, domainAtom),
		    !Atom::of(domainAtom, classifier)
		.

		error invalidValueType(FeatureAtom featureAtom) <->
		    FeatureAtom::of(featureAtom, feature),
		    featureTyping(feature, classifier),
		    value(featureAtom, valueAtom),
		    !Atom::of(valueAtom, classifier)
		.

		error duplicateFeatureAtom(domainAtom, valueAtom) <->
		    featureAtomOfType(domainAtom, feature, valueAtom),
		    count { featureAtomOfType(domainAtom, feature, valueAtom) } > 1
		.

		error invalidMultiplicity(domainAtom, feature) <->
			!isAbstract(type),
		    Atom::of(domainAtom, type),
		    typeFeaturing(type, feature),
		    c is count { featureAtomOfType(domainAtom, feature, _) },
		    c < lowerBound(feature) || c > upperBound(feature)
		.
		
		error invalidSubsetting(Feature subsetting, Feature subsetted) <-> 
		    subsettedFeature(subsetting, subsetted),
		    FeatureAtom::of(fa, subsetting),
		    !FeatureAtom::of(fa, subsetted)
		.
		
		error invalidRedefinition() <->
		    redefinedFeature(redefining, redefined),
		    FeatureAtom::of(fa, redefining),
		    !FeatureAtom::of(fa, redefined)
		;
		    redefinedFeature(redefining, redefined),
		    FeatureAtom::of(fa, redefined),
		    !FeatureAtom::of(fa, redefining)
		.

		@priority(99)
		decision rule atomOfSuper(Atom a, Classifier sc) <->
		    Atom::of(a, c),
		    superclass(c, sc)
		==>
		    Atom::of(a, sc)
		.
		error inconsistentAtomType(Atom a) <->
		    Atom::of(a, c),
		    superclass(c, sc),
		    !Atom::of(a, sc)
		.

		@priority(99)
		decision rule featureAtomOfSuper(FeatureAtom fa, Feature sf) <->
		    FeatureAtom::of(fa, f),
		    specializedType(f, sf)
		==>
		    FeatureAtom::of(fa, sf)
		.
		error inconsistentFeatureAtomType(FeatureAtom fa, Feature sf) <->
		    FeatureAtom::of(fa, f),
		    specializedType(f, sf),
		    !FeatureAtom::of(fa, sf)
		.

		@priority(2)
		decision rule addFeatureAtomToLowerBound(domainAtom, @focus featureAtom, feature, valueType, @focus valueAtom) <->
			!isAbstract(feature),
			!isAbstract(valueType),
		    Atom::of(domainAtom, domainType),
		    typeFeaturing(domainType, feature),
		    featureTyping(feature, valueType),
		    count { must featureAtomOfType(domainAtom, feature, _) } < lowerBound(feature),
		    !must exists(valueAtom),
		    !must exists(featureAtom)
		==>
		    FeatureAtom::of(featureAtom, feature),
		    domain(featureAtom, domainAtom),
		    value(featureAtom, valueAtom),
		    Atom::of(valueAtom, valueType)
		.

		decision rule addOptionalFeatureAtom(domainAtom, @focus featureAtom, feature, valueType, @focus valueAtom) <->
		    !isAbstract(feature),
		    !isAbstract(valueType),
		    Atom::of(domainAtom, domainType),
		    typeFeaturing(domainType, feature),
		    featureTyping(feature, valueType),
		    count { must featureAtomOfType(domainAtom, feature, _) } < upperBound(feature),
		    !must exists(valueAtom),
		    !must exists(featureAtom)
		==>
		    FeatureAtom::of(featureAtom, feature),
		    domain(featureAtom, domainAtom),
		    value(featureAtom, valueAtom),
		    Atom::of(valueAtom, valueType)
		.

		%% Abstract constraints

		pred atomOfNonAbstractSub(Atom a, Classifier ac) <->
		    isAbstract(ac),
		    Atom::of(a, ac),
		    Atom::of(a, c),
		    superclass(c, ac),
		    !isAbstract(c)
		.
		error abstractAtomWithoutSpecificType(Atom a) <->
		    Classifier(ac),
		    isAbstract(ac),
		    Atom::of(a, ac),
		    !atomOfNonAbstractSub(a, ac)
		.

		pred featureAtomOfNonAbstractSub(FeatureAtom fa, Feature af) <->
		    isAbstract(af),
		    FeatureAtom::of(fa, af),
		    FeatureAtom::of(fa, f),
		    specializedType(f, af),
		    !isAbstract(f)
		.
		error abstractFeatureAtomWithoutSpecificType(FeatureAtom fa) <->
		    Feature(f),
		    isAbstract(f),
		    FeatureAtom::of(fa, f),
		    !featureAtomOfNonAbstractSub(fa, f)
		.
		'''
	}
}