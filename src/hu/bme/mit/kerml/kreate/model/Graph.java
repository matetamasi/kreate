package hu.bme.mit.kerml.kreate.model;

import java.util.HashMap;
import java.util.List;
import java.util.Collection;
import java.util.Map;
import java.util.function.Consumer;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class Graph {
	private Map<String, Atom> atoms = new HashMap<String, Atom>();
	private Map<String, FeatureAtom> featureAtoms = new HashMap<String, FeatureAtom>();
	private Map<String, Classifier> classifiers = new HashMap<String, Classifier>();
	private Map<String, Feature> features = new HashMap<String, Feature>();

	public Collection<Atom> atoms() {
		return atoms.values();
	}
	public Collection<FeatureAtom> featureAtoms() {
		return featureAtoms.values();
	}

	public Collection<Classifier> classifiers() {
		return classifiers.values();
	}
	
	public Collection<Feature> features() {
		return features.values();
	}
	
	private final List<Pair<Pattern, Consumer<Matcher>>> patterns = List.of(
			new Pair<>(Pattern.compile("^Atom\\((.*)\\)\\.$"), (m) -> addAtom(m.group(1))),
			new Pair<>(Pattern.compile("^Atom::of\\((.*), (.*)\\)\\.$"), (m) -> addAtom(m.group(1)).of(addClassifier(m.group(2)))),
			new Pair<>(Pattern.compile("^FeatureAtom\\((.*)\\)\\.$"), (m) -> addFeatureAtom(m.group(1))),
			new Pair<>(Pattern.compile("^FeatureAtom::of\\((.*), (.*)\\)\\.$"), (m) -> addFeatureAtom(m.group(1)).of(addFeature(m.group(2)))),
			new Pair<>(Pattern.compile("^domain\\((.*), (.*)\\)\\.$"), (m) -> addFeatureAtom(m.group(1)).domain(addAtom(m.group(2)))),
			new Pair<>(Pattern.compile("^value\\((.*), (.*)\\)\\.$"), (m) -> addFeatureAtom(m.group(1)).value(addAtom(m.group(2))))
	);
	
	public static final Graph generate(String s) {
		Graph g = new Graph();
		s.lines()
		.dropWhile(line -> !line.startsWith("declare"))
		.dropWhile(line -> line.startsWith("declare"))
		.forEach(line -> {
			g.addString(line);
		});
		g.fillNames();
		return g;
	}
	
	private final void addString(String line) {
		for (Pair<Pattern, Consumer<Matcher>> pair : patterns) {
			Matcher m;
			if ((m = pair.a().matcher(line)).matches()) {
				pair.b().accept(m);
				break;
			}
		}
	}
	
	public void fillNames() {
		atoms.values().forEach(atom -> atom.generateName());
		featureAtoms.values().forEach(featureAtom -> featureAtom.generateName());
	}
	
	private Atom addAtom(String name) {
		if (!atoms.containsKey(name)) {
			atoms.put(name, new Atom());
		}
		return atoms.get(name);
	}

	private FeatureAtom addFeatureAtom(String name) {
		if (!featureAtoms.containsKey(name)) {
			featureAtoms.put(name, new FeatureAtom());
		}
		return featureAtoms.get(name);
	}

	private Classifier addClassifier(String name) {
		if (!classifiers.containsKey(name)) {
			classifiers.put(name, new Classifier(name));
		}
		return classifiers.get(name);
	}

	private Feature addFeature(String name) {
		if (!features.containsKey(name)) {
			features.put(name, new Feature(name));
		}
		return features.get(name);
	}
}
