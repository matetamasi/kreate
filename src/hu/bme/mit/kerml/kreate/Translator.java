package hu.bme.mit.kerml.kreate;

import java.util.Collection;
import java.util.List;

import org.eclipse.emf.ecore.EObject;
import org.omg.sysml.lang.sysml.Classifier;
import org.omg.sysml.lang.sysml.Feature;
import org.omg.sysml.lang.sysml.Type;

public class Translator {

	public static String translate(Classifier classifier, Collection<EObject> objects) {
		System.out.println("translate called with classifier: " + classifier.getDeclaredName());
		List<Feature> features = classifier.getFeature().stream()
				.filter(it -> 
					!"self".equals(it.getDeclaredName()) &&
					!"that".equals(it.getDeclaredName())
				)
				.toList();

		List<Classifier> featureTypes = features.stream()
				.map(it -> mostSpecificNonFeatureType(it.getType())).toList();

		var x = Templates.classifier(classifier);
		System.out.println("x: " + x);

		return x + concat(featureTypes.stream().map(it -> translate(it, objects)).toList());
	}
	
	private static String concat(List<String> strings) {
		return String.join("", strings);
	}
	
	public static Classifier mostSpecificNonFeatureType(List<Type> types) {
		List<Classifier> classifierTypes = types.stream()
				.filter(it -> (it instanceof Classifier))
				.map(it -> (Classifier)it)
				.toList();
		for (Classifier classifier : classifierTypes) {
			for (Classifier c: classifierTypes) {
				if (classifier.allSupertypes().contains(c)) {
					continue;
				}
			}
			return classifier;
		}
		String t = "";
		for (Type ty : types) {
			t += "\t" + ty.effectiveName() + "\n";
		}
		
		throw new RuntimeException("No most specific classifier found for types\n." + t
		);
	}
}
