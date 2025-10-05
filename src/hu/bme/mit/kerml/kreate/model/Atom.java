package hu.bme.mit.kerml.kreate.model;

public class Atom {
	Classifier of;
	String generatedName;

	public Classifier of() {
		return of;
	}

	public void of(Classifier c) {
		of = c;
	}
	public String generatedName() {
		return generatedName;
	}

	public void generateName() {
		this.generatedName = of.nextName();
	}

}
