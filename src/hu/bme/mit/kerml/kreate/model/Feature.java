package hu.bme.mit.kerml.kreate.model;

public class Feature {
	private int nameCounter = 1;
	private String name;
	
	public Feature(String name) {
		this.name = name;
	}

	public String nextName() {
		return name + nameCounter++;
	}

	public String getName() {
		return name;
	}
}
