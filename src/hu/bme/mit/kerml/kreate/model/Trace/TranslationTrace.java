package hu.bme.mit.kerml.kreate.model.Trace;

import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import org.omg.sysml.lang.sysml.Feature;
import org.omg.sysml.lang.sysml.Type;

public class TranslationTrace {
	public static Map<Feature, FeaturingData> typeFeaturing = new HashMap<>();
	
	public static void addTypeFeaturing(Feature f, Type t) {
		typeFeaturing.putIfAbsent(f, FeaturingData.of(f, t)); // might need more sophisticated selection
		if (typeFeaturing.get(f).getT() == null) {
			typeFeaturing.put(f, FeaturingData.of(f, t));
		}

	}
	
	public static void addFeaturingData(FeaturingData fd) {
		typeFeaturing.putIfAbsent(fd.getF(), fd);	
		if (typeFeaturing.get(fd.getF()).getT() == null) {
			typeFeaturing.put(fd.getF(), fd);
		}
	}
	
	public static void normalizeNames() {
		Map<String, List<FeaturingData>> collisions = typeFeaturing.values().stream()
			    .collect(Collectors.groupingBy(FeaturingData::getName))
			    .entrySet().stream()
			    .filter(e -> e.getValue().size() > 1)
			    .collect(Collectors.toMap(Map.Entry::getKey, Map.Entry::getValue));

		for (Map.Entry<String, List<FeaturingData>> collision : collisions.entrySet()) {
			int i = 1;
			for (FeaturingData fd : collision.getValue()) {
				fd.setName(collision.getKey() + i++);
			}
		}
	}

	public static void defaultAllTypesTo(Type type) {
		for (FeaturingData fd : typeFeaturing.values()) {
			if (fd.getT() == null) {
				fd.setT(type);
			}
		}
	}
}
