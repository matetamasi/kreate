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
import static org.junit.Assert.*
import java.nio.file.Files
import java.nio.file.Paths

class Translator {
	val static logger = Logger.getLogger("KreateLogger")
	var static Classifier anything = null;
	def static String translate(Classifier classifier, Collection<EObject> objects) {

		val classifiersToTranslate = findRelatedClassifiers(classifier)
		addFeaturesOfClassifiers(classifiersToTranslate)
		addAllContents(classifiersToTranslate)
		
		anything = classifiersToTranslate.flatMap[it.superclasses].findFirst[it.declaredName == "Anything"]
		assertTrue(anything !== null)
		assertTrue(anything.declaredName == "Anything")
		TranslationTrace.defaultAllTypesTo(anything)
		assertTrue(TranslationTrace.typeFeaturing.values.filter[it.t === null].toSet.isEmpty)
//		TranslationTrace.normalizeNames
		
		return classifiersToTranslate.map[classifierTemplate(it)].join("\n") + "\n" + 
		TranslationTrace.typeFeaturing.values.map[featureTemplate(it)].join("\n")
	}
	
	def static String classifierTemplate(Classifier classifier) {
		return '''
		Classifier(«classifier.name»).
«««		directSuperclass(«classifier.name», Anything).
«««		directSpecializedType(«classifier.name», Anything).
«««		«println(classifier)»
		«FOR superclass : classifier.superclasses»
«««		«println("CLASSIFIER TEMPLATE")»
«««		«println(superclass)»
		directSuperclass(«classifier.name», «superclass.name»).
		directSpecializedType(«classifier.name», «superclass.name»).
		«ENDFOR»
		«IF classifier.abstract»
		isAbstract(«classifier.name»).
		«ENDIF»

		'''
	}
		def private static String chainingTemplate(FeaturingData fd) {
		val feature = fd.f
		val featuringType = fd.t
//		var fts = (FeatureUtil.getAllFeaturingTypesOf(feature) + List.of(featuringType)).toSet
//		var ft = fts.get(0)
//		var fcName = "chain_" + featuringType.declaredName + feature.chainingFeature.map[declaredName].join("_")
		var fcName = fd.name
		return'''
			Feature(«fcName»).
			FeatureChain(«fcName»).
			FeatureChain::source(«fcName», «featuringType.declaredName»).
			first(«fcName», «fcName»_1).
			«var counter = 1»
			«FOR link : feature.chainingFeature»
				ChainAdapter(«fcName»_«counter»).
				head(«fcName»_«counter», «link.declaredName»).
				«IF counter < feature.chainingFeature.size»
				tail(«fcName»_«counter», «fcName»_«counter++ + 1»).
				«ENDIF»
			«ENDFOR»
		'''
	}
	def private static String featureTemplate(FeaturingData fd) {
		if (!fd.f.chainingFeature.empty) {
			return chainingTemplate(fd)
		}
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
	
//	def private static String featureTemplate(FeaturingData fd) {
//		val feature = fd.f
//		val featuringType = fd.t
//		val fName = fd.name
//		return '''
//		
//		Feature(«fName»).
//		typeFeaturing(«featuringType.declaredName», «fName»).
//		«FOR redefined : FeatureUtil.getRedefinedFeaturesOf(feature)»
//			directRedefinedFeature(«fName», «TranslationTrace.typeFeaturing.get(redefined).name»).
//			directSpecializedType(«fName», «TranslationTrace.typeFeaturing.get(redefined).name»).
//		«ENDFOR»
//		«FOR subsetted : FeatureUtil.getSubsettedFeaturesOf(feature)»
//			directSubsettedFeature(«fName», «TranslationTrace.typeFeaturing.get(subsetted).name»).
//			directSpecializedType(«fName», «TranslationTrace.typeFeaturing.get(subsetted).name»).
//			«IF !subsetted.chainingFeature.empty»
//				«var ft = (FeatureUtil.getAllFeaturingTypesOf(feature) + List.of(featuringType)).toSet»
//				«var fts = ft.get(0)»
//				«var fcname = "chain_" + fts.declaredName + subsetted.chainingFeature.map[declaredName].join»
//				FeatureChain(«fcname»).
//				FeatureChain::source(«fcname», «fts.declaredName»).
//				first(«fcname», «fcname»_1).
//				«var counter = 1»
//				«FOR link : subsetted.chainingFeature»
//					ChainAdapter(«fcname»_«counter»).
//					head(«fcname»_«counter», «link.declaredName»).
//					«IF counter < subsetted.chainingFeature.size»
//					tail(«fcname»_«counter», «fcname»_«counter»).
//					«counter += 1»
//					«ENDIF»
//				«ENDFOR»
//			«ENDIF»
//		«ENDFOR»
//		«FOR featureType : FeatureUtil.getAllTypesOf(feature).filter[it instanceof Classifier]»
//		featureTyping(«fName», «featureType.declaredName»).
//		directSpecializedType(«fName», «featureType.declaredName»).
//		«ENDFOR»
//		lowerBound(«fName»): «feature.lower».
//		upperBound(«fName»): «feature.upper».
//		«IF feature.abstract»
//		isAbstract(«feature.name»).
//		«ENDIF»
//		'''
//	}
	
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
		return c.supertypes(false).filter[it instanceof Classifier].map[it as Classifier].toList
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
		new String(Files.readAllBytes(Paths.get("metamodel.problem")))
	}

	def static void printAllEContents(EList<EObject> el, int depth) {
		for (e : el) {
			print("\t".repeat(depth))
			println(el)
			printAllEContents(e.eContents, depth+1)
		}
	}
	def static Set<Classifier> findRelatedClassifiers(Classifier classifier) {
		var classifiersToTranslate = new HashSet
		var newClassifiers = Set.of(classifier)
		logger.info("Identifying classifiers to translate...")
		while (classifiersToTranslate.size < newClassifiers.size) {
			classifiersToTranslate.addAll(newClassifiers)
			assertEquals(classifiersToTranslate, newClassifiers)
			val superClasses = classifiersToTranslate.flatMap[it.superclasses]
			val featureClasses = classifiersToTranslate
				.flatMap[it.relevantFeatures]
				.flatMap[FeatureUtil.getAllTypesOf(it)]
				.filter[it instanceof Classifier]
				.map[it as Classifier]
			newClassifiers = (newClassifiers + superClasses + featureClasses).toSet
		}
		logger.info("Done!")
		return classifiersToTranslate
	}
	
	def static void addFeaturesOfClassifiers(Set<Classifier> classifiersToTranslate) {
		logger.info("Identifying features to translate...")
		var directFeaturesToTranslate = new HashSet
		var newFeatures = classifiersToTranslate.flatMap[c | c.relevantFeatures.map[f | Pair.of(c as Type, f)]].toSet
		while (directFeaturesToTranslate.size < newFeatures.size) {
			directFeaturesToTranslate.addAll(newFeatures)
			assertEquals(directFeaturesToTranslate, newFeatures)
			val featuresOfFeatures = directFeaturesToTranslate.flatMap[p | p.v.relevantFeatures.map[ff | Pair.of(p.v as Type, ff)]].toSet
			val specialized = directFeaturesToTranslate.flatMap[ p |
				FeatureUtil.getSubsettedFeaturesOf(p.v).map[s | Pair.of(null, s)] +
				FeatureUtil.getRedefinedFeaturesOf(p.v).map[s | Pair.of(null, s)]
			].toSet
			newFeatures = (newFeatures + featuresOfFeatures + specialized).toSet
		}
		logger.info("Done!")
		directFeaturesToTranslate.forEach[p | TranslationTrace.addTypeFeaturing(p.v, p.k)]
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
//		val externalFeatures = new HashMap<Feature, Type>
		var previousSize = 0
		var	 Set<Pair<Feature, Type>> externalFeatures = classifiersToTranslate
			.flatMap[c |
				c.eAllContents.filter[
					it instanceof Feature &&
					(it as Feature).declaredName != "self" &&
					(it as Feature).declaredName != "that"
				]
				.map[Pair.of(it as Feature, c as Type)]
				.toSet
			].toSet

		while(previousSize < externalFeatures.size) {
			previousSize = externalFeatures.size
			val featuresOfFeatures = externalFeatures
			.flatMap[f | f.k.eAllContents
				.filter[
					it instanceof Feature
				]
				.map[it as Feature]
				.filter[
					it.declaredName != "self" &&
					it.declaredName != "that"
				]
				.map[Pair.of(it, f.v)]
				.toSet
			].toSet
//			val specialized = externalFeatures.flatMap[ f |
//				FeatureUtil.getSubsettedFeaturesOf(f.k) +
//				FeatureUtil.getRedefinedFeaturesOf(f.k)
//			]
//			.map[Pair.of()]
//			.toSet
			externalFeatures = (externalFeatures + featuresOfFeatures).toSet
		}
//		println("externalFeatures size: " +externalFeatures.size)
		for (f : externalFeatures) {
//			println("looking for type of " + f)
//			val fts = FeatureUtil.getAllFeaturingTypesOf(f.k)
//			println("fts: " + fts)
//			val fcs = fts.filter[it instanceof Classifier].map[it as Classifier].toSet
//			println("fcs: " + fcs)
//			var Type ft = null
//			if (!fcs.isEmpty) {
//				ft = fcs.get(0)
//			} else if (!fts.isEmpty) {
//				ft = fts.get(0)
//			}
			if (TranslationTrace.typeFeaturing.containsKey(f.k)) {
				TranslationTrace.addTypeFeaturing(f.k, f.v)
			}
		}
	}
}