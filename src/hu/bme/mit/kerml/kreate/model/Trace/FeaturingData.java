package hu.bme.mit.kerml.kreate.model.Trace;

import org.omg.sysml.lang.sysml.Classifier;
import org.omg.sysml.lang.sysml.Feature;
import org.omg.sysml.lang.sysml.Type;
import org.omg.sysml.util.FeatureUtil;

public class FeaturingData {
	private Feature f;
	private Type t;
	private String name;
	
	public static FeaturingData of(Feature feature, Type featuringType) {
		return new FeaturingData(feature, featuringType);
	}
	private FeaturingData(Feature f, Type t) {
		this.f = f;
		this.t = t;
		this.name = f.getDeclaredName() != null ? f.getDeclaredName() : generateName();
	}
	
	private String generateName() {
		String featuringTypeName = "Unknown";
		if (t != null && t.getDeclaredName() != null) {
				featuringTypeName = t.getDeclaredName();
		}
		Classifier featureTyping = FeatureUtil.getFirstTypeOf(f, Classifier.class);
		String featureTypingName = featureTyping.getDeclaredName() != null ? featureTyping.getDeclaredName() : "unknown";
		return featuringTypeName + "_to_" + featureTypingName;
	}

	public Feature getF() {
		return f;
	}

	public void setF(Feature f) {
		this.f = f;
	}

	public Type getT() {
		return t;
	}

	public void setT(Type t) {
		this.t = t;
	}

	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}
}
