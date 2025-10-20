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
import org.omg.sysml.lang.sysml.Type
import hu.bme.mit.kerml.kreate.model.Pair
import java.util.logging.Logger
import hu.bme.mit.kerml.kreate.model.Trace.TranslationTrace
import hu.bme.mit.kerml.kreate.model.Trace.FeaturingData
import org.omg.sysml.lang.sysml.Multiplicity
import org.omg.sysml.lang.sysml.MultiplicityRange
import org.eclipse.emf.common.util.EList
import org.omg.sysml.lang.sysml.Documentation
import org.omg.sysml.lang.sysml.Expression
import org.omg.sysml.lang.sysml.LiteralBoolean

class Translator {
	val static logger = Logger.getLogger("KreateLogger")
	def static String translate(Classifier classifier, Collection<EObject> objects) {
		var classifiersToTranslate = new HashSet
		var newClassifiers = Set.of(classifier)
		logger.info("Identifying classifiers to translate...")
		while (classifiersToTranslate.size < newClassifiers.size) {
			classifiersToTranslate.addAll(newClassifiers)
			val superClasses = classifiersToTranslate.flatMap[it.superclasses]
			val featureClasses = classifiersToTranslate
				.flatMap[it.relevantFeatures]
				.flatMap[FeatureUtil.getAllTypesOf(it)]
				.filter[it instanceof Classifier]
				.map[it as Classifier]
			newClassifiers = (newClassifiers + superClasses + featureClasses).toSet
		}
		logger.info("Done!")

		logger.info("Identifying features to translate...")
		var directFeaturesToTranslate = new HashSet
		var newFeatures = classifiersToTranslate.flatMap[c | c.relevantFeatures.map[f | Pair.of(c as Type, f)]].toSet
		while (directFeaturesToTranslate.size < newFeatures.size) {
			directFeaturesToTranslate.addAll(newFeatures)
			val featuresOfFeatures = directFeaturesToTranslate.flatMap[f | f.v.relevantFeatures.map[ff | Pair.of(f.v as Type, ff)]].toSet
			val specialized = directFeaturesToTranslate.flatMap[ f |
				FeatureUtil.getSubsettedFeaturesOf(f.v).map[s | Pair.of(null, s)] +
				FeatureUtil.getRedefinedFeaturesOf(f.v).map[s | Pair.of(null, s)]
			].toSet
			newFeatures = (newFeatures + featuresOfFeatures + specialized).toSet
		}
		logger.info("Done!")
		
		directFeaturesToTranslate.forEach[p | TranslationTrace.addTypeFeaturing(p.v, p.k)]
		
		hu.bme.mit.kerml.kreate.Translator.addOwnedMemberFeatures(classifiersToTranslate);
		
		
		var anything = classifiersToTranslate.flatMap[it.allSupertypes].findFirst[it.declaredName == "Anything"]
		TranslationTrace.defaultAllTypesTo(anything)
		
		
		return classifiersToTranslate.map[classifierTemplate(it)].join("\n") + "\n" + 
		TranslationTrace.typeFeaturing.values.map[featureTemplate(it)].join("\n")
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
	def private static String featureTemplate(FeaturingData fd) {
		val feature = fd.f
		val featuringType = fd.t
		val fName = fd.name
		return '''
		
		Feature(«fName»).
		typeFeaturing(«featuringType.declaredName», «fName»).
		«FOR redefined : FeatureUtil.getRedefinedFeaturesOf(feature)»
			directRedefinedFeature(«fName», «TranslationTrace.typeFeaturing.get(redefined).name»).
			directSpecializedType(«fName», «TranslationTrace.typeFeaturing.get(redefined).name»).
		«ENDFOR»
		«FOR subsetted : FeatureUtil.getSubsettedFeaturesOf(feature)»
			directSubsettedFeature(«fName», «TranslationTrace.typeFeaturing.get(subsetted).name»).
			directSpecializedType(«fName», «TranslationTrace.typeFeaturing.get(subsetted).name»).
			«IF !subsetted.chainingFeature.empty»
				«var ft = (FeatureUtil.getAllFeaturingTypesOf(feature) + List.of(featuringType)).toSet»
				«var fts = ft.get(0)»
				«var fcname = "chain_" + fts.declaredName + subsetted.chainingFeature.map[declaredName].join»
				FeatureChain(«fcname»).
				FeatureChain::source(«fcname», «fts.declaredName»).
				first(«fcname», «fcname»_1).
				«var counter = 1»
				«FOR link : subsetted.chainingFeature»
					ChainAdapter(«fcname»_«counter»).
					head(«fcname»_«counter», «link.declaredName»).
					«IF counter < subsetted.chainingFeature.size»
					tail(«fcname»_«counter», «fcname»_«counter»).
					«counter += 1»
					«ENDIF»
				«ENDFOR»
			«ENDIF»
		«ENDFOR»
		«FOR featureType : FeatureUtil.getAllTypesOf(feature).filter[it instanceof Classifier]»
		featureTyping(«fName», «featureType.declaredName»).
		directSpecializedType(«fName», «featureType.declaredName»).
		«ENDFOR»
		lowerBound(«fName»): «feature.lower».
		upperBound(«fName»): «feature.upper».
		«IF feature.abstract»
		isAbstract(«feature.name»).
		«ENDIF»
		'''
	}
	
	def private static List<Feature> relevantFeatures(Type type) {
		return type.ownedFeature.filter[it |
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
		    FeatureChain[0..*] subsettedChain
		    FeatureChain[0..*] redefinedChain
		    int lowerBound
		    int upperBound
		}

		!exists(Feature::new).
		default !featureTyping(*, *).
		default !directSubsettedFeature(*, *).
		default !directRedefinedFeature(*, *).
		default !subsettedChain(*, *).

		pred subsettedOrRedefinedChain(Feature f, FeatureChain fc) <->
		    subsettedChain(f, fc)
		;
		    redefinedChain(f, fc)
		.

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

		%% Feature chaining

		@decide(false)
		class FeatureChain {
		    Classifier [1] source
		    ChainAdapter [1] first
		}
		!exists(FeatureChain::new).

		@decide(false)
		class ChainAdapter {
		    Feature[1] head
		    ChainAdapter [0..1] tail
		}
		!exists(ChainAdapter::new).
		default !tail(*, *).

		pred last(ChainAdapter c) <->
		    !tail(c, _)
		.

		pred resolveSub(Atom from, ChainAdapter chain, Atom to) <->
		    head(chain, feature),
		    featureAtomOfType(from, feature, to),
		    Atom::of(from, type),
		    typeFeaturing(type, feature)
		.
		pred resolveFinal(Atom from, ChainAdapter chain, Atom to) <->
		    last(chain),
		    resolveSub(from, chain, to)
		.
		pred resolveIntermediate(Atom from, ChainAdapter chain, Atom intermediate) <->
		    !last(chain),
		    resolveSub(from, chain, intermediate)
		.

		pred resolveChain(Atom from, FeatureChain fChain, Atom to) <->
		    first(fChain, chain),
		    resolveIntermediate(from, chain, i1),
		    tail(chain, chain2),
		    resolveFinal(i1, chain2, to)
		;
		    first(fChain, chain),
		    resolveIntermediate(from, chain, i1),
		    tail(chain, chain2),
		    resolveIntermediate(i1, chain2, i2),
		    tail(chain2, chain3),
		    resolveFinal(i2, chain3, to)
		;   
		    first(fChain, chain),
		    resolveIntermediate(from, chain, i1),
		    tail(chain, chain2),
		    resolveIntermediate(i1, chain2, i2),
		    tail(chain2, chain3),
		    resolveIntermediate(i2, chain3, i3),
		    tail(chain3, chain4),
		    resolveFinal(i3, chain4, to)
		;
		    first(fChain, chain),
		    resolveIntermediate(from, chain, i1),
		    tail(chain, chain2),
		    resolveIntermediate(i1, chain2, i2),
		    tail(chain2, chain3),
		    resolveIntermediate(i2, chain3, i3),
		    tail(chain3, chain4),
		    resolveIntermediate(i3, chain4, i4),
		    tail(chain4, chain5),
		    resolveFinal(i4, chain5, to)
		.

		@priority(2)
		decision rule addFeatureAtomSubsettingChainToLowerMultiplicity(@focus FeatureAtom fa, Atom incompleteAtom, Feature feature, Atom potentialValue) <->
		    Atom::of(incompleteAtom, type),
		    typeFeaturing(type, feature),
		    subsettedOrRedefinedChain(feature, fc),
		    !must featureAtomOfType(incompleteAtom, feature, potentialValue),
		    count { must featureAtomOfType(incompleteAtom, feature, _) } < lowerBound(feature),
		    !must exists(fa),
		    resolveChain(incompleteAtom, fc, potentialValue)
		==>
		    domain(fa, incompleteAtom),
		    value(fa, potentialValue),
		    FeatureAtom::of(fa, feature)
		.


		decision rule addOptionalFeatureAtomSubsettingChain(@focus FeatureAtom fa, Atom incompleteAtom, Feature feature, Atom potentialValue) <->
		    Atom::of(incompleteAtom, type),
		    typeFeaturing(type, feature),
		    subsettedOrRedefinedChain(feature, fc),
		    !must featureAtomOfType(incompleteAtom, feature, potentialValue),
		    count { must featureAtomOfType(incompleteAtom, feature, _) } < upperBound(feature),
		    !must exists(fa),
		    resolveChain(incompleteAtom, fc, potentialValue)
		==>
		    domain(fa, incompleteAtom),
		    value(fa, potentialValue),
		    FeatureAtom::of(fa, feature)
		.

		error chainNotSubsetted(FeatureAtom featureAtom) <->
		    FeatureAtom::of(featureAtom, feature),
		    subsettedChain(feature, chain),
		    value(featureAtom, valueAtom),
		    domain(featureAtom, domainAtom),
		    !resolveChain(domainAtom, chain, valueAtom)
		.

		error chainNotRedefined(FeatureAtom featureAtom) <->
		    FeatureAtom::of(featureAtom, feature),
		    redefinedChain(feature, chain),
		    value(featureAtom, valueAtom),
		    domain(featureAtom, domainAtom),
		    !resolveChain(domainAtom, chain, valueAtom)
		;
		    FeatureAtom::of(featureAtom, feature),
		    redefinedChain(feature, chain),
		    domain(featureAtom, domainAtom),
		    resolveChain(domainAtom, chain, someOtherAtom),
		    !value(featureAtom, someOtherAtom)
		.
		'''
	}

	def static void printAllEContents(EList<EObject> el, int depth) {
		for (e : el) {
			print("\t".repeat(depth))
			println(el)
			printAllEContents(e.eContents, depth+1)
		}
	}
	
	def static void addOwnedMemberFeatures(Set<Classifier> classifiersToTranslate) {
		var externalFeatures = new HashSet<FeaturingData>
		var newExternalFeatures = classifiersToTranslate
		.flatMap[c | c.ownedMember
			.filter[
				it instanceof Feature &&
				!(it instanceof Multiplicity) &&
				!(it instanceof MultiplicityRange) &&
				(it as Feature).declaredName != "self" &&
				(it as Feature).declaredName != "that"
			]
			.map[FeaturingData.of(it as Feature, c)]
		]
		.toSet
		while(externalFeatures.size < newExternalFeatures.size) {
			externalFeatures.addAll(newExternalFeatures)
			val featuresOfFeatures = externalFeatures.flatMap[fd | fd.f.ownedMember.filter[it instanceof Feature].map[FeaturingData.of(it as Feature, fd.f)].toSet].toSet
			newExternalFeatures = (newExternalFeatures + featuresOfFeatures).filter[ fd |
				fd.f instanceof Feature &&
				!(fd.f instanceof Multiplicity) &&
				!(fd.f instanceof MultiplicityRange) &&
				fd.f.declaredName != "self" &&
				fd.f.declaredName != "that"
			].toSet
		}
		externalFeatures.forEach[fd | TranslationTrace.addFeaturingData(fd)]
		
	}
	def static void addAllContents(Set<Classifier> classifiersToTranslate) {
		var externalFeatures = new HashSet<Feature>
		var Set<Feature> newExternalFeatures = classifiersToTranslate
			.flatMap[c |
				c.eAllContents.filter[
					it instanceof Feature &&
					!(it instanceof Multiplicity) &&
					!(it instanceof MultiplicityRange) &&
					!(it instanceof Documentation) &&
					!(it instanceof LiteralBoolean) &&
					!(it instanceof LiteralInfinity) &&
					!(it instanceof LiteralInteger) &&
					!(it instanceof Expression) &&
					(it as Feature).declaredName != "self" &&
					(it as Feature).declaredName != "that"
				].map[it as Feature].toSet
			]
			.toSet
		while(externalFeatures.size < newExternalFeatures.size) {
			externalFeatures.addAll(newExternalFeatures)
			val featuresOfFeatures = externalFeatures.flatMap[f | f.eAllContents.filter[it instanceof Feature].map[it as Feature].toSet].toSet
			val specialized = externalFeatures.flatMap[ f |
				FeatureUtil.getSubsettedFeaturesOf(f) +
				FeatureUtil.getRedefinedFeaturesOf(f)
			].toSet
			newExternalFeatures = (newExternalFeatures + featuresOfFeatures + specialized).filter[
				it instanceof Feature &&
				!(it instanceof Multiplicity) &&
				!(it instanceof MultiplicityRange) &&
				!(it instanceof Documentation) &&
				!(it instanceof LiteralBoolean) &&
				!(it instanceof LiteralInfinity) &&
				!(it instanceof LiteralInteger) &&
				!(it instanceof Expression) &&
				it.declaredName != "self" &&
				it.declaredName != "that"
			].toSet
		}
		println("externalFeatures size: " +externalFeatures.size)
		for (f : externalFeatures) {
			println("looking for type of " + f)
			val fts = FeatureUtil.getAllFeaturingTypesOf(f)
			println("fts: " + fts)
			val fcs = fts.filter[it instanceof Classifier].map[it as Classifier].toSet
			println("fcs: " + fcs)
			var Type ft = null
			if (!fcs.isEmpty) {
				ft = fcs.get(0)
			} else if (!fts.isEmpty) {
				ft = fts.get(0)
			}
			TranslationTrace.addTypeFeaturing(f, ft)
		}
	}
}