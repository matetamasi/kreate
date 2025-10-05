package hu.bme.mit.kerml.kreate.model;

public class FeatureAtom {
	private String generatedName;
	private Feature of;
	private Atom domain;
	private Atom value;

	public void generateName() {
		generatedName = of.nextName();
	}
	
	public String getGeneratedName() {
		return generatedName;
	}

	public Feature of() {
		return of;
	}
	public void of(Feature f) {
		of = f;
	}

	public Atom domain() {
		return domain;
	}

	public void domain(Atom a) {
		domain = a;
	}

	public Atom value() {
		return value;
	}

	public void value(Atom a) {
		value = a;
	}
}
